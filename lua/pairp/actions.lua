local M = {}

local watcher_refs = 0
local watcher_augroup = nil
local buffer_file_exists = {}
local dir_watchers = {} -- dir_path -> { handle = uv_fs_event_t, buf_count = number }
local buf_dir_map = {} -- buf -> dir (for cleanup on BufDelete when name may be gone)
local created_files_timer = nil

local function is_file_buffer(buf)
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
		return false
	end
	local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
	if bt ~= "" then
		return false
	end
	local name = vim.api.nvim_buf_get_name(buf)
	return name ~= ""
end

local function file_exists(path)
	local stat = vim.uv.fs_stat(path)
	return stat ~= nil and stat.type == "file"
end

local function get_buf_dir(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return nil
	end
	return vim.fn.fnamemodify(name, ":h")
end

local function reload_buf(buf)
	if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent! checktime")
		end)
	end
end

local function watch_dir(dir)
	if dir_watchers[dir] then
		dir_watchers[dir].buf_count = dir_watchers[dir].buf_count + 1
		return
	end
	local handle = vim.uv.new_fs_event()
	if not handle then
		return
	end
	handle:start(dir, {}, vim.schedule_wrap(function(err, filename)
		if err or not filename then
			return
		end
		local full_path = dir .. "/" .. filename
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if is_file_buffer(buf) then
				local name = vim.api.nvim_buf_get_name(buf)
				if name == full_path then
					reload_buf(buf)
				end
			end
		end
	end))
	dir_watchers[dir] = { handle = handle, buf_count = 1 }
end

local function unwatch_dir(dir)
	local entry = dir_watchers[dir]
	if not entry then
		return
	end
	entry.buf_count = entry.buf_count - 1
	if entry.buf_count <= 0 then
		pcall(entry.handle.stop, entry.handle)
		pcall(entry.handle.close, entry.handle)
		dir_watchers[dir] = nil
	end
end

local function stop_all_dir_watchers()
	for dir, entry in pairs(dir_watchers) do
		pcall(entry.handle.stop, entry.handle)
		pcall(entry.handle.close, entry.handle)
	end
	dir_watchers = {}
end

local function reload_created_files()
	for buf, _ in pairs(buffer_file_exists) do
		if not vim.api.nvim_buf_is_valid(buf) then
			buffer_file_exists[buf] = nil
		end
	end

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if is_file_buffer(buf) then
			local ok, _ = pcall(function()
				local name = vim.api.nvim_buf_get_name(buf)
				local exists_now = file_exists(name)
				local existed_before = buffer_file_exists[buf]

				if existed_before == nil then
					buffer_file_exists[buf] = exists_now
				elseif not existed_before and exists_now then
					local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
					if not modified then
						-- Avoid W13 ("created after editing started") by explicitly re-reading the buffer.
						vim.api.nvim_buf_call(buf, function()
							vim.cmd("silent! keepalt keepjumps edit")
						end)
					end
					buffer_file_exists[buf] = true
				else
					buffer_file_exists[buf] = exists_now
				end
			end)
			if not ok then
				buffer_file_exists[buf] = nil
			end
		end
	end
end

--- Open a file in a non-floating, non-terminal editor window.
--- Prefers the most recently used editor window over the first found.
--- @param filepath string absolute or relative path
--- @param line number|nil optional line to jump to
--- @param col number|nil optional column to jump to
function M.open(filepath, line, col)
	if not filepath or filepath == "" then
		return { ok = false, error = "filepath is required" }
	end

	-- Collect candidate windows (non-floating, non-terminal)
	local candidates = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(win)
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
		if cfg.relative == "" and bt ~= "terminal" then
			table.insert(candidates, win)
		end
	end

	local target_win
	if #candidates > 0 then
		-- Prefer the previous window (most recently used) if it's a candidate
		local prev_win = vim.fn.win_getid(vim.fn.winnr("#"))
		for _, win in ipairs(candidates) do
			if win == prev_win then
				target_win = win
				break
			end
		end
		-- Fall back to the largest candidate window
		if not target_win then
			local max_area = 0
			for _, win in ipairs(candidates) do
				local w = vim.api.nvim_win_get_width(win)
				local h = vim.api.nvim_win_get_height(win)
				local area = w * h
				if area > max_area then
					max_area = area
					target_win = win
				end
			end
		end
	else
		vim.cmd("topleft vsplit")
		target_win = vim.api.nvim_get_current_win()
	end

	-- Save current window so we can restore focus after opening
	local prev_win = vim.api.nvim_get_current_win()

	local ok, result = pcall(function()
		vim.api.nvim_set_current_win(target_win)
		vim.cmd("silent edit " .. vim.fn.fnameescape(filepath))

		-- Enable autoread so external changes are picked up
		vim.api.nvim_set_option_value("autoread", true, { buf = 0 })

		local opened_file = vim.api.nvim_buf_get_name(0)

		if line then
			local total = vim.api.nvim_buf_line_count(0)
			line = math.max(1, math.min(line, total))
			col = col or 0
			vim.api.nvim_win_set_cursor(target_win, { line, col })
			vim.cmd("normal! zz")
		end

		return opened_file
	end)

	-- Always restore focus to the previous window (e.g. the Pairp terminal)
	if vim.api.nvim_win_is_valid(prev_win) then
		vim.api.nvim_set_current_win(prev_win)
	end

	if not ok then
		return { ok = false, error = tostring(result) }
	end

	return { ok = true, file = result }
end

--- Start file watchers for external change detection.
--- Uses fs_event for efficient per-directory watching, plus a lightweight timer for new-file detection.
--- Uses reference counting so multiple sessions share one set of watchers.
function M.start_watcher(interval_ms)
	watcher_refs = watcher_refs + 1
	if created_files_timer then
		return
	end

	buffer_file_exists = {}
	buf_dir_map = {}
	interval_ms = interval_ms or 500
	vim.o.autoread = true

	-- Auto-reload changed files without prompting while Claude is active.
	-- W13 ("created after editing started") is handled separately in reload_created_files().
	watcher_augroup = vim.api.nvim_create_augroup("pairp_file_watcher", { clear = true })
	vim.cmd([[
		autocmd pairp_file_watcher FileChangedShell * let v:fcs_choice = 'reload'
	]])
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = watcher_augroup,
		pattern = "*",
		callback = function(args)
			local buf = args.buf
			if is_file_buffer(buf) then
				local name = vim.api.nvim_buf_get_name(buf)
				buffer_file_exists[buf] = file_exists(name)
				local dir = get_buf_dir(buf)
				if dir then
					buf_dir_map[buf] = dir
					watch_dir(dir)
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = watcher_augroup,
		pattern = "*",
		callback = function(args)
			buffer_file_exists[args.buf] = nil
			local dir = buf_dir_map[args.buf]
			if dir then
				unwatch_dir(dir)
			end
			buf_dir_map[args.buf] = nil
		end,
	})

	-- Watch directories of all currently open file buffers
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if is_file_buffer(buf) then
			local dir = get_buf_dir(buf)
			if dir then
				buf_dir_map[buf] = dir
				watch_dir(dir)
			end
		end
	end

	-- Lightweight timer only for detecting newly-created files
	created_files_timer = vim.uv.new_timer()
	created_files_timer:start(
		0,
		interval_ms,
		vim.schedule_wrap(function()
			if vim.fn.getcmdwintype() == "" then
				reload_created_files()
			end
		end)
	)
end

--- Decrement watcher reference count; stop when no sessions remain.
function M.stop_watcher()
	watcher_refs = math.max(0, watcher_refs - 1)
	if watcher_refs > 0 then
		return
	end
	stop_all_dir_watchers()
	if created_files_timer then
		local timer = created_files_timer
		created_files_timer = nil
		pcall(timer.stop, timer)
		pcall(timer.close, timer)
	end
	if watcher_augroup then
		vim.api.nvim_del_augroup_by_id(watcher_augroup)
		watcher_augroup = nil
	end
	buffer_file_exists = {}
	buf_dir_map = {}
end

--- List open file buffers.
function M.buffers()
	local result = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
			if name ~= "" and bt == "" then
				table.insert(result, {
					name = name,
					modified = vim.api.nvim_get_option_value("modified", { buf = buf }),
				})
			end
		end
	end
	return { ok = true, buffers = result }
end

--- Register globally so actions are callable via RPC from the terminal.
function M.register()
	_G.PairpActions = M
end

return M

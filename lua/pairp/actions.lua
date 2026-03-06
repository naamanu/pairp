local M = {}

local watcher_timer = nil
local watcher_refs = 0
local watcher_augroup = nil

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

	vim.api.nvim_set_current_win(target_win)
	vim.cmd("edit " .. vim.fn.fnameescape(filepath))

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

	-- Restore focus to the previous window (e.g. the Pairp terminal)
	if vim.api.nvim_win_is_valid(prev_win) then
		vim.api.nvim_set_current_win(prev_win)
	end

	return { ok = true, file = opened_file }
end

--- Start a timer that polls for external file changes.
--- Uses reference counting so multiple sessions share one watcher.
function M.start_watcher(interval_ms)
	watcher_refs = watcher_refs + 1
	if watcher_timer then
		return
	end

	interval_ms = interval_ms or 500
	vim.o.autoread = true

	-- Auto-reload all files without prompting while Claude is active
	-- Use vimscript autocmd because setting vim.v.fcs_choice from Lua
	-- callbacks does not reliably suppress the W13 confirm prompt.
	watcher_augroup = vim.api.nvim_create_augroup("pairp_file_watcher", { clear = true })
	vim.cmd([[
		autocmd pairp_file_watcher FileChangedShell * let v:fcs_choice = 'reload'
	]])

	watcher_timer = vim.uv.new_timer()
	watcher_timer:start(
		0,
		interval_ms,
		vim.schedule_wrap(function()
			if vim.fn.getcmdwintype() == "" then
				vim.cmd("silent! checktime")
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
	if watcher_timer then
		watcher_timer:stop()
		watcher_timer:close()
		watcher_timer = nil
	end
	if watcher_augroup then
		vim.api.nvim_del_augroup_by_id(watcher_augroup)
		watcher_augroup = nil
	end
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

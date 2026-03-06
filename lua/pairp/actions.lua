local M = {}

local watcher_timer = nil

--- Open a file in a non-floating, non-terminal editor window.
--- @param filepath string absolute or relative path
--- @param line number|nil optional line to jump to
--- @param col number|nil optional column to jump to
function M.open(filepath, line, col)
	if not filepath or filepath == "" then
		return { ok = false, error = "filepath is required" }
	end

	-- Find a regular editor window (not floating, not terminal)
	local target_win = nil
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(win)
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
		if cfg.relative == "" and bt ~= "terminal" then
			target_win = win
			break
		end
	end

	if not target_win then
		vim.cmd("topleft vsplit")
		target_win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_set_current_win(target_win)
	vim.cmd("edit " .. vim.fn.fnameescape(filepath))

	-- Enable autoread so external changes are picked up
	vim.api.nvim_set_option_value("autoread", true, { buf = 0 })

	if line then
		local total = vim.api.nvim_buf_line_count(0)
		line = math.max(1, math.min(line, total))
		col = col or 0
		vim.api.nvim_win_set_cursor(target_win, { line, col })
		vim.cmd("normal! zz")
	end

	return { ok = true, file = vim.api.nvim_buf_get_name(0) }
end

--- Start a timer that polls for external file changes.
--- Runs checktime every interval_ms to reload buffers modified on disk.
function M.start_watcher(interval_ms)
	if watcher_timer then
		return
	end

	interval_ms = interval_ms or 500
	vim.o.autoread = true

	watcher_timer = vim.uv.new_timer()
	watcher_timer:start(
		0,
		interval_ms,
		vim.schedule_wrap(function()
			-- Only run checktime if we're not in a prompt or cmdline
			if vim.fn.getcmdwintype() == "" then
				vim.cmd("silent! checktime")
			end
		end)
	)
end

--- Stop the file change watcher.
function M.stop_watcher()
	if watcher_timer then
		watcher_timer:stop()
		watcher_timer:close()
		watcher_timer = nil
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

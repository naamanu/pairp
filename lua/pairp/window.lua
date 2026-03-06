local M = {}

local state = {
	buf = nil,
	win = nil,
	chan = nil,
}

local function is_valid()
	return state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.win and vim.api.nvim_win_is_valid(state.win)
end

local function win_opts()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	return {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Pairp ",
		title_pos = "center",
	}
end

function M.open(cli_path)
	-- If already open, focus it
	if is_valid() then
		vim.api.nvim_set_current_win(state.win)
		return
	end

	-- Reuse existing buffer if the terminal is still running
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.chan then
		state.win = vim.api.nvim_open_win(state.buf, true, win_opts())
		vim.cmd.startinsert()
		return
	end

	-- Create a new terminal buffer
	state.buf = vim.api.nvim_create_buf(false, true)
	state.win = vim.api.nvim_open_win(state.buf, true, win_opts())

	state.chan = vim.fn.termopen(cli_path, {
		on_exit = function()
			state.chan = nil
			if is_valid() then
				vim.api.nvim_win_close(state.win, true)
			end
			if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
				vim.api.nvim_buf_delete(state.buf, { force = true })
			end
			state.buf = nil
			state.win = nil
		end,
	})

	vim.cmd.startinsert()

	-- q in normal mode closes the window (but keeps the terminal alive)
	vim.keymap.set("n", "q", function()
		M.hide()
	end, { buffer = state.buf, desc = "Hide Pairp window" })
end

function M.hide()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
		state.win = nil
	end
end

function M.toggle(cli_path)
	if is_valid() then
		M.hide()
	else
		M.open(cli_path)
	end
end

return M

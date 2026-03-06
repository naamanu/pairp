local M = {}

function M.open()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "markdown"

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Pairp ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, desc = "Close Pairp window" })

	return { buf = buf, win = win }
end

function M.set_title(handle, title)
	if not vim.api.nvim_win_is_valid(handle.win) then
		return
	end
	vim.api.nvim_win_set_config(handle.win, { title = " " .. title .. " ", title_pos = "center" })
end

function M.append(handle, text)
	if not vim.api.nvim_buf_is_valid(handle.buf) then
		return
	end

	local lines = vim.split(text, "\n", { plain = true })
	local last_line = vim.api.nvim_buf_line_count(handle.buf)
	local last_text = vim.api.nvim_buf_get_lines(handle.buf, last_line - 1, last_line, false)[1] or ""

	-- Append first chunk to the current last line
	vim.api.nvim_buf_set_lines(handle.buf, last_line - 1, last_line, false, { last_text .. lines[1] })

	-- Add remaining lines
	if #lines > 1 then
		vim.api.nvim_buf_set_lines(handle.buf, -1, -1, false, { unpack(lines, 2) })
	end

	-- Scroll to bottom
	if vim.api.nvim_win_is_valid(handle.win) then
		local new_last = vim.api.nvim_buf_line_count(handle.buf)
		vim.api.nvim_win_set_cursor(handle.win, { new_last, 0 })
	end
end

return M

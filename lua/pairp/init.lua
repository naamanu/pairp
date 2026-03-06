local window = require("pairp.window")

local M = {}

M.config = {
	keymap = "<leader>cc",
	send_keymap = "<leader>cs",
	context_keymap = "<leader>cx",
	cli_path = "claude",
	position = "right", -- "right", "left", "center", "top", "bottom"
	width = 0.4,
	height = 0.8,
	watch_interval = 500,
}

function M.setup(opts)
	if vim.fn.has("nvim-0.10") ~= 1 then
		vim.notify("Pairp requires Neovim >= 0.10", vim.log.levels.ERROR)
		return
	end

	opts = opts or {}
	if type(opts) ~= "table" then
		vim.notify("Pairp: setup options must be a table", vim.log.levels.ERROR)
		return
	end
	for k, v in pairs(opts) do
		M.config[k] = v
	end

	vim.keymap.set("n", M.config.keymap, function()
		M.toggle()
	end, { desc = "Pairp: toggle Claude Code" })

	vim.keymap.set("v", M.config.send_keymap, function()
		M.send_selection()
	end, { desc = "Pairp: send selection to Claude" })

	vim.keymap.set("n", M.config.context_keymap, function()
		M.send_context()
	end, { desc = "Pairp: send current file context" })
end

function M.toggle(session_name)
	window.toggle(M.config.cli_path, M.config.position, M.config, session_name)
end

function M.open(session_name)
	window.open(M.config.cli_path, M.config.position, M.config, session_name)
end

function M.close(session_name)
	window.close(session_name)
end

function M.send_selection(session_name)
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
	if #lines == 0 then
		return
	end
	local text = table.concat(lines, "\n") .. "\n"
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	window.send_text(text, session_name)
end

function M.send_context(session_name)
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("Pairp: current buffer has no file", vim.log.levels.WARN)
		return
	end
	window.send_text("Current file: " .. file .. "\n", session_name)
end

function M.send_file(session_name)
	local file = vim.api.nvim_buf_get_name(0)
	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if #buf_lines == 0 then
		vim.notify("Pairp: buffer is empty", vim.log.levels.WARN)
		return
	end
	local header = file ~= "" and ("--- " .. file .. " ---\n") or "--- untitled buffer ---\n"
	local text = header .. table.concat(buf_lines, "\n") .. "\n"
	window.send_text(text, session_name)
end

return M

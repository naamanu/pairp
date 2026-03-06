local window = require("pairp.window")

local M = {}

M.config = {
	keymap = "<leader>cc",
	cli_path = "claude",
}

function M.setup(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		M.config[k] = v
	end

	vim.keymap.set("n", M.config.keymap, function()
		M.toggle()
	end, { desc = "Pairp: toggle Claude Code" })
end

function M.toggle()
	window.toggle(M.config.cli_path)
end

function M.open()
	window.open(M.config.cli_path)
end

return M

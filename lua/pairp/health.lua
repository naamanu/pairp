local M = {}

M.check = function()
	vim.health.start("pairp")

	if vim.fn.has("nvim-0.10") == 1 then
		vim.health.ok("Neovim >= 0.10")
	else
		vim.health.warn("Neovim >= 0.10 is recommended")
	end

	local cli_path = require("pairp").config.cli_path
	if vim.fn.executable(cli_path) == 1 then
		vim.health.ok(cli_path .. " found in PATH")
	else
		vim.health.error(cli_path .. " not found in PATH", {
			"Install Claude Code: npm install -g @anthropic-ai/claude-code",
			"Or set a custom path: require('pairp').setup({ cli_path = '/path/to/claude' })",
		})
	end
end

return M

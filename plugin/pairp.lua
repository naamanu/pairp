if vim.g.loaded_pairp then
	return
end
vim.g.loaded_pairp = true

vim.api.nvim_create_user_command("Pairp", function(opts)
	require("pairp").run(opts.args)
end, {
	nargs = "?",
	desc = "Send a prompt to Claude Code",
})

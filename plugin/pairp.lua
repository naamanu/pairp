if vim.g.loaded_pairp then
	return
end
vim.g.loaded_pairp = true

vim.api.nvim_create_user_command("Pairp", function()
	require("pairp").toggle()
end, {
	desc = "Toggle Claude Code chat window",
})

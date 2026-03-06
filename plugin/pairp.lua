if vim.g.loaded_pairp then
	return
end
vim.g.loaded_pairp = true

vim.api.nvim_create_user_command("Pairp", function(opts)
	local session = opts.args ~= "" and opts.args or nil
	require("pairp").toggle(session)
end, {
	desc = "Toggle Claude Code chat window",
	nargs = "?",
})

vim.api.nvim_create_user_command("PairpSend", function(opts)
	local session = opts.fargs[1]
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, opts.line1 - 1, opts.line2, false)
	local text = table.concat(lines, "\n") .. "\n"
	require("pairp.window").send_text(text, session)
end, {
	desc = "Send selection to Claude Code",
	range = true,
	nargs = "?",
})

vim.api.nvim_create_user_command("PairpContext", function(opts)
	local session = opts.args ~= "" and opts.args or nil
	require("pairp").send_context(session)
end, {
	desc = "Send current file context to Claude Code",
	nargs = "?",
})

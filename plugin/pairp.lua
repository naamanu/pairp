if vim.g.loaded_pairp then
	return
end
vim.g.loaded_pairp = true

local function session_complete()
	return require("pairp.window").list_sessions()
end

vim.api.nvim_create_user_command("PairpToggle", function(opts)
	local session = opts.args ~= "" and opts.args or nil
	require("pairp").toggle(session)
end, {
	desc = "Toggle Claude Code chat window",
	nargs = "?",
	complete = session_complete,
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
	complete = session_complete,
})

vim.api.nvim_create_user_command("PairpContext", function(opts)
	local session = opts.args ~= "" and opts.args or nil
	require("pairp").send_context(session)
end, {
	desc = "Send current file path to Claude Code",
	nargs = "?",
	complete = session_complete,
})

vim.api.nvim_create_user_command("PairpSendFile", function(opts)
	local session = opts.args ~= "" and opts.args or nil
	require("pairp").send_file(session)
end, {
	desc = "Send entire buffer contents to Claude Code",
	nargs = "?",
	complete = session_complete,
})

vim.api.nvim_create_user_command("PairpList", function()
	local sessions = require("pairp.window").list_sessions()
	if #sessions == 0 then
		vim.notify("Pairp: no active sessions", vim.log.levels.INFO)
	else
		vim.notify("Pairp sessions: " .. table.concat(sessions, ", "), vim.log.levels.INFO)
	end
end, {
	desc = "List active Pairp sessions",
})

vim.api.nvim_create_user_command("PairpClose", function(opts)
	local session = opts.args ~= "" and opts.args or nil
	require("pairp").close(session)
end, {
	desc = "Close a Pairp session",
	nargs = "?",
	complete = session_complete,
})

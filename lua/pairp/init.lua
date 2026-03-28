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
	system_prompt = "",
	menu_keymap = "<leader>cm",
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

	local valid_positions = { right = true, left = true, center = true, top = true, bottom = true }
	if not valid_positions[M.config.position] then
		vim.notify("Pairp: invalid position '" .. tostring(M.config.position) .. "', using 'right'", vim.log.levels.WARN)
		M.config.position = "right"
	end
	if type(M.config.width) ~= "number" or M.config.width < 0.1 or M.config.width > 1.0 then
		vim.notify("Pairp: width must be a number between 0.1 and 1.0, using 0.4", vim.log.levels.WARN)
		M.config.width = 0.4
	end
	if type(M.config.height) ~= "number" or M.config.height < 0.1 or M.config.height > 1.0 then
		vim.notify("Pairp: height must be a number between 0.1 and 1.0, using 0.8", vim.log.levels.WARN)
		M.config.height = 0.8
	end
	if type(M.config.watch_interval) ~= "number" or M.config.watch_interval <= 0 then
		vim.notify("Pairp: watch_interval must be a positive number, using 500", vim.log.levels.WARN)
		M.config.watch_interval = 500
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

	vim.keymap.set("n", M.config.menu_keymap, function()
		M.show_menu()
	end, { desc = "Pairp: open actions menu" })
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

function M.switch()
	local session_names = window.list_sessions()
	if #session_names == 0 then
		vim.notify("Pairp: no active sessions", vim.log.levels.INFO)
		return
	end
	if #session_names == 1 then
		window.show_session(session_names[1], M.config)
		return
	end
	-- Prefer Telescope if available
	local has_telescope, _ = pcall(require, "telescope")
	if has_telescope then
		vim.cmd("Telescope pairp sessions")
		return
	end
	vim.ui.select(session_names, { prompt = "Switch to Pairp session:" }, function(choice)
		if choice then
			window.show_session(choice, M.config)
		end
	end)
end

function M.send_selection(session_name)
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local lines = vim.fn.getregion(start_pos, end_pos, { type = vim.fn.mode() })
	if #lines == 0 then
		return
	end

	local file = vim.api.nvim_buf_get_name(0)
	local start_line = start_pos[2]
	local end_line = end_pos[2]
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local header = ""
	if file ~= "" then
		local rel = vim.fn.fnamemodify(file, ":.")
		header = "From " .. rel .. ":" .. start_line .. "-" .. end_line .. ":\n"
	end

	local text = header .. table.concat(lines, "\n") .. "\n"
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

function M.send_diff(session_name)
	local result = vim.fn.systemlist({ "git", "diff", "--no-color" })
	if vim.v.shell_error ~= 0 then
		vim.notify("Pairp: not in a git repository", vim.log.levels.WARN)
		return
	end
	if #result == 0 then
		vim.notify("Pairp: no unstaged changes", vim.log.levels.INFO)
		return
	end
	local text = "Here is the current git diff:\n```diff\n" .. table.concat(result, "\n") .. "\n```\n"
	window.send_text(text, session_name)
end

function M.send_diff_staged(session_name)
	local result = vim.fn.systemlist({ "git", "diff", "--cached", "--no-color" })
	if vim.v.shell_error ~= 0 then
		vim.notify("Pairp: not in a git repository", vim.log.levels.WARN)
		return
	end
	if #result == 0 then
		vim.notify("Pairp: no staged changes", vim.log.levels.INFO)
		return
	end
	local text = "Here is the staged git diff:\n```diff\n" .. table.concat(result, "\n") .. "\n```\n"
	window.send_text(text, session_name)
end

function M.send_diagnostics(session_name)
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	if file == "" then
		vim.notify("Pairp: current buffer has no file", vim.log.levels.WARN)
		return
	end
	local diags = vim.diagnostic.get(buf)
	if #diags == 0 then
		vim.notify("Pairp: no diagnostics in current buffer", vim.log.levels.INFO)
		return
	end
	local severity_labels = { "ERROR", "WARN", "INFO", "HINT" }
	local lines = { "Diagnostics for " .. file .. ":" }
	for _, d in ipairs(diags) do
		local sev = severity_labels[d.severity] or "UNKNOWN"
		table.insert(lines, string.format("  Line %d: [%s] %s", d.lnum + 1, sev, d.message))
	end
	local text = table.concat(lines, "\n") .. "\n"
	window.send_text(text, session_name)
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

function M.review()
	local actions = require("pairp.actions")
	local files = actions.get_tracked_files()
	if #files == 0 then
		vim.notify("Pairp: no files to review", vim.log.levels.INFO)
		return
	end
	-- Filter to files that actually have git changes
	local changed = {}
	for _, file in ipairs(files) do
		vim.fn.system({ "git", "diff", "--quiet", "--", file })
		if vim.v.shell_error ~= 0 then
			table.insert(changed, file)
		end
	end
	if #changed == 0 then
		vim.notify("Pairp: all tracked files are unchanged", vim.log.levels.INFO)
		return
	end
	M._review_files = changed
	M._review_index = 1
	M._open_review_diff(changed[1])
end

function M._open_review_diff(file)
	-- Open the working copy in a new tab
	vim.cmd("tabnew " .. vim.fn.fnameescape(file))
	local working_win = vim.api.nvim_get_current_win()
	vim.cmd("diffthis")

	-- Open the HEAD version in a vertical split
	vim.cmd("vnew")
	local rel_path = vim.fn.fnamemodify(file, ":.")
	local head_content = vim.fn.systemlist({ "git", "show", "HEAD:" .. rel_path })
	if vim.v.shell_error == 0 then
		vim.api.nvim_buf_set_lines(0, 0, -1, false, head_content)
	end
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.modifiable = false
	vim.cmd("diffthis")

	-- Focus the working copy for easier navigation
	vim.api.nvim_set_current_win(working_win)

	-- Set up review keymaps on both buffers in this tab
	local tab = vim.api.nvim_get_current_tabpage()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		local buf = vim.api.nvim_win_get_buf(win)
		vim.keymap.set("n", "ga", function()
			M._accept_current()
		end, { buffer = buf, desc = "Pairp: accept changes" })
		vim.keymap.set("n", "gr", function()
			M._revert_current()
		end, { buffer = buf, desc = "Pairp: revert to HEAD" })
		vim.keymap.set("n", "gn", function()
			M._next_review()
		end, { buffer = buf, desc = "Pairp: next file" })
		vim.keymap.set("n", "gq", function()
			M._close_review()
		end, { buffer = buf, desc = "Pairp: close review" })
	end

	local count = #M._review_files
	vim.notify(
		string.format("Review (%d/%d): [ga] accept  [gr] revert  [gn] next  [gq] close", M._review_index, count),
		vim.log.levels.INFO
	)
end

function M._close_review_tab()
	vim.cmd("diffoff!")
	vim.cmd("tabclose")
end

function M._accept_current()
	M._close_review_tab()
	M._next_review()
end

function M._revert_current()
	local file = M._review_files[M._review_index]
	vim.fn.system({ "git", "checkout", "HEAD", "--", file })
	vim.cmd("silent! checktime")
	M._close_review_tab()
	M._next_review()
end

function M._next_review()
	M._review_index = M._review_index + 1
	if M._review_index > #M._review_files then
		vim.notify("Pairp: review complete", vim.log.levels.INFO)
		M._review_files = nil
		M._review_index = nil
		return
	end
	M._open_review_diff(M._review_files[M._review_index])
end

function M._close_review()
	if M._review_index and M._review_index <= #M._review_files then
		M._close_review_tab()
	end
	M._review_files = nil
	M._review_index = nil
	vim.notify("Pairp: review closed", vim.log.levels.INFO)
end

function M.revert_all()
	local actions = require("pairp.actions")
	local files = actions.get_tracked_files()
	if #files == 0 then
		vim.notify("Pairp: no files to revert", vim.log.levels.INFO)
		return
	end
	for _, file in ipairs(files) do
		vim.fn.system({ "git", "checkout", "HEAD", "--", file })
	end
	vim.cmd("silent! checktime")
	vim.notify("Pairp: reverted " .. #files .. " file(s)", vim.log.levels.INFO)
	actions.clear_tracked_files()
end

function M.show_menu(session_name)
	local items = {
		{ label = "Toggle window", action = function() M.toggle(session_name) end },
		{ label = "Send file", action = function() M.send_file(session_name) end },
		{ label = "Send diff", action = function() M.send_diff(session_name) end },
		{ label = "Send staged diff", action = function() M.send_diff_staged(session_name) end },
		{ label = "Send diagnostics", action = function() M.send_diagnostics(session_name) end },
		{ label = "Review changes", action = function() M.review() end },
		{ label = "Revert all", action = function() M.revert_all() end },
		{ label = "Switch session", action = function() M.switch() end },
	}
	vim.ui.select(
		vim.tbl_map(function(item)
			return item.label
		end, items),
		{ prompt = "Pairp Actions:" },
		function(_, idx)
			if idx then
				items[idx].action()
			end
		end
	)
end

function M.statusline()
	local session_names = window.list_sessions()
	if #session_names == 0 then
		return ""
	end
	if #session_names == 1 then
		return "Pairp: " .. session_names[1]
	end
	return "Pairp: " .. #session_names .. " sessions"
end

return M

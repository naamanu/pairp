local M = {}

local sessions = {}

local function normalize_session_name(name)
	if name == nil or name == "" then
		return "default"
	end
	return name
end

local function get_state(name)
	return sessions[normalize_session_name(name)]
end

local function ensure_state(name)
	local session_name = normalize_session_name(name)
	if not sessions[session_name] then
		sessions[session_name] = { buf = nil, win = nil, chan = nil, name = session_name }
	end
	return sessions[session_name]
end

local function clear_state(name)
	sessions[normalize_session_name(name)] = nil
end

local function clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function safe_chansend(chan, text, session_name)
	local ok = vim.fn.chansend(chan, text)
	if ok == 0 then
		local label = session_name or "default"
		vim.notify("Pairp [" .. label .. "]: failed to send to terminal (channel dead)", vim.log.levels.ERROR)
		return false
	end
	return true
end

local function setup_highlights()
	local has_border = vim.api.nvim_get_hl(0, { name = "PairpBorder" })
	if vim.tbl_isempty(has_border) then
		vim.api.nvim_set_hl(0, "PairpBorder", { link = "FloatBorder" })
	end

	local has_title = vim.api.nvim_get_hl(0, { name = "PairpTitle" })
	if vim.tbl_isempty(has_title) then
		vim.api.nvim_set_hl(0, "PairpTitle", { link = "Title" })
	end

	local has_footer = vim.api.nvim_get_hl(0, { name = "PairpFooter" })
	if vim.tbl_isempty(has_footer) then
		vim.api.nvim_set_hl(0, "PairpFooter", { link = "Comment" })
	end

	local has_normal = vim.api.nvim_get_hl(0, { name = "PairpNormal" })
	if vim.tbl_isempty(has_normal) then
		vim.api.nvim_set_hl(0, "PairpNormal", { link = "NormalFloat" })
	end
end

local function is_valid(state)
	return state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.win and vim.api.nvim_win_is_valid(state.win)
end

local function build_border()
	return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
end

local function win_opts(position, config, session_name)
	local columns = math.max(1, vim.o.columns)
	local lines = math.max(3, vim.o.lines - 2)

	local width_value = (config and type(config.width) == "number") and config.width or 0.4
	local height_value = (config and type(config.height) == "number") and config.height or 0.8
	local width_pct = clamp(width_value, 0.1, 1)
	local height_pct = clamp(height_value, 0.1, 1)
	local min_width = math.min(20, columns)
	local min_height = math.min(5, lines)

	local width, height, row, col

	if position == "right" then
		width = clamp(math.floor(columns * width_pct), min_width, columns)
		height = lines
		row = 0
		col = columns - width
	elseif position == "left" then
		width = clamp(math.floor(columns * width_pct), min_width, columns)
		height = lines
		row = 0
		col = 0
	elseif position == "top" then
		width = columns
		height = clamp(math.floor(lines * height_pct), min_height, lines)
		row = 0
		col = 0
	elseif position == "bottom" then
		width = columns
		height = clamp(math.floor(lines * height_pct), min_height, lines)
		row = lines - height
		col = 0
	else -- "center"
		width = clamp(math.floor(columns * width_pct), min_width, columns)
		height = clamp(math.floor(lines * height_pct), min_height, lines)
		row = math.floor((lines - height) / 2)
		col = math.floor((columns - width) / 2)
	end

	row = math.max(0, row)
	col = math.max(0, col)

	local display_name = (session_name and session_name ~= "default") and session_name or nil
	local title = display_name and (" Pairp: " .. display_name .. " ") or " Pairp "

	local border_chars = build_border()
	local border = {}
	for _, ch in ipairs(border_chars) do
		table.insert(border, { ch, "PairpBorder" })
	end

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = border,
		title = { { title, "PairpTitle" } },
		title_pos = "center",
		footer = { { " <C-q>:hide  <Esc><Esc>:normal  <C-w>:navigate ", "PairpFooter" } },
		footer_pos = "center",
	}
end

function M.open(cli_path, position, config, session_name)
	setup_highlights()

	if vim.fn.executable(cli_path) ~= 1 then
		vim.notify("Pairp: CLI not found: " .. cli_path, vim.log.levels.ERROR)
		return
	end

	local state = ensure_state(session_name)

	-- If already open, focus it and enter insert mode
	if is_valid(state) then
		vim.api.nvim_set_current_win(state.win)
		vim.cmd.startinsert()
		return
	end

	local opts = win_opts(position, config, session_name)

	-- Reuse existing buffer if the terminal is still running
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.chan then
		state.win = vim.api.nvim_open_win(state.buf, true, opts)
		vim.api.nvim_set_option_value("winhl", "Normal:PairpNormal,FloatBorder:PairpBorder", { win = state.win })
		vim.cmd.startinsert()
		return
	end

	-- Create a new terminal buffer
	state.buf = vim.api.nvim_create_buf(false, true)
	state.win = vim.api.nvim_open_win(state.buf, true, opts)
	vim.api.nvim_set_option_value("winhl", "Normal:PairpNormal,FloatBorder:PairpBorder", { win = state.win })

	-- Inject pairp bin directory into PATH so Claude can use pairp-nvim
	local bin_candidates = vim.api.nvim_get_runtime_file("bin/pairp-nvim", false)
	local bin_dir
	if bin_candidates and #bin_candidates > 0 then
		bin_dir = vim.fn.fnamemodify(bin_candidates[1], ":h")
	else
		local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
		bin_dir = plugin_root .. "/bin"
	end
	local env = {
		PAIRP = "1",
		PATH = bin_dir .. ":" .. (vim.env.PATH or ""),
	}

	-- Start file watcher so buffers auto-reload when Claude edits files
	local actions = require("pairp.actions")
	actions.start_watcher(config and config.watch_interval or 500)

	local augroup = nil
	local function cleanup_state()
		state.chan = nil
		actions.stop_watcher()
		if augroup then
			pcall(vim.api.nvim_del_augroup_by_id, augroup)
			augroup = nil
		end
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_close(state.win, true)
		end
		if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
			vim.api.nvim_buf_delete(state.buf, { force = true })
		end
		state.buf = nil
		state.win = nil
		clear_state(state.name)
	end

	-- Build command with pairp-nvim instructions appended to Claude's system prompt
	local pairp_prompt = table.concat({
		"You are running inside Neovim via the Pairp plugin.",
		"You have access to the `pairp-nvim` CLI tool which controls the parent Neovim editor.",
		"IMPORTANT: Before you create, read, or edit any file, ALWAYS first run `pairp-nvim open <filepath>` to open it in the user's editor buffer so they can watch your changes in real-time.",
		"Neovim will automatically reload buffers when you write to files on disk.",
		"The user can see the file in their editor as you work on it.",
		"Use the editor buffer as the primary surface for showing code changes - the user is watching the file update live.",
		"Do NOT paste large code blocks in this terminal. Instead, write changes directly to the file so the user sees them in the editor.",
		"After making changes to a file, ask the user to review the changes in their editor buffer and confirm before moving on.",
		"Available commands:",
		"  pairp-nvim open <file> [line] [col]  - open a file in the editor",
		"  pairp-nvim buffers                   - list open editor buffers",
	}, " ")

	if config and config.system_prompt and config.system_prompt ~= "" then
		pairp_prompt = pairp_prompt .. "\n" .. config.system_prompt
	end

	local cmd = { cli_path, "--append-system-prompt", pairp_prompt }

	state.chan = vim.fn.termopen(cmd, {
		env = env,
		on_exit = function()
			cleanup_state()
		end,
	})

	if state.chan <= 0 then
		cleanup_state()
		vim.notify("Pairp: failed to start Claude Code", vim.log.levels.ERROR)
		return
	end

	vim.cmd.startinsert()

	-- q in normal mode hides the window (keeps terminal alive)
	vim.keymap.set("n", "q", function()
		M.hide(session_name)
	end, { buffer = state.buf, desc = "Hide Pairp window" })

	-- Double <Esc> exits terminal mode
	vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = state.buf, desc = "Exit terminal mode" })

	-- <C-q> hides the window from terminal mode
	vim.keymap.set("t", "<C-q>", function()
		M.hide(session_name)
	end, { buffer = state.buf, desc = "Hide Pairp window" })

	-- <C-w> navigation from terminal mode
	for _, key in ipairs({ "h", "j", "k", "l" }) do
		vim.keymap.set("t", "<C-w>" .. key, function()
			vim.cmd.stopinsert()
			vim.cmd.wincmd(key)
		end, { buffer = state.buf, desc = "Navigate to window " .. key })
	end

	-- Re-enter terminal mode when the Pairp window regains focus
	-- Without this, the cursor behaves oddly because the terminal buffer
	-- is left in normal mode after navigating away and back.
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		buffer = state.buf,
		callback = function()
			if state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_get_current_win() == state.win then
				vim.cmd.startinsert()
			end
		end,
	})

	-- Reposition window on terminal resize
	augroup = vim.api.nvim_create_augroup("pairp_resize_" .. state.name, { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = augroup,
		callback = function()
			if is_valid(state) then
				vim.api.nvim_win_set_config(state.win, win_opts(position, config, session_name))
			end
		end,
	})
end

function M.hide(session_name)
	local state = get_state(session_name)
	if not state then
		return
	end
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
		state.win = nil
	end
end

function M.show_session(session_name, config)
	local target = get_state(session_name)
	if not target then
		vim.notify("Pairp: session not found: " .. tostring(session_name), vim.log.levels.WARN)
		return
	end
	-- Hide all other visible sessions
	for name, state in pairs(sessions) do
		if name ~= normalize_session_name(session_name) and state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_close(state.win, true)
			state.win = nil
		end
	end
	-- Show the target session
	if target.buf and vim.api.nvim_buf_is_valid(target.buf) and target.chan then
		if not (target.win and vim.api.nvim_win_is_valid(target.win)) then
			local position = config and config.position or "right"
			local opts = win_opts(position, config, session_name)
			target.win = vim.api.nvim_open_win(target.buf, true, opts)
			vim.api.nvim_set_option_value("winhl", "Normal:PairpNormal,FloatBorder:PairpBorder", { win = target.win })
		end
		vim.api.nvim_set_current_win(target.win)
		vim.cmd.startinsert()
	end
end

function M.close(session_name)
	local state = get_state(session_name)
	if not state then
		return
	end
	if state.chan then
		vim.fn.jobstop(state.chan)
	else
		clear_state(session_name)
	end
end

function M.toggle(cli_path, position, config, session_name)
	local state = get_state(session_name)
	if state and is_valid(state) then
		M.hide(session_name)
	else
		M.open(cli_path, position, config, session_name)
	end
end

function M.send_text(text, session_name)
	local state = get_state(session_name)
	if not state or not state.chan then
		vim.notify("Pairp: no active session", vim.log.levels.WARN)
		return false
	end
	return safe_chansend(state.chan, text, state.name)
end

function M.list_sessions()
	local names = {}
	local stale = {}
	for name, state in pairs(sessions) do
		local has_buf = state.buf and vim.api.nvim_buf_is_valid(state.buf)
		local has_win = state.win and vim.api.nvim_win_is_valid(state.win)
		if state.chan or has_buf or has_win then
			table.insert(names, name)
		else
			table.insert(stale, name)
		end
	end
	for _, name in ipairs(stale) do
		sessions[name] = nil
	end
	table.sort(names)
	return names
end

function M.get_session_details()
	local details = {}
	local stale = {}
	for name, state in pairs(sessions) do
		local has_buf = state.buf and vim.api.nvim_buf_is_valid(state.buf)
		local has_win = state.win and vim.api.nvim_win_is_valid(state.win)
		if state.chan or has_buf or has_win then
			table.insert(details, {
				name = name,
				visible = has_win and true or false,
				has_channel = state.chan ~= nil,
			})
		else
			table.insert(stale, name)
		end
	end
	for _, name in ipairs(stale) do
		sessions[name] = nil
	end
	table.sort(details, function(a, b)
		return a.name < b.name
	end)
	return details
end

return M

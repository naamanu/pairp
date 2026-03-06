local M = {}

local sessions = {}

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

local function get_state(name)
	name = name or "default"
	if not sessions[name] then
		sessions[name] = { buf = nil, win = nil, chan = nil, name = name }
	end
	return sessions[name]
end

local function is_valid(state)
	return state.buf
		and vim.api.nvim_buf_is_valid(state.buf)
		and state.win
		and vim.api.nvim_win_is_valid(state.win)
end

local function build_border(position)
	if position == "right" then
		return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
	elseif position == "left" then
		return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
	elseif position == "top" or position == "bottom" then
		return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
	else -- center
		return { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
	end
end

local function win_opts(position, config, session_name)
	local columns = vim.o.columns
	local lines = vim.o.lines

	local width_pct = (config and config.width) or 0.4
	local height_pct = (config and config.height) or 0.8

	local width, height, row, col

	if position == "right" then
		width = math.floor(columns * width_pct)
		height = lines - 2
		row = 0
		col = columns - width
	elseif position == "left" then
		width = math.floor(columns * width_pct)
		height = lines - 2
		row = 0
		col = 0
	elseif position == "top" then
		width = columns
		height = math.floor(lines * height_pct)
		row = 0
		col = 0
	elseif position == "bottom" then
		width = columns
		height = math.floor(lines * height_pct)
		row = lines - height - 2
		col = 0
	else -- "center"
		width = math.floor(columns * width_pct)
		height = math.floor(lines * height_pct)
		row = math.floor((lines - height) / 2)
		col = math.floor((columns - width) / 2)
	end

	local display_name = (session_name and session_name ~= "default") and session_name or nil
	local title = display_name and (" Pairp: " .. display_name .. " ") or " Pairp "

	local border_chars = build_border(position)
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
	local state = get_state(session_name)

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

	state.chan = vim.fn.termopen(cli_path, {
		on_exit = function()
			state.chan = nil
			if is_valid(state) then
				vim.api.nvim_win_close(state.win, true)
			end
			if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
				vim.api.nvim_buf_delete(state.buf, { force = true })
			end
			state.buf = nil
			state.win = nil
			sessions[state.name] = nil
		end,
	})

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

	-- Reposition window on terminal resize
	local augroup = vim.api.nvim_create_augroup("pairp_resize_" .. state.name, { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = augroup,
		callback = function()
			if is_valid(state) then
				vim.api.nvim_win_set_config(state.win, win_opts(position, config, session_name))
			else
				vim.api.nvim_del_augroup_by_id(augroup)
			end
		end,
	})
end

function M.hide(session_name)
	local state = get_state(session_name)
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
		state.win = nil
	end
end

function M.close(session_name)
	local state = get_state(session_name)
	if state.chan then
		vim.fn.jobstop(state.chan)
	end
end

function M.toggle(cli_path, position, config, session_name)
	local state = get_state(session_name)
	if is_valid(state) then
		M.hide(session_name)
	else
		M.open(cli_path, position, config, session_name)
	end
end

function M.send_text(text, session_name)
	local state = get_state(session_name)
	if not state.chan then
		vim.notify("Pairp: no active session", vim.log.levels.WARN)
		return
	end
	vim.fn.chansend(state.chan, text)
end

function M.list_sessions()
	local names = {}
	for name, _ in pairs(sessions) do
		table.insert(names, name)
	end
	return names
end

return M

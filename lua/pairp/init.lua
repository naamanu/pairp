local process = require("pairp.process")
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
		M.prompt()
	end, { desc = "Pairp: prompt Claude Code" })
end

function M.prompt()
	vim.ui.input({ prompt = "Pairp> " }, function(input)
		if not input or input == "" then
			return
		end
		M.run(input)
	end)
end

function M.run(input)
	if not input or input == "" then
		M.prompt()
		return
	end

	local win = window.open()

	window.set_title(win, "Pairp: thinking...")

	process.exec(M.config.cli_path, input, {
		on_stdout = function(chunk)
			vim.schedule(function()
				window.append(win, chunk)
			end)
		end,
		on_exit = function(code)
			vim.schedule(function()
				if code == 0 then
					window.set_title(win, "Pairp: done")
				else
					window.set_title(win, "Pairp: error (exit " .. code .. ")")
				end
			end)
		end,
	})
end

return M

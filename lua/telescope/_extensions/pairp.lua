local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	return
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.action_state")

local function sessions(opts)
	opts = opts or {}

	local pairp_window = require("pairp.window")
	local pairp_config = require("pairp").config
	local details = pairp_window.get_session_details()

	if #details == 0 then
		vim.notify("Pairp: no active sessions", vim.log.levels.INFO)
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Pairp Sessions",
			finder = finders.new_table({
				results = details,
				entry_maker = function(entry)
					local status = entry.visible and "visible" or "hidden"
					local display = entry.name .. " [" .. status .. "]"
					return {
						value = entry,
						display = display,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				-- Default: switch to session
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						pairp_window.show_session(selection.value.name, pairp_config)
					end
				end)

				-- <C-d>: close/kill session
				map("i", "<C-d>", function()
					local selection = action_state.get_selected_entry()
					if selection then
						require("pairp").close(selection.value.name)
						-- Refresh picker
						local current_picker = action_state.get_current_picker(prompt_bufnr)
						local new_details = pairp_window.get_session_details()
						current_picker:refresh(finders.new_table({
							results = new_details,
							entry_maker = function(entry)
								local status = entry.visible and "visible" or "hidden"
								local display = entry.name .. " [" .. status .. "]"
								return {
									value = entry,
									display = display,
									ordinal = entry.name,
								}
							end,
						}))
					end
				end)

				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	exports = {
		sessions = sessions,
	},
})

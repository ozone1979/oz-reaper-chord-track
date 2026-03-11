local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local core = dofile(script_path .. "Oz Chord Track Core.lua")

local _, _, section_id, command_id = reaper.get_action_context()

local function set_action_toggle(state)
	if not section_id or not command_id or command_id == 0 then
		return
	end
	reaper.SetToggleCommandState(section_id, command_id, state and 1 or 0)
	reaper.RefreshToolbar2(section_id, command_id)
end

set_action_toggle(true)
reaper.atexit(function()
	set_action_toggle(false)
end)

core.run_dockable_panel()

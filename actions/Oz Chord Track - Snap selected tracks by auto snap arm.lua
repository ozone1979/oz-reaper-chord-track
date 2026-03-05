local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local core = dofile(script_path .. "Oz Chord Track Core.lua")
core.snap_selected_tracks_by_auto_snap_arm_mode()
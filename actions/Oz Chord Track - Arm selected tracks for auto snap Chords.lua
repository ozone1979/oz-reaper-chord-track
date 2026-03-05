local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local core = dofile(script_path .. "Oz Chord Track Core.lua")
core.arm_selected_tracks_for_auto_snap("chords")

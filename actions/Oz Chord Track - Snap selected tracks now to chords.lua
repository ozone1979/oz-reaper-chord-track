local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local core = dofile(script_path .. "Oz Chord Track Core.lua")
core.snap_selected_tracks_now("chord_only")

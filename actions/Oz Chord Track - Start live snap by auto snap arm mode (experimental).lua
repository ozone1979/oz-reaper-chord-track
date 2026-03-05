local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local core = dofile(script_path .. "Oz Chord Track Core.lua")
core.start_new_note_snap("post", nil)
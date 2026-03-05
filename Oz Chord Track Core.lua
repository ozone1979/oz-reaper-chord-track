local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local loader = dofile(script_path .. "libs/Oz Chord Track Loader.lua")
return loader.load_core(script_path)

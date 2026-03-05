local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
return dofile(script_path .. "../Oz Chord Track Core.lua")

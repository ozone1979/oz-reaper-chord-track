local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local loader = dofile(script_path .. "../libs/Oz Chord Track Loader.lua")
local ok, err = loader.run_internal(script_path, "Oz Chord Track - Stop input snap manager (experimental).lua")
if not ok then
	reaper.MB(tostring(err or "Could not stop input snap manager."), "Oz Reaper Chord Track", 0)
end

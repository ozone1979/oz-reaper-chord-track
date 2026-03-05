local MANAGER_SECTION = "OZ_REAPER_CHORD_TRACK_INPUT_MANAGER"
local SNAP_MODE_OVERRIDE_KEY = "SNAP_MODE_OVERRIDE"

local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local loader = dofile(script_path .. "../libs/Oz Chord Track Loader.lua")

local previous_override = reaper.GetExtState(MANAGER_SECTION, SNAP_MODE_OVERRIDE_KEY)

local _, _ = loader.run_internal(script_path, "Oz Chord Track - Stop input snap manager (experimental).lua")

if previous_override and previous_override ~= "" then
  reaper.SetExtState(MANAGER_SECTION, SNAP_MODE_OVERRIDE_KEY, previous_override, false)
end

local _, _ = loader.run_internal(script_path, "Oz Chord Track - Start input snap manager (experimental).lua")

local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local core = dofile(script_path .. "Oz Chord Track Core.lua")

if core and core.ensure_input_snap_jsfx then
  core.ensure_input_snap_jsfx()
else
  reaper.MB("Could not access ensure_input_snap_jsfx() in core.", "Oz Reaper Chord Track", 0)
end

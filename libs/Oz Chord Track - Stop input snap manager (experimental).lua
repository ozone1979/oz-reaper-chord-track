local MANAGER_SECTION = "OZ_REAPER_CHORD_TRACK_INPUT_MANAGER"
local RUN_TOKEN_KEY = "RUN_TOKEN"
local STATUS_KEY = "STATUS"
local SNAP_MODE_OVERRIDE_KEY = "SNAP_MODE_OVERRIDE"

local GMEM_NAMESPACE = "OZ_REAPER_CHORD_TRACK_INPUT_SNAP"
local REC_FX_OFFSET = 0x1000000

local GMEM_VERSION = 0
local GMEM_CHORD_COUNT = 1
local GMEM_SCALE_COUNT = 2
local GMEM_HEARTBEAT = 3
local GMEM_RUNNING = 4
local GMEM_ALLOW_INVERSIONS = 5
local GMEM_CHORD_BASE = 8
local GMEM_SCALE_BASE = 24

local function as_number(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    return tonumber(value)
  end
  return nil
end

local function normalize_fx_name(name)
  local value = tostring(name or ""):lower()
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("^js:%s*", "")
  value = value:gsub("\\", "/")
  return value
end

local function is_input_snap_fx_name(name)
  local normalized = normalize_fx_name(name)
  return normalized:find("oz chord track input snap", 1, true) ~= nil
end

local function list_input_snap_fx_indices(track)
  local indices = {}
  if not reaper.TrackFX_GetRecCount then
    return indices
  end

  local rec_count = reaper.TrackFX_GetRecCount(track)
  for i = 0, rec_count - 1 do
    local fx_index = REC_FX_OFFSET + i
    local ok, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
    if ok and is_input_snap_fx_name(fx_name) then
      indices[#indices + 1] = fx_index
    end
  end

  return indices
end

local function disable_input_fx_on_track(track)
  local indices = list_input_snap_fx_indices(track)
  if #indices == 0 then
    return
  end

  for i = #indices, 1, -1 do
    local fx_index = indices[i]
    reaper.TrackFX_SetParam(track, fx_index, 1, 0)
    if reaper.TrackFX_SetEnabled then
      reaper.TrackFX_SetEnabled(track, fx_index, false)
    end
    reaper.TrackFX_Delete(track, indices[i])
  end
end

local function clear_shared_memory()
  if not reaper.gmem_attach or not reaper.gmem_write or not reaper.gmem_read then
    return
  end

  reaper.gmem_attach(GMEM_NAMESPACE)

  local version = math.floor(as_number(reaper.gmem_read(GMEM_VERSION)) or 0) + 1
  reaper.gmem_write(GMEM_CHORD_COUNT, 0)
  reaper.gmem_write(GMEM_SCALE_COUNT, 0)
  reaper.gmem_write(GMEM_ALLOW_INVERSIONS, 0)
  for pc = 0, 11 do
    reaper.gmem_write(GMEM_CHORD_BASE + pc, 0)
    reaper.gmem_write(GMEM_SCALE_BASE + pc, 0)
  end
  reaper.gmem_write(GMEM_RUNNING, 0)
  reaper.gmem_write(GMEM_HEARTBEAT, reaper.time_precise())
  reaper.gmem_write(GMEM_VERSION, version)
end

reaper.SetExtState(MANAGER_SECTION, RUN_TOKEN_KEY, "", false)
reaper.SetExtState(MANAGER_SECTION, STATUS_KEY, "stopping", false)
reaper.SetExtState(MANAGER_SECTION, SNAP_MODE_OVERRIDE_KEY, "", false)

local track_count = reaper.CountTracks(0)
for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  disable_input_fx_on_track(track)
end

clear_shared_memory()
reaper.SetExtState(MANAGER_SECTION, STATUS_KEY, "stopped", false)

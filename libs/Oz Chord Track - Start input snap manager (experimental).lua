local EXT_SECTION = "OZ_REAPER_CHORD_TRACK"
local MANAGER_SECTION = "OZ_REAPER_CHORD_TRACK_INPUT_MANAGER"
local RUN_TOKEN_KEY = "RUN_TOKEN"
local STATUS_KEY = "STATUS"
local SNAP_MODE_OVERRIDE_KEY = "SNAP_MODE_OVERRIDE"

local FX_NAME = "JS:ReaTrak/Oz Chord Track Input Snap"
local FX_NAME_FALLBACK = "JS: Oz Chord Track Input Snap"
local GMEM_NAMESPACE = "OZ_REAPER_CHORD_TRACK_INPUT_SNAP"
local REC_FX_OFFSET = 0x1000000

local GMEM_VERSION = 0
local GMEM_CHORD_COUNT = 1
local GMEM_SCALE_COUNT = 2
local GMEM_HEARTBEAT = 3
local GMEM_RUNNING = 4
local GMEM_CHORD_BASE = 8
local GMEM_SCALE_BASE = 24

local AUTO_SNAP_ARM_KEY_PREFIX = "AUTO_SNAP_ARM_MODE_"
local AUTO_SNAP_ARM_MODE_OFF = "off"
local AUTO_SNAP_ARM_MODE_CHORDS = "chords"
local AUTO_SNAP_ARM_MODE_SCALES = "scales"
local AUTO_SNAP_ARM_MODE_CHORDS_SCALES = "chords_scales"

local MODE_TO_JSFX_PARAM = {
  [AUTO_SNAP_ARM_MODE_CHORDS] = 0,
  [AUTO_SNAP_ARM_MODE_SCALES] = 1,
  [AUTO_SNAP_ARM_MODE_CHORDS_SCALES] = 2,
}

local JSFX_ADD_NAME_CANDIDATES = {
  FX_NAME,
  "JS:Oz Reaper Chord Track/Oz Chord Track Input Snap",
  "JS:Oz Chord Track Input Snap",
  FX_NAME_FALLBACK,
}

local cached_discovered_jsfx_add_names = nil

local function csv_to_set(csv)
  local set = {}
  if not csv or csv == "" then return set end
  for token in csv:gmatch("[^,]+") do
    local value = tonumber(token)
    if value then
      set[value % 12] = true
    end
  end
  return set
end

local function as_number(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    return tonumber(value)
  end
  return nil
end

local function set_count(pitch_set)
  local total = 0
  for _, enabled in pairs(pitch_set or {}) do
    if enabled then
      total = total + 1
    end
  end
  return total
end

local function set_to_signature(pitch_set)
  local parts = {}
  for pc = 0, 11 do
    parts[#parts + 1] = pitch_set[pc] and "1" or "0"
  end
  return table.concat(parts, "")
end

local function get_track_guid(track)
  if not track then return nil end
  local _, guid = reaper.GetSetMediaTrackInfo_String(track, "GUID", "", false)
  return guid
end

local function find_track_by_guid(guid)
  if not guid or guid == "" then return nil end
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if get_track_guid(track) == guid then
      return track
    end
  end
  return nil
end

local function auto_snap_arm_key_for_track(track)
  local guid = get_track_guid(track)
  if not guid or guid == "" then
    return nil
  end
  local safe_guid = guid:gsub("[^%w]", "_")
  return AUTO_SNAP_ARM_KEY_PREFIX .. safe_guid
end

local function normalize_auto_snap_arm_mode(mode)
  if mode == "chord_only" then return AUTO_SNAP_ARM_MODE_CHORDS end
  if mode == "scale_only" then return AUTO_SNAP_ARM_MODE_SCALES end
  if mode == "chord_scale" then return AUTO_SNAP_ARM_MODE_CHORDS_SCALES end

  if mode == AUTO_SNAP_ARM_MODE_CHORDS or mode == AUTO_SNAP_ARM_MODE_SCALES or mode == AUTO_SNAP_ARM_MODE_CHORDS_SCALES then
    return mode
  end

  return AUTO_SNAP_ARM_MODE_OFF
end

local function normalize_override_mode(mode)
  local value = tostring(mode or ""):lower()
  if value == "" then return nil end

  if value == "chord_only" then return AUTO_SNAP_ARM_MODE_CHORDS end
  if value == "scale_only" then return AUTO_SNAP_ARM_MODE_SCALES end
  if value == "chord_scale" then return AUTO_SNAP_ARM_MODE_CHORDS_SCALES end

  value = normalize_auto_snap_arm_mode(value)
  if value == AUTO_SNAP_ARM_MODE_OFF then
    return nil
  end
  return value
end

local function get_override_mode()
  local stored = reaper.GetExtState(MANAGER_SECTION, SNAP_MODE_OVERRIDE_KEY)
  return normalize_override_mode(stored)
end

local function get_auto_snap_arm_mode_for_track(track)
  local key = auto_snap_arm_key_for_track(track)
  if not key then return AUTO_SNAP_ARM_MODE_OFF end

  local _, stored = reaper.GetProjExtState(0, EXT_SECTION, key)
  return normalize_auto_snap_arm_mode(stored)
end

local function gather_chord_notes(chord_track)
  local notes = {}
  if not chord_track then return notes end

  local item_count = reaper.CountTrackMediaItems(chord_track)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(chord_track, item_index)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local _, note_count = reaper.MIDI_CountEvts(take)
      for note_index = 0, note_count - 1 do
        local ok, _, muted, start_ppq, end_ppq, _, pitch = reaper.MIDI_GetNote(take, note_index)
        if ok and not muted and end_ppq > start_ppq then
          local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
          local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)
          if end_time > start_time then
            notes[#notes + 1] = {
              start_time = start_time,
              end_time = end_time,
              pc = pitch % 12,
            }
          end
        end
      end
    end
  end

  table.sort(notes, function(a, b)
    return a.start_time < b.start_time
  end)

  return notes
end

local function chord_pcs_at_time(chord_notes, time_position)
  local pitch_set = {}
  local found = 0

  for i = 1, #chord_notes do
    local note = chord_notes[i]
    if note.start_time > time_position then
      break
    end
    if note.start_time <= time_position and note.end_time > time_position then
      if not pitch_set[note.pc] then
        pitch_set[note.pc] = true
        found = found + 1
      end
    end
  end

  return pitch_set, found
end

local function write_shared_sets(runtime_state, chord_set, scale_set)
  local chord_count = set_count(chord_set)
  local scale_count = set_count(scale_set)
  local signature = set_to_signature(chord_set) .. "|" .. set_to_signature(scale_set)

  if signature ~= runtime_state.last_shared_signature then
    runtime_state.shared_version = runtime_state.shared_version + 1

    reaper.gmem_write(GMEM_CHORD_COUNT, chord_count)
    reaper.gmem_write(GMEM_SCALE_COUNT, scale_count)

    for pc = 0, 11 do
      reaper.gmem_write(GMEM_CHORD_BASE + pc, chord_set[pc] and 1 or 0)
      reaper.gmem_write(GMEM_SCALE_BASE + pc, scale_set[pc] and 1 or 0)
    end

    reaper.gmem_write(GMEM_VERSION, runtime_state.shared_version)
    runtime_state.last_shared_signature = signature
  end

  reaper.gmem_write(GMEM_RUNNING, 1)
  reaper.gmem_write(GMEM_HEARTBEAT, reaper.time_precise())

  runtime_state.last_chord_count = chord_count
  runtime_state.last_scale_count = scale_count
end

local function clear_shared_sets(runtime_state)
  runtime_state.shared_version = runtime_state.shared_version + 1

  reaper.gmem_write(GMEM_CHORD_COUNT, 0)
  reaper.gmem_write(GMEM_SCALE_COUNT, 0)
  for pc = 0, 11 do
    reaper.gmem_write(GMEM_CHORD_BASE + pc, 0)
    reaper.gmem_write(GMEM_SCALE_BASE + pc, 0)
  end

  reaper.gmem_write(GMEM_RUNNING, 0)
  reaper.gmem_write(GMEM_HEARTBEAT, reaper.time_precise())
  reaper.gmem_write(GMEM_VERSION, runtime_state.shared_version)
end

local function get_play_or_cursor_position()
  local play_state = reaper.GetPlayState()
  local is_playing = (play_state & 1) == 1
  local is_recording = (play_state & 4) == 4

  if is_playing or is_recording then
    if reaper.GetPlayPosition2Ex then
      return reaper.GetPlayPosition2Ex(0)
    end
    return reaper.GetPlayPosition()
  end

  if reaper.GetCursorPositionEx then
    return reaper.GetCursorPositionEx(0)
  end
  return reaper.GetCursorPosition()
end

local function normalize_fx_name(name)
  local value = tostring(name or ""):lower()
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("^js:%s*", "")
  value = value:gsub("\\", "/")
  return value
end

local function trim_jsfx_extension(name)
  local value = tostring(name or "")
  return value:gsub("%.jsfx$", "")
end

local function add_unique_string(list, seen, value)
  local text = tostring(value or "")
  if text == "" then return end
  if seen[text] then return end
  seen[text] = true
  list[#list + 1] = text
end

local function discover_jsfx_add_names_from_effects_tree()
  if cached_discovered_jsfx_add_names then
    return cached_discovered_jsfx_add_names
  end

  local discovered = {}
  local seen = {}

  for i = 1, #JSFX_ADD_NAME_CANDIDATES do
    add_unique_string(discovered, seen, JSFX_ADD_NAME_CANDIDATES[i])
  end

  if not reaper.GetResourcePath or not reaper.EnumerateFiles or not reaper.EnumerateSubdirectories then
    cached_discovered_jsfx_add_names = discovered
    return discovered
  end

  local effects_root = tostring(reaper.GetResourcePath() or "") .. "/Effects"

  local function scan_dir(abs_dir, relative_dir)
    local file_index = 0
    while true do
      local file_name = reaper.EnumerateFiles(abs_dir, file_index)
      if not file_name then break end

      local normalized_file = tostring(file_name):lower()
      if normalized_file:find("oz chord track input snap", 1, true) then
        local rel = relative_dir and (relative_dir .. "/" .. tostring(file_name)) or tostring(file_name)
        rel = rel:gsub("\\", "/")
        rel = trim_jsfx_extension(rel)
        add_unique_string(discovered, seen, "JS:" .. rel)
      end

      file_index = file_index + 1
    end

    local sub_index = 0
    while true do
      local sub_name = reaper.EnumerateSubdirectories(abs_dir, sub_index)
      if not sub_name then break end

      local child_abs = abs_dir .. "/" .. tostring(sub_name)
      local child_rel = relative_dir and (relative_dir .. "/" .. tostring(sub_name)) or tostring(sub_name)
      scan_dir(child_abs, child_rel)

      sub_index = sub_index + 1
    end
  end

  scan_dir(effects_root, nil)

  cached_discovered_jsfx_add_names = discovered
  return discovered
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

local function collapse_duplicate_input_fx(track)
  local indices = list_input_snap_fx_indices(track)
  if #indices == 0 then
    return -1, 0
  end

  local keep_index = indices[1]
  local removed = 0
  for i = #indices, 2, -1 do
    reaper.TrackFX_Delete(track, indices[i])
    removed = removed + 1
  end

  return keep_index, removed
end

local function find_input_fx(track)
  local indices = list_input_snap_fx_indices(track)
  return indices[1] or -1
end

local function ensure_input_fx(track)
  local fx_index = find_input_fx(track)
  if fx_index >= 0 then
    return fx_index
  end

  local add_names = discover_jsfx_add_names_from_effects_tree()
  for i = 1, #add_names do
    fx_index = reaper.TrackFX_AddByName(track, add_names[i], true, 1)
    if fx_index >= 0 then
      return fx_index
    end
  end

  return find_input_fx(track)
end

local function candidate_input_fx_indices(track, fx_index)
  local candidates = {}
  local seen = {}

  local function push(idx)
    if type(idx) ~= "number" or idx < 0 or seen[idx] then
      return
    end
    local ok, fx_name = reaper.TrackFX_GetFXName(track, idx, "")
    if ok and is_input_snap_fx_name(fx_name) then
      seen[idx] = true
      candidates[#candidates + 1] = idx
    end
  end

  push(fx_index)
  if fx_index >= REC_FX_OFFSET then
    push(fx_index - REC_FX_OFFSET)
  else
    push(REC_FX_OFFSET + fx_index)
  end

  local listed = list_input_snap_fx_indices(track)
  for i = 1, #listed do
    push(listed[i])
  end

  return candidates
end

local function set_fx_param_value(track, fx_index, param_index, target_value)
  local current, min_value, max_value = reaper.TrackFX_GetParam(track, fx_index, param_index)
  current = as_number(current)
  min_value = as_number(min_value)
  max_value = as_number(max_value)

  if current == nil then
    return false, nil
  end

  if reaper.TrackFX_SetParamNormalized and min_value and max_value and max_value > min_value then
    local normalized = (target_value - min_value) / (max_value - min_value)
    if normalized < 0 then normalized = 0 end
    if normalized > 1 then normalized = 1 end
    reaper.TrackFX_SetParamNormalized(track, fx_index, param_index, normalized)
  end

  reaper.TrackFX_SetParam(track, fx_index, param_index, target_value)

  local readback = as_number(reaper.TrackFX_GetParam(track, fx_index, param_index))
  if readback == nil then
    return false, nil
  end

  return math.abs(readback - target_value) <= 0.51, readback
end

local function configure_input_fx(track, fx_index, mode_param, enabled)
  if fx_index < 0 then return false, nil end

  local candidates = candidate_input_fx_indices(track, fx_index)
  for i = 1, #candidates do
    local candidate = candidates[i]
    local mode_ok = true
    local mode_readback = nil

    if mode_param then
      mode_ok, mode_readback = set_fx_param_value(track, candidate, 0, mode_param)
    end

    local enabled_ok = set_fx_param_value(track, candidate, 1, enabled and 1 or 0)

    if reaper.TrackFX_SetEnabled then
      reaper.TrackFX_SetEnabled(track, candidate, true)
    end

    if mode_ok and enabled_ok then
      return true, mode_readback
    end
  end

  return false, nil
end

local function manage_track_input_fx(chord_track)
  local active_targets = 0
  local fx_enabled_targets = 0
  local fx_missing = 0
  local duplicate_fx_removed = 0
  local fx_mode_mismatch = 0
  local fx_config_errors = 0
  local mode_override = get_override_mode()

  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track ~= chord_track then
      local fx_index, removed_count = collapse_duplicate_input_fx(track)
      duplicate_fx_removed = duplicate_fx_removed + removed_count

      local rec_arm = reaper.GetMediaTrackInfo_Value(track, "I_RECARM")
      local mode = mode_override or get_auto_snap_arm_mode_for_track(track)
      local mode_param = MODE_TO_JSFX_PARAM[mode]

      local should_enable = (rec_arm >= 1) and (mode_param ~= nil)
      if should_enable then
        active_targets = active_targets + 1
        if fx_index < 0 then
          fx_index = ensure_input_fx(track)
        end
        if fx_index >= 0 then
          local configured, mode_readback = configure_input_fx(track, fx_index, mode_param, true)
          if configured then
            fx_enabled_targets = fx_enabled_targets + 1
            if mode_readback and mode_param and math.abs(mode_readback - mode_param) > 0.51 then
              fx_mode_mismatch = fx_mode_mismatch + 1
            end
          else
            fx_config_errors = fx_config_errors + 1
          end
        else
          fx_missing = fx_missing + 1
        end
      else
        if fx_index >= 0 then
          configure_input_fx(track, fx_index, mode_param or 2, false)
        end
      end
    end
  end

  return active_targets, fx_enabled_targets, fx_missing, mode_override, duplicate_fx_removed, fx_mode_mismatch, fx_config_errors
end

local function main()
  if not reaper.gmem_attach or not reaper.gmem_write or not reaper.gmem_read then
    reaper.MB("This REAPER build does not support gmem_* APIs required for input snap manager.", "Oz Chord Track", 0)
    return
  end

  reaper.gmem_attach(GMEM_NAMESPACE)

  local runtime_state = {
    token = tostring(reaper.time_precise()),
    last_shared_signature = "",
    last_project_state = -1,
    last_chord_guid = "",
    chord_notes = {},
    last_refresh = 0,
    shared_version = math.floor(as_number(reaper.gmem_read(GMEM_VERSION)) or 0),
    last_chord_count = 0,
    last_scale_count = 0,
  }

  reaper.SetExtState(MANAGER_SECTION, RUN_TOKEN_KEY, runtime_state.token, false)
  reaper.SetExtState(MANAGER_SECTION, STATUS_KEY, "starting", false)

  local function loop()
    if reaper.GetExtState(MANAGER_SECTION, RUN_TOKEN_KEY) ~= runtime_state.token then
      clear_shared_sets(runtime_state)
      return
    end

    local _, chord_guid = reaper.GetProjExtState(0, EXT_SECTION, "TRACK_GUID")
    local chord_track = find_track_by_guid(chord_guid)

    local _, scale_csv = reaper.GetProjExtState(0, EXT_SECTION, "SCALE_PCS")
    local scale_set = csv_to_set(scale_csv)

    local project_state = reaper.GetProjectStateChangeCount(0)
    local now = reaper.time_precise()

    local should_refresh_chord_notes = false
    if project_state ~= runtime_state.last_project_state then
      should_refresh_chord_notes = true
    end
    if chord_guid ~= runtime_state.last_chord_guid then
      should_refresh_chord_notes = true
    end
    if now - runtime_state.last_refresh > 0.35 then
      should_refresh_chord_notes = true
    end

    if should_refresh_chord_notes then
      runtime_state.chord_notes = gather_chord_notes(chord_track)
      runtime_state.last_project_state = project_state
      runtime_state.last_chord_guid = chord_guid or ""
      runtime_state.last_refresh = now
    end

    local chord_set = {}
    if chord_track and #runtime_state.chord_notes > 0 then
      local current_position = get_play_or_cursor_position()
      chord_set = chord_pcs_at_time(runtime_state.chord_notes, current_position)
    end

    write_shared_sets(runtime_state, chord_set, scale_set)

    local active_targets, fx_enabled_targets, fx_missing, mode_override, duplicate_fx_removed, fx_mode_mismatch, fx_config_errors = manage_track_input_fx(chord_track)

    local chord_name = "(none)"
    if chord_track then
      local _, track_name = reaper.GetTrackName(chord_track)
      chord_name = (track_name and track_name ~= "") and track_name or "(unnamed track)"
    end

    local status_text =
      "running | chord=" .. tostring(chord_name) ..
      " | chord_pcs=" .. tostring(runtime_state.last_chord_count) ..
      " | scale_pcs=" .. tostring(runtime_state.last_scale_count) ..
      " | armed_targets=" .. tostring(active_targets) ..
      " | fx_enabled=" .. tostring(fx_enabled_targets)

    if mode_override then
      status_text = status_text .. " | override=" .. tostring(mode_override)
    end

    if fx_missing > 0 then
      status_text = status_text .. " | fx_missing=" .. tostring(fx_missing)
    end
    if duplicate_fx_removed > 0 then
      status_text = status_text .. " | fx_deduped=" .. tostring(duplicate_fx_removed)
    end
    if fx_mode_mismatch > 0 then
      status_text = status_text .. " | mode_mismatch=" .. tostring(fx_mode_mismatch)
    end
    if fx_config_errors > 0 then
      status_text = status_text .. " | fx_cfg_err=" .. tostring(fx_config_errors)
    end

    reaper.SetExtState(MANAGER_SECTION, STATUS_KEY, status_text, false)
    reaper.defer(loop)
  end

  reaper.atexit(function()
    local current = reaper.GetExtState(MANAGER_SECTION, RUN_TOKEN_KEY)
    if current == runtime_state.token then
      reaper.SetExtState(MANAGER_SECTION, RUN_TOKEN_KEY, "", false)
      reaper.SetExtState(MANAGER_SECTION, STATUS_KEY, "stopped", false)
    end
    clear_shared_sets(runtime_state)
  end)

  loop()
end

main()

local EXT_SECTION = "OZ_REAPER_CHORD_TRACK"
local MANAGER_SECTION = "OZ_REAPER_CHORD_TRACK_INPUT_MANAGER"
local RUN_TOKEN_KEY = "RUN_TOKEN"
local STATUS_KEY = "STATUS"
local SNAP_MODE_OVERRIDE_KEY = "SNAP_MODE_OVERRIDE"
local ALLOW_SNAP_INVERSIONS_KEY = "ALLOW_SNAP_INVERSIONS"
local RECORD_TIMING_OFFSET_MS_KEY = "RECORD_TIMING_OFFSET_MS"
local RECORD_TIMING_OFFSET_MS_DEFAULT = 0
local RECORD_TIMING_OFFSET_MS_MIN = -150
local RECORD_TIMING_OFFSET_MS_MAX = 150

local FX_NAME = "JS:Oz Chord Track/Oz Chord Track Input Snap"
local FX_NAME_FALLBACK = "JS: Oz Chord Track Input Snap"
local GMEM_NAMESPACE = "OZ_REAPER_CHORD_TRACK_INPUT_SNAP"
local REC_FX_OFFSET = 0x1000000

local GMEM_VERSION = 0
local GMEM_CHORD_COUNT = 1
local GMEM_SCALE_COUNT = 2
local GMEM_HEARTBEAT = 3
local GMEM_RUNNING = 4
local GMEM_ALLOW_INVERSIONS = 5
local GMEM_CHORD_ROOT = 6
local GMEM_CHORD_BASE = 8
local GMEM_SCALE_BASE = 24

local AUTO_SNAP_ARM_KEY_PREFIX = "AUTO_SNAP_ARM_MODE_"
local AUTO_SNAP_ARM_MODE_OFF = "off"
local AUTO_SNAP_ARM_MODE_CHORDS = "chords"
local AUTO_SNAP_ARM_MODE_SCALES = "scales"
local AUTO_SNAP_ARM_MODE_CHORDS_SCALES = "chords_scales"
local AUTO_SNAP_ARM_MODE_MELODIC_FLOW = "melodic_flow"

local MODE_TO_JSFX_PARAM = {
  [AUTO_SNAP_ARM_MODE_CHORDS] = 0,
  [AUTO_SNAP_ARM_MODE_SCALES] = 1,
  [AUTO_SNAP_ARM_MODE_CHORDS_SCALES] = 2,
  [AUTO_SNAP_ARM_MODE_MELODIC_FLOW] = 3,
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

local function clamp_record_timing_offset_ms(value)
  local numeric = tonumber(value) or RECORD_TIMING_OFFSET_MS_DEFAULT
  if numeric < RECORD_TIMING_OFFSET_MS_MIN then
    numeric = RECORD_TIMING_OFFSET_MS_MIN
  elseif numeric > RECORD_TIMING_OFFSET_MS_MAX then
    numeric = RECORD_TIMING_OFFSET_MS_MAX
  end

  if math.abs(numeric) < 0.0001 then
    numeric = 0
  end

  return numeric
end

local function get_record_timing_offset_ms()
  local _, stored = reaper.GetProjExtState(0, EXT_SECTION, RECORD_TIMING_OFFSET_MS_KEY)
  if not stored or stored == "" then
    return RECORD_TIMING_OFFSET_MS_DEFAULT
  end

  return clamp_record_timing_offset_ms(stored)
end

local function for_each_midi_take_on_track(track, callback)
  if not track or not callback then return end

  local item_count = reaper.CountTrackMediaItems(track)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      callback(take)
    end
  end
end

local function take_id(take)
  local _, guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
  if guid and guid ~= "" then return guid end
  return tostring(take)
end

local function shift_take_note_timing(take, start_note_index, offset_ms)
  local _, note_count = reaper.MIDI_CountEvts(take)
  if note_count == 0 then return 0, 0, note_count end

  local offset = tonumber(offset_ms) or 0
  if math.abs(offset) < 0.0001 then
    return 0, 0, note_count
  end

  local from_index = start_note_index or 0
  if from_index < 0 then from_index = 0 end
  if from_index >= note_count then return 0, 0, note_count end

  local offset_seconds = offset / 1000.0
  local changed = 0
  local processed = 0

  for note_index = from_index, note_count - 1 do
    local ok, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, note_index)
    if ok and not muted then
      local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
      local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)

      local new_start_time = start_time + offset_seconds
      local new_end_time = end_time + offset_seconds

      if new_start_time < 0 then
        local compensation = -new_start_time
        new_start_time = 0
        new_end_time = new_end_time + compensation
      end

      if new_end_time <= new_start_time then
        new_end_time = new_start_time + 0.001
      end

      local new_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, new_start_time)
      local new_end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, new_end_time)
      if new_end_ppq <= new_start_ppq then
        new_end_ppq = new_start_ppq + 1
      end

      if math.abs(new_start_ppq - start_ppq) > 0.0001 or math.abs(new_end_ppq - end_ppq) > 0.0001 then
        reaper.MIDI_SetNote(take, note_index, selected, muted, new_start_ppq, new_end_ppq, channel, pitch, velocity, true)
        changed = changed + 1
      end

      processed = processed + 1
    end
  end

  if changed > 0 then
    reaper.MIDI_Sort(take)
  end

  return changed, processed, note_count
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
  if mode == "melodic_flow" then return AUTO_SNAP_ARM_MODE_MELODIC_FLOW end

  if mode == AUTO_SNAP_ARM_MODE_CHORDS or mode == AUTO_SNAP_ARM_MODE_SCALES or mode == AUTO_SNAP_ARM_MODE_CHORDS_SCALES or mode == AUTO_SNAP_ARM_MODE_MELODIC_FLOW then
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
  if value == "melodic_flow" then return AUTO_SNAP_ARM_MODE_MELODIC_FLOW end

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
              pitch = pitch,
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
  local lowest_pitch = nil
  local root_pc = nil

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

      local note_pitch = tonumber(note.pitch)
      if note_pitch and (lowest_pitch == nil or note_pitch < lowest_pitch) then
        lowest_pitch = note_pitch
        root_pc = note.pc
      end
    end
  end

  return pitch_set, found, root_pc
end

local function write_shared_sets(runtime_state, chord_set, scale_set, chord_root_pc)
  local chord_count = set_count(chord_set)
  local scale_count = set_count(scale_set)
  local chord_root = tonumber(chord_root_pc)
  if chord_root == nil then
    chord_root = -1
  else
    chord_root = chord_root % 12
  end
  local signature = set_to_signature(chord_set) .. "|" .. set_to_signature(scale_set) .. "|" .. tostring(chord_root)

  if signature ~= runtime_state.last_shared_signature then
    runtime_state.shared_version = runtime_state.shared_version + 1

    reaper.gmem_write(GMEM_CHORD_COUNT, chord_count)
    reaper.gmem_write(GMEM_SCALE_COUNT, scale_count)
    reaper.gmem_write(GMEM_CHORD_ROOT, chord_root)

    for pc = 0, 11 do
      reaper.gmem_write(GMEM_CHORD_BASE + pc, chord_set[pc] and 1 or 0)
      reaper.gmem_write(GMEM_SCALE_BASE + pc, scale_set[pc] and 1 or 0)
    end

    reaper.gmem_write(GMEM_VERSION, runtime_state.shared_version)
    runtime_state.last_shared_signature = signature
  end

  local _, allow_inversions_value = reaper.GetProjExtState(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY)
  local allow_inversions = tostring(allow_inversions_value or ""):lower()
  local allow_flag = (allow_inversions == "1" or allow_inversions == "true" or allow_inversions == "yes" or allow_inversions == "on") and 1 or 0
  reaper.gmem_write(GMEM_ALLOW_INVERSIONS, allow_flag)

  reaper.gmem_write(GMEM_RUNNING, 1)
  reaper.gmem_write(GMEM_HEARTBEAT, reaper.time_precise())

  runtime_state.last_chord_count = chord_count
  runtime_state.last_scale_count = scale_count
  runtime_state.last_chord_root = chord_root
end

local function clear_shared_sets(runtime_state)
  runtime_state.shared_version = runtime_state.shared_version + 1

  reaper.gmem_write(GMEM_CHORD_COUNT, 0)
  reaper.gmem_write(GMEM_SCALE_COUNT, 0)
  reaper.gmem_write(GMEM_ALLOW_INVERSIONS, 0)
  reaper.gmem_write(GMEM_CHORD_ROOT, -1)
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

  if #discovered > #JSFX_ADD_NAME_CANDIDATES then
    cached_discovered_jsfx_add_names = discovered
  end

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

local function gather_record_timing_target_tracks(chord_track, mode_override)
  local targets = {}
  local target_guids = {}

  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track ~= chord_track then
      local rec_arm = reaper.GetMediaTrackInfo_Value(track, "I_RECARM")
      local mode = mode_override or get_auto_snap_arm_mode_for_track(track)
      local mode_param = MODE_TO_JSFX_PARAM[mode]

      if rec_arm >= 1 and mode_param ~= nil then
        targets[#targets + 1] = track
        local guid = get_track_guid(track)
        if guid and guid ~= "" then
          target_guids[guid] = true
        end
      end
    end
  end

  return targets, target_guids
end

local function apply_record_timing_offset_to_tracks(runtime_state, chord_track, offset_ms, active_targets, include_target_guids, is_recording, should_flush_after_record)
  local changed_total = 0
  local processed_total = 0
  local touched_take_count = 0
  local seen_take_ids = {}

  local function process_take(take)
    local id = take_id(take)
    seen_take_ids[id] = true

    local _, note_count = reaper.MIDI_CountEvts(take)
    local last_count = tonumber(runtime_state.take_timing_counts[id])
    if last_count == nil then
      last_count = note_count
    end

    local changed, processed, current_count = shift_take_note_timing(take, last_count, offset_ms)
    runtime_state.take_timing_counts[id] = current_count

    changed_total = changed_total + (tonumber(changed) or 0)
    processed_total = processed_total + (tonumber(processed) or 0)
    touched_take_count = touched_take_count + 1

    if (tonumber(changed) or 0) > 0 then
      reaper.UpdateItemInProject(reaper.GetMediaItemTake_Item(take))
    end
  end

  if include_target_guids and next(include_target_guids) then
    for guid in pairs(include_target_guids) do
      local track = find_track_by_guid(guid)
      if track and track ~= chord_track then
        for_each_midi_take_on_track(track, process_take)
      end
    end
  else
    for i = 1, #active_targets do
      for_each_midi_take_on_track(active_targets[i], process_take)
    end
  end

  for id in pairs(runtime_state.take_timing_counts) do
    if not seen_take_ids[id] then
      runtime_state.take_timing_counts[id] = nil
    end
  end

  return changed_total, processed_total, touched_take_count
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
    last_chord_root = -1,
    take_timing_counts = {},
    was_recording = false,
    pending_record_flush = false,
    record_stop_time = 0,
    record_target_guids = {},
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
    local chord_root_pc = nil
    if chord_track and #runtime_state.chord_notes > 0 then
      local current_position = get_play_or_cursor_position()
      chord_set, _, chord_root_pc = chord_pcs_at_time(runtime_state.chord_notes, current_position)
    end

    write_shared_sets(runtime_state, chord_set, scale_set, chord_root_pc)

    local active_targets, fx_enabled_targets, fx_missing, mode_override, duplicate_fx_removed, fx_mode_mismatch, fx_config_errors = manage_track_input_fx(chord_track)

    local play_state = reaper.GetPlayState()
    local is_recording = (play_state & 4) == 4
    local should_flush_after_record = false

    if is_recording then
      runtime_state.was_recording = true
      runtime_state.pending_record_flush = false
    elseif runtime_state.was_recording and (not runtime_state.pending_record_flush) then
      runtime_state.pending_record_flush = true
      runtime_state.record_stop_time = reaper.time_precise()
    end

    if runtime_state.pending_record_flush then
      should_flush_after_record = true
    end

    local record_timing_offset_ms = get_record_timing_offset_ms()
    local apply_record_timing_offset = math.abs(record_timing_offset_ms) >= 0.0001
    local timing_changed = 0
    local timing_processed = 0
    local timing_take_count = 0

    if apply_record_timing_offset then
      local active_timing_tracks, active_timing_guids = gather_record_timing_target_tracks(chord_track, mode_override)

      if is_recording then
        for guid in pairs(active_timing_guids) do
          runtime_state.record_target_guids[guid] = true
        end
      end

      local include_guid_set = should_flush_after_record and runtime_state.record_target_guids or nil
      timing_changed, timing_processed, timing_take_count = apply_record_timing_offset_to_tracks(
        runtime_state,
        chord_track,
        record_timing_offset_ms,
        active_timing_tracks,
        include_guid_set,
        is_recording,
        should_flush_after_record
      )
    else
      runtime_state.take_timing_counts = {}
      runtime_state.record_target_guids = {}
      runtime_state.pending_record_flush = false
      runtime_state.was_recording = is_recording
      runtime_state.record_stop_time = 0
    end

    if should_flush_after_record then
      local flush_age = reaper.time_precise() - (tonumber(runtime_state.record_stop_time) or 0)
      local keep_waiting = apply_record_timing_offset and timing_take_count == 0 and flush_age < 6.0

      if not keep_waiting then
        runtime_state.pending_record_flush = false
        runtime_state.record_stop_time = 0
        runtime_state.was_recording = false
        runtime_state.record_target_guids = {}
      end
    end

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
    if apply_record_timing_offset and timing_changed > 0 then
      status_text = status_text .. " | timing_shifted=" .. tostring(timing_changed)
    end
    if runtime_state.pending_record_flush then
      status_text = status_text .. " | timing_flush=1"
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

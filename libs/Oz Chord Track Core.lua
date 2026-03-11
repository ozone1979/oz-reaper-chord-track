local OzChordTrack = {}

local EXT_SECTION = "OZ_REAPER_CHORD_TRACK"
local LIVE_SECTION = "OZ_REAPER_CHORD_TRACK_LIVE"
local LIVE_MODE_KEY = "RUN_MODE"
local INPUT_MANAGER_SECTION = "OZ_REAPER_CHORD_TRACK_INPUT_MANAGER"
local INPUT_MANAGER_RUN_TOKEN_KEY = "RUN_TOKEN"
local INPUT_MANAGER_STATUS_KEY = "STATUS"
local INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY = "SNAP_MODE_OVERRIDE"
local PANEL_SECTION = "OZ_REAPER_CHORD_TRACK_PANEL"
local CUT_OVERLAPS_AFTER_SNAP_KEY = "CUT_OVERLAPS_AFTER_SNAP"
local ALLOW_SNAP_INVERSIONS_KEY = "ALLOW_SNAP_INVERSIONS"
local POPOUT_INITIAL_TAB_KEY = "POPOUT_INITIAL_TAB"
local POPOUT_WINDOW_X_KEY = "POPOUT_WINDOW_X"
local POPOUT_WINDOW_Y_KEY = "POPOUT_WINDOW_Y"
local POPOUT_WINDOW_W_KEY = "POPOUT_WINDOW_W"
local POPOUT_WINDOW_H_KEY = "POPOUT_WINDOW_H"
local NEW_NOTE_SNAP_PIPELINE_KEY = "NEW_NOTE_SNAP_PIPELINE"
local NEW_NOTE_SNAP_MODE_KEY = "NEW_NOTE_SNAP_MODE"
local TIMELINE_CALIBRATION_PX_KEY = "TIMELINE_CALIBRATION_PX"
local TIMELINE_CALIBRATION_DEFAULT = 0
local TIMELINE_CALIBRATION_MIN = -32
local TIMELINE_CALIBRATION_MAX = 32
local TIMELINE_CALIBRATION_COARSE_STEP = 1.0
local TIMELINE_CALIBRATION_FINE_STEP = 0.5

local CORE_DIR = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
local SnapSettings = dofile(CORE_DIR .. "Oz Chord Track Snap Settings.lua")

local AUTO_SNAP_ARM_MODE_OFF = "off"
local AUTO_SNAP_ARM_MODE_CHORDS = "chords"
local AUTO_SNAP_ARM_MODE_SCALES = "scales"
local AUTO_SNAP_ARM_MODE_CHORDS_SCALES = "chords_scales"
local AUTO_SNAP_ARM_MODE_DEFAULT = AUTO_SNAP_ARM_MODE_OFF
local AUTO_SNAP_ARM_KEY_PREFIX = "AUTO_SNAP_ARM_MODE_"

local AUTO_SNAP_ARM_MODE_ORDER = {
  AUTO_SNAP_ARM_MODE_OFF,
  AUTO_SNAP_ARM_MODE_CHORDS,
  AUTO_SNAP_ARM_MODE_SCALES,
  AUTO_SNAP_ARM_MODE_CHORDS_SCALES,
}

local AUTO_SNAP_ARM_MODE_LABELS = {
  [AUTO_SNAP_ARM_MODE_OFF] = "Off",
  [AUTO_SNAP_ARM_MODE_CHORDS] = "Chords",
  [AUTO_SNAP_ARM_MODE_SCALES] = "Scales",
  [AUTO_SNAP_ARM_MODE_CHORDS_SCALES] = "Chords + Scales",
}

local AUTO_SNAP_ARM_MODE_TO_SNAP_MODE = {
  [AUTO_SNAP_ARM_MODE_CHORDS] = "chord_only",
  [AUTO_SNAP_ARM_MODE_SCALES] = "scale_only",
  [AUTO_SNAP_ARM_MODE_CHORDS_SCALES] = "chord_scale",
}

local SNAP_MODE_CHORD_ONLY = "chord_only"
local SNAP_MODE_SCALE_ONLY = "scale_only"
local SNAP_MODE_CHORD_SCALE = "chord_scale"
local SNAP_MODE_MELODIC_FLOW = "melodic_flow"
local SNAP_MODE_DEFAULT = SNAP_MODE_CHORD_SCALE

local NEW_NOTE_SNAP_PIPELINE_PRE = "pre"
local NEW_NOTE_SNAP_PIPELINE_POST = "post"
local NEW_NOTE_SNAP_PIPELINE_DEFAULT = NEW_NOTE_SNAP_PIPELINE_PRE

local SNAP_MODE_LABELS = {
  [SNAP_MODE_CHORD_ONLY] = "Chords",
  [SNAP_MODE_SCALE_ONLY] = "Scales",
  [SNAP_MODE_CHORD_SCALE] = "Chords + Scales",
  [SNAP_MODE_MELODIC_FLOW] = "Melodic Flow",
}

local CHORD_BLOCK_THEME_AUTO = "auto"
local CHORD_BLOCK_THEME_BLUE = "blue"
local CHORD_BLOCK_THEME_PURPLE = "purple"
local CHORD_BLOCK_THEME_NEUTRAL = "neutral"
local CHORD_BLOCK_THEME_DEFAULT = CHORD_BLOCK_THEME_BLUE

local CHORD_BLOCK_THEME_ORDER = {
  CHORD_BLOCK_THEME_AUTO,
  CHORD_BLOCK_THEME_BLUE,
  CHORD_BLOCK_THEME_PURPLE,
  CHORD_BLOCK_THEME_NEUTRAL,
}

local CHORD_BLOCK_THEME_LABELS = {
  [CHORD_BLOCK_THEME_AUTO] = "Auto",
  [CHORD_BLOCK_THEME_BLUE] = "Blue",
  [CHORD_BLOCK_THEME_PURPLE] = "Purple",
  [CHORD_BLOCK_THEME_NEUTRAL] = "Neutral",
}

local INPUT_MANAGER_START_SCRIPT = "libs/Oz Chord Track - Start input snap manager (experimental).lua"
local INPUT_MANAGER_STOP_SCRIPT = "libs/Oz Chord Track - Stop input snap manager (experimental).lua"
local INPUT_SNAP_JSFX_RELATIVE_PATH = "Oz Chord Track/Oz Chord Track Input Snap.jsfx"

local INPUT_SNAP_JSFX_SOURCE = [[desc:Oz Chord Track Input Snap
options:gmem=OZ_REAPER_CHORD_TRACK_INPUT_SNAP

slider1:2<0,2,1{Chords,Scales,Chords+Scales}>Snap Mode
slider2:1<0,1,1{Off,On}>Enabled

@init

GMEM_CHORD_COUNT = 1;
GMEM_SCALE_COUNT = 2;
GMEM_RUNNING = 4;
GMEM_ALLOW_INVERSIONS = 5;
GMEM_CHORD_BASE = 8;
GMEM_SCALE_BASE = 24;

i = 0;
loop(2048,
  map_note[i] = -1;
  i += 1;
);

function normalize_pc(value) local(result) (
  result = value % 12;
  result < 0 ? result += 12;
  result;
);

function is_pc_enabled_for_mode(pc, mode) local(chord_on, scale_on) (
  chord_on = gmem[GMEM_CHORD_BASE + pc] >= 0.5;
  scale_on = gmem[GMEM_SCALE_BASE + pc] >= 0.5;

  mode == 0 ? chord_on
  : mode == 1 ? scale_on
  : (chord_on || scale_on);
);

function mode_has_any_notes(mode) (
  mode == 0 ? (gmem[GMEM_CHORD_COUNT] > 0.5)
  : mode == 1 ? (gmem[GMEM_SCALE_COUNT] > 0.5)
  : ((gmem[GMEM_CHORD_COUNT] > 0.5) || (gmem[GMEM_SCALE_COUNT] > 0.5));
);

function nearest_allowed_note_unbounded(note, mode) local(best_note, best_distance, candidate, distance, pc) (
  best_note = -1;
  best_distance = 999;

  candidate = 0;
  loop(128,
    pc = normalize_pc(candidate);
    is_pc_enabled_for_mode(pc, mode) ? (
      distance = abs(candidate - note);
      (distance < best_distance || (distance == best_distance && (best_note < 0 || candidate < best_note))) ? (
        best_distance = distance;
        best_note = candidate;
      );
    );
    candidate += 1;
  );

  best_note >= 0 ? best_note : note;
);

function nearest_allowed_note(note, mode, min_note, max_note) local(best_note, best_distance, candidate, distance, pc) (
  min_note < 0 ? min_note = 0;
  max_note > 127 ? max_note = 127;
  min_note > max_note ? (
    nearest_allowed_note_unbounded(note, mode);
  ) : (
    best_note = -1;
    best_distance = 999;

    candidate = min_note | 0;
    loop((max_note - min_note + 1) | 0,
      pc = normalize_pc(candidate);
      is_pc_enabled_for_mode(pc, mode) ? (
        distance = abs(candidate - note);
        (distance < best_distance || (distance == best_distance && (best_note < 0 || candidate < best_note))) ? (
          best_distance = distance;
          best_note = candidate;
        );
      );
      candidate += 1;
    );

    best_note >= 0 ? best_note : nearest_allowed_note_unbounded(note, mode);
  );
);

function neighboring_snapped_bounds(chan, note) local(scan_note, mapped, key) (
  min_bound = -1;
  max_bound = 128;

  scan_note = 0;
  loop(128,
    key = chan * 128 + scan_note;
    mapped = map_note[key];

    mapped >= 0 ? (
      scan_note < note ? (
        mapped > min_bound ? min_bound = mapped;
      ) : scan_note > note ? (
        mapped < max_bound ? max_bound = mapped;
      );
    );

    scan_note += 1;
  );

);

@slider
mode = slider1 | 0;
mode < 0 ? mode = 0;
mode > 2 ? mode = 2;
enabled = slider2 >= 0.5;

@block
running = gmem[GMEM_RUNNING] >= 0.5;
mode = slider1 | 0;
enabled = slider2 >= 0.5;

while (
  midirecv(offset, msg1, msg23)
) (
  status = msg1 & 240;
  chan = msg1 & 15;
  note = msg23 & 127;
  velocity = (msg23 / 256) | 0;
  key = chan * 128 + note;

  (enabled && running && mode_has_any_notes(mode) && status == 144 && velocity > 0) ? (
    allow_inversions = gmem[GMEM_ALLOW_INVERSIONS] >= 0.5;
    allow_inversions ? (
      snapped_note = nearest_allowed_note_unbounded(note, mode);
    ) : (
      neighboring_snapped_bounds(chan, note);
      snapped_note = nearest_allowed_note(note, mode, min_bound + 1, max_bound - 1);
    );
    map_note[key] = snapped_note;
    midisend(offset, msg1, (msg23 & 65280) | snapped_note);
  ) : ((status == 128 || (status == 144 && velocity == 0)) ? (
    mapped = map_note[key];
    mapped >= 0 ? (
      send_note = mapped;
      map_note[key] = -1;
    ) : (
      send_note = note;
    );
    midisend(offset, msg1, (msg23 & 65280) | send_note);
  ) : (
    midisend(offset, msg1, msg23);
  ));
);
]]

local function message(text)
  reaper.MB(text, "Oz Reaper Chord Track", 0)
end

local function normalize_text(value)
  if not value then return "" end
  local normalized = value:lower():gsub("[^%w]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return normalized
end

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

local function set_to_csv(pitch_set)
  local values = {}
  for pc = 0, 11 do
    if pitch_set[pc] then
      values[#values + 1] = tostring(pc)
    end
  end
  return table.concat(values, ",")
end

local function pitch_set_to_note_names(pitch_set)
  local note_names = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
  local names = {}
  for pc = 0, 11 do
    if pitch_set and pitch_set[pc] then
      names[#names + 1] = note_names[(pc % 12) + 1]
    end
  end
  return table.concat(names, " ")
end

local function copy_set(source)
  local target = {}
  for key, enabled in pairs(source or {}) do
    if enabled then
      target[key] = true
    end
  end
  return target
end

local function intersect_sets(a, b)
  local result = {}
  for pc = 0, 11 do
    if a[pc] and b[pc] then
      result[pc] = true
    end
  end
  return result
end

local function set_count(pitch_set)
  local total = 0
  for _, enabled in pairs(pitch_set or {}) do
    if enabled then total = total + 1 end
  end
  return total
end

local ROOT_MAP = {
  C = 0,
  ["C#"] = 1,
  DB = 1,
  D = 2,
  ["D#"] = 3,
  EB = 3,
  E = 4,
  FB = 4,
  ["E#"] = 5,
  F = 5,
  ["F#"] = 6,
  GB = 6,
  G = 7,
  ["G#"] = 8,
  AB = 8,
  A = 9,
  ["A#"] = 10,
  BB = 10,
  B = 11,
  CB = 11,
}

local NOTE_NAMES_SHARP = {
  "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
}

local function pc_to_note_name(pc)
  if pc == nil then return "?" end
  return NOTE_NAMES_SHARP[(pc % 12) + 1]
end

local SCALE_LIBRARY = {
  { id = "major pentatonic", aliases = { "major pentatonic", "pentatonic major", "maj pent" }, intervals = { 0, 2, 4, 7, 9 } },
  { id = "minor pentatonic", aliases = { "minor pentatonic", "pentatonic minor", "min pent" }, intervals = { 0, 3, 5, 7, 10 } },
  { id = "harmonic minor", aliases = { "harmonic minor" }, intervals = { 0, 2, 3, 5, 7, 8, 11 } },
  { id = "melodic minor", aliases = { "melodic minor", "jazz minor" }, intervals = { 0, 2, 3, 5, 7, 9, 11 } },
  { id = "natural minor", aliases = { "natural minor", "minor", "aeolian" }, intervals = { 0, 2, 3, 5, 7, 8, 10 } },
  { id = "dorian", aliases = { "dorian" }, intervals = { 0, 2, 3, 5, 7, 9, 10 } },
  { id = "phrygian", aliases = { "phrygian" }, intervals = { 0, 1, 3, 5, 7, 8, 10 } },
  { id = "lydian", aliases = { "lydian" }, intervals = { 0, 2, 4, 6, 7, 9, 11 } },
  { id = "mixolydian", aliases = { "mixolydian" }, intervals = { 0, 2, 4, 5, 7, 9, 10 } },
  { id = "locrian", aliases = { "locrian" }, intervals = { 0, 1, 3, 5, 6, 8, 10 } },
  { id = "blues", aliases = { "blues", "minor blues" }, intervals = { 0, 3, 5, 6, 7, 10 } },
  { id = "whole tone", aliases = { "whole tone", "wholetone" }, intervals = { 0, 2, 4, 6, 8, 10 } },
  { id = "diminished", aliases = { "diminished", "octatonic" }, intervals = { 0, 2, 3, 5, 6, 8, 9, 11 } },
  { id = "major", aliases = { "major", "ionian" }, intervals = { 0, 2, 4, 5, 7, 9, 11 } },
  { id = "chromatic", aliases = { "chromatic" }, intervals = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } },
}

local function parse_root_pc(text)
  if not text or text == "" then return nil end
  local token = text:match("([A-Ga-g][#bB]?)")
  if not token then return nil end
  token = token:upper()
  return ROOT_MAP[token]
end

local function resolve_scale_intervals(scale_text)
  local normalized = normalize_text(scale_text)
  for i = 1, #SCALE_LIBRARY do
    local entry = SCALE_LIBRARY[i]
    for j = 1, #entry.aliases do
      local alias = entry.aliases[j]
      if normalized:find(alias, 1, true) then
        return entry.intervals, entry.id
      end
    end
  end
  return nil, nil
end

local function pcs_from_root_and_scale(root_pc, intervals)
  local pitch_set = {}
  if root_pc == nil or not intervals then return pitch_set end
  for i = 1, #intervals do
    local pc = (root_pc + intervals[i]) % 12
    pitch_set[pc] = true
  end
  return pitch_set
end

local function pitch_set_from_scale_mask(root_pc, scale_mask)
  local pitch_set = {}
  if root_pc == nil or scale_mask == nil then return pitch_set end

  local mask = math.floor(scale_mask)
  for interval = 0, 11 do
    local bit = 1 << interval
    if (mask & bit) ~= 0 then
      local pc = (root_pc + interval) % 12
      pitch_set[pc] = true
    end
  end

  return pitch_set
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

local function find_reascale_fx(track)
  if not track then return nil end
  local function matches_reascale(fx_name)
    local name = normalize_text(fx_name)
    return name:find("reascale", 1, true) or name:find("midi scale", 1, true) or name:find("midi_scale", 1, true)
  end

  local fx_count = reaper.TrackFX_GetCount(track)
  for fx = 0, fx_count - 1 do
    local _, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
    if matches_reascale(fx_name) then
      return fx
    end
  end

  local rec_fx_count = reaper.TrackFX_GetRecCount(track)
  for fx = 0, rec_fx_count - 1 do
    local fx_index = 0x1000000 + fx
    local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
    if matches_reascale(fx_name) then
      return fx_index
    end
  end

  return nil
end

local function detect_reascale_params(track, fx_index)
  local key_param = 0
  local scale_param = 1
  local param_count = reaper.TrackFX_GetNumParams(track, fx_index)

  for param = 0, param_count - 1 do
    local _, param_name = reaper.TrackFX_GetParamName(track, fx_index, param, "")
    local name = normalize_text(param_name)
    if name:find("scale", 1, true) and not name:find("root", 1, true) and not name:find("key", 1, true) then
      scale_param = param
    elseif name:find("key", 1, true) or name:find("root", 1, true) then
      key_param = param
    end
  end

  return key_param, scale_param
end

local function get_track_name(track)
  if not track then return "(none)" end
  local _, track_name = reaper.GetTrackName(track)
  if track_name == "" then track_name = "(unnamed track)" end
  return track_name
end

local function normalize_auto_snap_arm_mode(mode)
  if mode == SNAP_MODE_CHORD_ONLY then return AUTO_SNAP_ARM_MODE_CHORDS end
  if mode == SNAP_MODE_SCALE_ONLY then return AUTO_SNAP_ARM_MODE_SCALES end
  if mode == SNAP_MODE_CHORD_SCALE then return AUTO_SNAP_ARM_MODE_CHORDS_SCALES end
  if mode == SNAP_MODE_MELODIC_FLOW then return AUTO_SNAP_ARM_MODE_CHORDS_SCALES end

  if AUTO_SNAP_ARM_MODE_LABELS[mode] then
    return mode
  end

  return AUTO_SNAP_ARM_MODE_DEFAULT
end

local function normalize_snap_mode(mode)
  if mode == AUTO_SNAP_ARM_MODE_CHORDS or mode == "chords" then return SNAP_MODE_CHORD_ONLY end
  if mode == AUTO_SNAP_ARM_MODE_SCALES or mode == "scales" then return SNAP_MODE_SCALE_ONLY end
  if mode == AUTO_SNAP_ARM_MODE_CHORDS_SCALES or mode == "chords_scales" then return SNAP_MODE_CHORD_SCALE end
  if mode == "melodicflow" or mode == "melodic flow" then return SNAP_MODE_MELODIC_FLOW end

  if SNAP_MODE_LABELS[mode] then
    return mode
  end

  return SNAP_MODE_DEFAULT
end

local function normalize_new_note_snap_pipeline_mode(mode)
  local value = tostring(mode or ""):lower()
  if value == NEW_NOTE_SNAP_PIPELINE_PRE or value == NEW_NOTE_SNAP_PIPELINE_POST then
    return value
  end
  return NEW_NOTE_SNAP_PIPELINE_DEFAULT
end

local function get_new_note_snap_pipeline_mode()
  return normalize_new_note_snap_pipeline_mode(reaper.GetExtState(PANEL_SECTION, NEW_NOTE_SNAP_PIPELINE_KEY))
end

local function set_new_note_snap_pipeline_mode(mode)
  local normalized = normalize_new_note_snap_pipeline_mode(mode)
  reaper.SetExtState(PANEL_SECTION, NEW_NOTE_SNAP_PIPELINE_KEY, normalized, true)
  return normalized
end

local function get_new_note_snap_mode()
  return normalize_snap_mode(reaper.GetExtState(PANEL_SECTION, NEW_NOTE_SNAP_MODE_KEY))
end

local function set_new_note_snap_mode(mode)
  local normalized = normalize_snap_mode(mode)
  reaper.SetExtState(PANEL_SECTION, NEW_NOTE_SNAP_MODE_KEY, normalized, true)
  return normalized
end

local function set_input_manager_snap_mode_override(mode)
  local normalized = normalize_snap_mode(mode)
  reaper.SetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY, normalized, false)
  return normalized
end

local function clear_input_manager_snap_mode_override()
  reaper.SetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY, "", false)
end

local function set_new_note_snap_mode_runtime(mode, pipeline_mode)
  local normalized = set_new_note_snap_mode(mode)
  local selected_pipeline = normalize_new_note_snap_pipeline_mode(pipeline_mode or get_new_note_snap_pipeline_mode())
  if selected_pipeline == NEW_NOTE_SNAP_PIPELINE_PRE then
    clear_input_manager_snap_mode_override()
  end
  return normalized
end

local function snap_mode_to_label(mode)
  local normalized = normalize_snap_mode(mode)
  return SNAP_MODE_LABELS[normalized] or SNAP_MODE_LABELS[SNAP_MODE_DEFAULT]
end

local function auto_snap_arm_mode_to_label(mode)
  local normalized = normalize_auto_snap_arm_mode(mode)
  return AUTO_SNAP_ARM_MODE_LABELS[normalized] or AUTO_SNAP_ARM_MODE_LABELS[AUTO_SNAP_ARM_MODE_DEFAULT]
end

local function auto_snap_arm_mode_to_snap_mode(mode)
  local normalized = normalize_auto_snap_arm_mode(mode)
  return AUTO_SNAP_ARM_MODE_TO_SNAP_MODE[normalized]
end

local function snap_mode_to_auto_snap_arm_mode(mode)
  local normalized = normalize_snap_mode(mode)
  if normalized == SNAP_MODE_CHORD_ONLY then return AUTO_SNAP_ARM_MODE_CHORDS end
  if normalized == SNAP_MODE_SCALE_ONLY then return AUTO_SNAP_ARM_MODE_SCALES end
  if normalized == SNAP_MODE_CHORD_SCALE then return AUTO_SNAP_ARM_MODE_CHORDS_SCALES end
  if normalized == SNAP_MODE_MELODIC_FLOW then return AUTO_SNAP_ARM_MODE_CHORDS_SCALES end
  return nil
end

local get_auto_snap_arm_mode_for_track

local function selected_tracks_follow_arming_state(infos)
  local has_target = false
  local armed_count = 0
  local disarmed_count = 0

  for i = 1, #(infos or {}) do
    local info = infos[i]
    if info and not info.is_chord_track then
      has_target = true
      if normalize_auto_snap_arm_mode(info.auto_snap_arm_mode) == AUTO_SNAP_ARM_MODE_OFF then
        disarmed_count = disarmed_count + 1
      else
        armed_count = armed_count + 1
      end
    end
  end

  local all_armed = has_target and disarmed_count == 0
  local all_disarmed = has_target and armed_count == 0
  local mixed = has_target and not all_armed and not all_disarmed

  return {
    has_target = has_target,
    armed_count = armed_count,
    disarmed_count = disarmed_count,
    all_armed = all_armed,
    all_disarmed = all_disarmed,
    mixed = mixed,
  }
end

local function count_follow_armed_target_tracks()
  local _, chord_guid = reaper.GetProjExtState(0, EXT_SECTION, "TRACK_GUID")
  local chord_track = find_track_by_guid(chord_guid)

  local armed_count = 0
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track ~= chord_track then
      local snap_mode = auto_snap_arm_mode_to_snap_mode(get_auto_snap_arm_mode_for_track(track))
      if snap_mode then
        armed_count = armed_count + 1
      end
    end
  end

  return armed_count
end

local function normalize_chord_block_theme(theme)
  if CHORD_BLOCK_THEME_LABELS[theme] then
    return theme
  end
  return CHORD_BLOCK_THEME_DEFAULT
end

local function chord_block_theme_to_label(theme)
  local normalized = normalize_chord_block_theme(theme)
  return CHORD_BLOCK_THEME_LABELS[normalized] or CHORD_BLOCK_THEME_LABELS[CHORD_BLOCK_THEME_DEFAULT]
end

local function native_color_to_rgb01(native_color)
  local r, g, b = 0, 0, 0
  if reaper.ColorFromNative then
    r, g, b = reaper.ColorFromNative(native_color or 0)
  end

  return
    (tonumber(r) or 0) / 255,
    (tonumber(g) or 0) / 255,
    (tonumber(b) or 0) / 255
end

local function is_reaper_theme_dark()
  if not reaper.GetThemeColor then
    return true
  end

  local native_color = reaper.GetThemeColor("col_main_bg2", 0)
  local r, g, b = native_color_to_rgb01(native_color)
  local luminance = (r * 0.2126) + (g * 0.7152) + (b * 0.0722)
  return luminance < 0.52
end

local function resolve_chord_block_theme(theme)
  local normalized = normalize_chord_block_theme(theme)
  if normalized == CHORD_BLOCK_THEME_AUTO then
    if is_reaper_theme_dark() then
      return CHORD_BLOCK_THEME_PURPLE
    end
    return CHORD_BLOCK_THEME_NEUTRAL
  end
  return normalized
end

local function chord_block_theme_to_display_label(theme)
  local normalized = normalize_chord_block_theme(theme)
  if normalized == CHORD_BLOCK_THEME_AUTO then
    return "Auto (" .. chord_block_theme_to_label(resolve_chord_block_theme(normalized)) .. ")"
  end
  return chord_block_theme_to_label(normalized)
end

local function auto_snap_arm_mode_keys_from_guid(guid)
  if not guid or guid == "" then return nil end
  local safe_guid = guid:gsub("[^%w]", "_")
  return AUTO_SNAP_ARM_KEY_PREFIX .. safe_guid
end

get_auto_snap_arm_mode_for_track = function(track)
  local guid = get_track_guid(track)
  local key = auto_snap_arm_mode_keys_from_guid(guid)
  if not key then return AUTO_SNAP_ARM_MODE_DEFAULT end

  local _, stored = reaper.GetProjExtState(0, EXT_SECTION, key)
  return normalize_auto_snap_arm_mode(stored)
end

local function set_auto_snap_arm_mode_for_track(track, mode)
  if not track then return false end
  local guid = get_track_guid(track)
  local key = auto_snap_arm_mode_keys_from_guid(guid)
  if not key then return false end

  local normalized = normalize_auto_snap_arm_mode(mode)
  reaper.SetProjExtState(0, EXT_SECTION, key, normalized)
  return true
end

local function get_cut_overlaps_after_snap_enabled()
  local _, stored = reaper.GetProjExtState(0, EXT_SECTION, CUT_OVERLAPS_AFTER_SNAP_KEY)
  if not stored or stored == "" then
    return true
  end
  stored = tostring(stored):lower()
  return stored == "1" or stored == "true" or stored == "yes" or stored == "on"
end

local function set_cut_overlaps_after_snap_enabled(enabled)
  reaper.SetProjExtState(0, EXT_SECTION, CUT_OVERLAPS_AFTER_SNAP_KEY, enabled and "1" or "0")
end

local function round_half_away_from_zero(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  end
  return math.ceil(value - 0.5)
end

local function round_to_step(value, step)
  local step_value = tonumber(step) or 0
  if step_value <= 0 then
    return tonumber(value) or 0
  end
  local numeric = tonumber(value) or 0
  local scaled = numeric / step_value
  return round_half_away_from_zero(scaled) * step_value
end

local function clamp_timeline_calibration_px(value)
  local numeric = tonumber(value) or TIMELINE_CALIBRATION_DEFAULT
  if numeric < TIMELINE_CALIBRATION_MIN then
    numeric = TIMELINE_CALIBRATION_MIN
  elseif numeric > TIMELINE_CALIBRATION_MAX then
    numeric = TIMELINE_CALIBRATION_MAX
  end

  numeric = round_to_step(numeric, TIMELINE_CALIBRATION_FINE_STEP)
  if numeric < TIMELINE_CALIBRATION_MIN then
    numeric = TIMELINE_CALIBRATION_MIN
  elseif numeric > TIMELINE_CALIBRATION_MAX then
    numeric = TIMELINE_CALIBRATION_MAX
  end

  if math.abs(numeric) < 0.0001 then
    numeric = 0
  end
  return numeric
end

local function timeline_calibration_to_label(value)
  local px = clamp_timeline_calibration_px(value)
  local rounded_int = round_half_away_from_zero(px)
  local text_value = ""
  if math.abs(px - rounded_int) < 0.0001 then
    text_value = tostring(rounded_int)
  else
    text_value = string.format("%.1f", px)
    text_value = text_value:gsub("%.0$", "")
  end

  if px > 0 then
    return "+" .. text_value .. " px"
  end
  return text_value .. " px"
end

local function get_timeline_calibration_px()
  local stored = reaper.GetExtState(PANEL_SECTION, TIMELINE_CALIBRATION_PX_KEY)
  if not stored or stored == "" then
    return TIMELINE_CALIBRATION_DEFAULT
  end
  return clamp_timeline_calibration_px(stored)
end

local function set_timeline_calibration_px(value)
  local px = clamp_timeline_calibration_px(value)
  reaper.SetExtState(PANEL_SECTION, TIMELINE_CALIBRATION_PX_KEY, tostring(px), true)
  return px
end

local function show_timeline_calibration_values_menu(x, y, current_value, step)
  gfx.x = x
  gfx.y = y

  local current = clamp_timeline_calibration_px(current_value)
  local values = {}
  local menu_items = {}
  local value = TIMELINE_CALIBRATION_MIN
  local menu_step = math.max(TIMELINE_CALIBRATION_FINE_STEP, tonumber(step) or TIMELINE_CALIBRATION_FINE_STEP)
  local epsilon = menu_step * 0.25

  while value <= (TIMELINE_CALIBRATION_MAX + epsilon) do
    local normalized = clamp_timeline_calibration_px(value)
    values[#values + 1] = normalized

    local label = timeline_calibration_to_label(normalized)
    if math.abs(normalized - current) < 0.0001 then
      label = "!" .. label
    end
    menu_items[#menu_items + 1] = label

    value = value + menu_step
  end

  local menu_result = gfx.showmenu(table.concat(menu_items, "|"))
  if menu_result <= 0 then
    return nil
  end

  return values[menu_result]
end

local function show_timeline_calibration_menu(x, y, current_value)
  gfx.x = x
  gfx.y = y

  local mode_result = gfx.showmenu("Coarse (1 px)|Fine (0.5 px)|Reset to 0 px")
  if mode_result <= 0 then
    return nil
  end

  if mode_result == 1 then
    return show_timeline_calibration_values_menu(x, y, current_value, TIMELINE_CALIBRATION_COARSE_STEP)
  end

  if mode_result == 2 then
    return show_timeline_calibration_values_menu(x, y, current_value, TIMELINE_CALIBRATION_FINE_STEP)
  end

  if mode_result == 3 then
    return TIMELINE_CALIBRATION_DEFAULT
  end

  return nil
end

local function normalize_popout_tab_id(tab_id)
  local value = tostring(tab_id or ""):lower()
  if value == "theme" then
    return value
  end
  return "snap"
end

local function consume_popout_initial_tab()
  local tab_id = normalize_popout_tab_id(reaper.GetExtState(PANEL_SECTION, POPOUT_INITIAL_TAB_KEY))
  reaper.SetExtState(PANEL_SECTION, POPOUT_INITIAL_TAB_KEY, "", false)
  return tab_id
end

local function get_selected_tracks_info(chord_track)
  local infos = {}
  local selected_count = reaper.CountSelectedTracks(0)
  for i = 0, selected_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    infos[#infos + 1] = {
      track = track,
      name = get_track_name(track),
      auto_snap_arm_mode = get_auto_snap_arm_mode_for_track(track),
      is_chord_track = (track == chord_track),
    }
  end
  return infos
end

local function set_auto_snap_arm_mode_for_selected_tracks(mode)
  local normalized = normalize_auto_snap_arm_mode(mode)
  local _, chord_guid = reaper.GetProjExtState(0, EXT_SECTION, "TRACK_GUID")
  local chord_track = find_track_by_guid(chord_guid)

  local selected_count = reaper.CountSelectedTracks(0)
  if selected_count == 0 then
    return false, "No tracks selected."
  end

  local changed = 0
  local skipped_chord_track = 0

  for i = 0, selected_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track == chord_track then
      skipped_chord_track = skipped_chord_track + 1
    else
      if set_auto_snap_arm_mode_for_track(track, normalized) then
        changed = changed + 1
      end
    end
  end

  if changed == 0 and skipped_chord_track > 0 then
    return false, "Chord track cannot be set to auto-snap arm mode. Select target tracks."
  end

  if changed == 0 then
    return false, "No tracks were updated."
  end

  local suffix = ""
  if skipped_chord_track > 0 then
    suffix = " (chord track skipped)"
  end

  return true, "Set auto-snap arm mode to " .. auto_snap_arm_mode_to_label(normalized) .. " for " .. changed .. " track(s)" .. suffix .. "."
end

local function set_auto_snap_arm_mode_for_all_target_tracks(mode)
  local normalized = normalize_auto_snap_arm_mode(mode)
  local _, chord_guid = reaper.GetProjExtState(0, EXT_SECTION, "TRACK_GUID")
  local chord_track = find_track_by_guid(chord_guid)

  local track_count = reaper.CountTracks(0)
  if track_count <= 0 then
    return false, "No tracks in project."
  end

  local changed = 0
  local skipped_chord_track = 0

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track == chord_track then
      skipped_chord_track = skipped_chord_track + 1
    else
      if set_auto_snap_arm_mode_for_track(track, normalized) then
        changed = changed + 1
      end
    end
  end

  if changed == 0 and skipped_chord_track > 0 then
    return false, "No target tracks found."
  end

  if changed == 0 then
    return false, "No tracks were updated."
  end

  local suffix = ""
  if skipped_chord_track > 0 then
    suffix = " (chord track skipped)"
  end

  return true, "Set auto-snap arm mode to " .. auto_snap_arm_mode_to_label(normalized) .. " for " .. changed .. " track(s)" .. suffix .. "."
end

local function is_auto_snap_arm_live_mode(mode)
  return mode == "track_auto_snap_arm" or mode == "track_auto_snap_arm_record"
end

local function selected_tracks_auto_snap_arm_summary(chord_track)
  local infos = get_selected_tracks_info(chord_track)
  if #infos == 0 then
    return "No selected tracks", infos
  end

  local first_mode = nil
  local mixed = false
  local has_non_chord = false

  for i = 1, #infos do
    local info = infos[i]
    if not info.is_chord_track then
      has_non_chord = true
      if not first_mode then
        first_mode = info.auto_snap_arm_mode
      elseif first_mode ~= info.auto_snap_arm_mode then
        mixed = true
      end
    end
  end

  if not has_non_chord then
    return "Only chord track selected", infos
  end

  if mixed then
    return "Mixed", infos
  end

  return auto_snap_arm_mode_to_label(first_mode), infos
end

local function for_each_midi_take_on_track(track, callback)
  local item_count = reaper.CountTrackMediaItems(track)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      callback(take)
    end
  end
end

local function load_state()
  local _, guid = reaper.GetProjExtState(0, EXT_SECTION, "TRACK_GUID")
  local _, root_pc_text = reaper.GetProjExtState(0, EXT_SECTION, "ROOT_PC")
  local _, root_name = reaper.GetProjExtState(0, EXT_SECTION, "ROOT_NAME")
  local _, scale_name = reaper.GetProjExtState(0, EXT_SECTION, "SCALE_NAME")
  local _, scale_csv = reaper.GetProjExtState(0, EXT_SECTION, "SCALE_PCS")

  local state = {
    track_guid = guid,
    root_pc = tonumber(root_pc_text),
    root_name = root_name,
    scale_name = scale_name,
    scale_pcs = csv_to_set(scale_csv),
  }

  return state
end

local function save_state(state)
  reaper.SetProjExtState(0, EXT_SECTION, "TRACK_GUID", state.track_guid or "")
  reaper.SetProjExtState(0, EXT_SECTION, "ROOT_PC", tostring(state.root_pc or ""))
  reaper.SetProjExtState(0, EXT_SECTION, "ROOT_NAME", state.root_name or "")
  reaper.SetProjExtState(0, EXT_SECTION, "SCALE_NAME", state.scale_name or "")
  reaper.SetProjExtState(0, EXT_SECTION, "SCALE_PCS", set_to_csv(state.scale_pcs or {}))
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

local DEGREE_LABELS_BY_INTERVAL = {
  "I", "bII", "II", "bIII", "III", "IV", "bV", "V", "bVI", "VI", "bVII", "VII"
}

local CHORD_INTERPRET_PATTERNS = {
  { suffix = "maj7", intervals = { 0, 4, 7, 11 }, quality = "major", min_matches = 3 },
  { suffix = "7", intervals = { 0, 4, 7, 10 }, quality = "dominant", min_matches = 3 },
  { suffix = "m7", intervals = { 0, 3, 7, 10 }, quality = "minor", min_matches = 3 },
  { suffix = "mMaj7", intervals = { 0, 3, 7, 11 }, quality = "minor", min_matches = 3 },
  { suffix = "m7b5", intervals = { 0, 3, 6, 10 }, quality = "diminished", min_matches = 3 },
  { suffix = "dim7", intervals = { 0, 3, 6, 9 }, quality = "diminished", min_matches = 3 },
  { suffix = "", intervals = { 0, 4, 7 }, quality = "major", min_matches = 2 },
  { suffix = "m", intervals = { 0, 3, 7 }, quality = "minor", min_matches = 2 },
  { suffix = "dim", intervals = { 0, 3, 6 }, quality = "diminished", min_matches = 2 },
  { suffix = "+", intervals = { 0, 4, 8 }, quality = "augmented", min_matches = 2 },
  { suffix = "sus2", intervals = { 0, 2, 7 }, quality = "suspended", min_matches = 2 },
  { suffix = "sus4", intervals = { 0, 5, 7 }, quality = "suspended", min_matches = 2 },
  { suffix = "5", intervals = { 0, 7 }, quality = "power", min_matches = 2 },
  { suffix = "", intervals = { 0 }, quality = "single", min_matches = 1 },
}

local CHORD_FORMULAS = {
  major = { 0, 4, 7 },
  minor = { 0, 3, 7 },
  dominant7 = { 0, 4, 7, 10 },
  major7 = { 0, 4, 7, 11 },
}

local function pitch_set_signature(pitch_set)
  local values = {}
  for pc = 0, 11 do
    if pitch_set and pitch_set[pc] then
      values[#values + 1] = tostring(pc)
    end
  end
  return table.concat(values, ",")
end

local function gather_chord_notes_detailed(chord_track)
  local notes = {}
  if not chord_track then return notes end

  local item_count = reaper.CountTrackMediaItems(chord_track)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(chord_track, item_index)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local _, note_count = reaper.MIDI_CountEvts(take)
      for note_index = 0, note_count - 1 do
        local ok, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, note_index)
        if ok and not muted and end_ppq > start_ppq then
          local start_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
          local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)
          if end_time > start_time then
            notes[#notes + 1] = {
              start_time = start_time,
              end_time = end_time,
              start_ppq = start_ppq,
              end_ppq = end_ppq,
              pc = pitch % 12,
              pitch = pitch,
              take = take,
              note_index = note_index,
              selected = selected,
              muted = muted,
              channel = channel,
              velocity = velocity,
            }
          end
        end
      end
    end
  end

  table.sort(notes, function(a, b)
    if a.start_time == b.start_time then
      return a.pitch < b.pitch
    end
    return a.start_time < b.start_time
  end)

  return notes
end

local function interval_set_for_root(pitch_set, root_pc)
  local interval_set = {}
  local total = 0
  for pc = 0, 11 do
    if pitch_set[pc] then
      interval_set[(pc - root_pc) % 12] = true
      total = total + 1
    end
  end
  return interval_set, total
end

local function score_chord_pattern(interval_set, interval_total, pattern)
  local matches = 0
  for i = 1, #pattern.intervals do
    if interval_set[pattern.intervals[i]] then
      matches = matches + 1
    end
  end

  if matches < pattern.min_matches then
    return nil
  end

  local missing = #pattern.intervals - matches
  local extras = interval_total - matches

  return (matches * 14) - (missing * 9) - (extras * 2) - (#pattern.intervals * 0.1)
end

local function degree_label_for_root(root_pc, scale_root_pc, quality)
  if scale_root_pc == nil then
    return "?"
  end

  local interval = (root_pc - scale_root_pc) % 12
  local degree = DEGREE_LABELS_BY_INTERVAL[interval + 1] or "?"

  if quality == "minor" or quality == "diminished" then
    degree = degree:lower()
  end

  if quality == "diminished" then
    degree = degree .. "°"
  end

  return degree
end

local function first_pitch_class(pitch_set)
  for pc = 0, 11 do
    if pitch_set[pc] then
      return pc
    end
  end
  return nil
end

local function interpret_chord_pitch_set(pitch_set, scale_root_pc)
  local best = nil

  for root_pc = 0, 11 do
    if pitch_set[root_pc] then
      local interval_set, interval_total = interval_set_for_root(pitch_set, root_pc)

      for i = 1, #CHORD_INTERPRET_PATTERNS do
        local pattern = CHORD_INTERPRET_PATTERNS[i]
        local score = score_chord_pattern(interval_set, interval_total, pattern)
        if score and (not best or score > best.score) then
          best = {
            score = score,
            root_pc = root_pc,
            suffix = pattern.suffix,
            quality = pattern.quality,
          }
        end
      end
    end
  end

  if not best then
    local fallback_root = first_pitch_class(pitch_set)
    if fallback_root == nil then
      return {
        root_pc = nil,
        chord_name = "(none)",
        degree_label = "?",
        quality = "unknown",
      }
    end

    return {
      root_pc = fallback_root,
      chord_name = pc_to_note_name(fallback_root),
      degree_label = degree_label_for_root(fallback_root, scale_root_pc, "major"),
      quality = "major",
    }
  end

  local chord_name = pc_to_note_name(best.root_pc) .. best.suffix
  local degree_label = degree_label_for_root(best.root_pc, scale_root_pc, best.quality)

  return {
    root_pc = best.root_pc,
    chord_name = chord_name,
    degree_label = degree_label,
    quality = best.quality,
  }
end

local function unique_sorted_times(notes)
  local raw_times = {}
  for i = 1, #notes do
    raw_times[#raw_times + 1] = notes[i].start_time
    raw_times[#raw_times + 1] = notes[i].end_time
  end

  table.sort(raw_times)

  local unique = {}
  local epsilon = 0.00001
  for i = 1, #raw_times do
    local value = raw_times[i]
    local previous = unique[#unique]
    if not previous or math.abs(previous - value) > epsilon then
      unique[#unique + 1] = value
    end
  end

  return unique
end

local function active_notes_between_times(notes, start_time, end_time)
  local pitch_set = {}
  local pitch_count = 0
  local active_refs = {}
  local start_refs = {}
  local midpoint = (start_time + end_time) * 0.5
  local epsilon = 0.0005

  for i = 1, #notes do
    local note = notes[i]
    if note.start_time > midpoint then
      break
    end

    if note.start_time <= midpoint and note.end_time > midpoint then
      if not pitch_set[note.pc] then
        pitch_set[note.pc] = true
        pitch_count = pitch_count + 1
      end
      active_refs[#active_refs + 1] = note

      if math.abs(note.start_time - start_time) <= epsilon then
        start_refs[#start_refs + 1] = note
      end
    end
  end

  if #start_refs == 0 then
    for i = 1, #active_refs do
      local note = active_refs[i]
      if note.start_time <= (start_time + epsilon) then
        start_refs[#start_refs + 1] = note
      end
    end
  end

  return pitch_set, pitch_count, active_refs, start_refs
end

local function collect_chord_blocks(chord_track, state)
  local blocks = {}
  local detailed_notes = gather_chord_notes_detailed(chord_track)
  if #detailed_notes == 0 then
    return blocks
  end

  local times = unique_sorted_times(detailed_notes)
  if #times < 2 then
    return blocks
  end

  local scale_root_pc = state and state.root_pc or nil

  for i = 1, #times - 1 do
    local start_time = times[i]
    local end_time = times[i + 1]

    if end_time > start_time + 0.00001 then
      local pitch_set, pitch_count, active_refs, start_refs = active_notes_between_times(detailed_notes, start_time, end_time)
      if pitch_count > 0 then
        local interpreted = interpret_chord_pitch_set(pitch_set, scale_root_pc)
        local signature = pitch_set_signature(pitch_set)

        local block = {
          start_time = start_time,
          end_time = end_time,
          pitch_set = pitch_set,
          pitch_signature = signature,
          chord_name = interpreted.chord_name,
          degree_label = interpreted.degree_label,
          root_pc = interpreted.root_pc,
          quality = interpreted.quality,
          active_note_refs = active_refs,
          start_note_refs = start_refs,
        }

        local previous = blocks[#blocks]
        if previous and
          math.abs(previous.end_time - block.start_time) <= 0.0005 and
          previous.pitch_signature == block.pitch_signature and
          previous.chord_name == block.chord_name and
          previous.degree_label == block.degree_label then
          previous.end_time = block.end_time
        else
          block.block_id = string.format("%.6f|%.6f|%s", block.start_time, block.end_time, block.pitch_signature)
          blocks[#blocks + 1] = block
        end
      end
    end
  end

  return blocks
end

local function sorted_block_note_refs(block)
  local source = block.start_note_refs
  if not source or #source == 0 then
    source = block.active_note_refs or {}
  end

  local refs = {}
  for i = 1, #source do
    refs[#refs + 1] = source[i]
  end

  table.sort(refs, function(a, b)
    if a.pitch == b.pitch then
      return a.note_index < b.note_index
    end
    return a.pitch < b.pitch
  end)

  return refs
end

local function update_takes_after_note_changes(note_refs)
  local touched = {}
  for i = 1, #note_refs do
    local take = note_refs[i].take
    if take and not touched[take] then
      touched[take] = true
      reaper.MIDI_Sort(take)
      local item = reaper.GetMediaItemTake_Item(take)
      if item then
        reaper.UpdateItemInProject(item)
      end
    end
  end
  reaper.UpdateArrange()
end

local function set_note_ref_pitch(note_ref, new_pitch)
  if not note_ref.take then return end
  local clamped = math.max(0, math.min(127, math.floor(new_pitch + 0.5)))
  reaper.MIDI_SetNote(
    note_ref.take,
    note_ref.note_index,
    note_ref.selected,
    note_ref.muted,
    note_ref.start_ppq,
    note_ref.end_ppq,
    note_ref.channel,
    clamped,
    note_ref.velocity,
    true
  )
end

local function apply_block_inversion(block, invert_up)
  local note_refs = sorted_block_note_refs(block)
  if #note_refs < 2 then
    return false, "Need at least two notes in the chord block for inversion."
  end

  local target = invert_up and note_refs[1] or note_refs[#note_refs]
  local offset = invert_up and 12 or -12
  local new_pitch = target.pitch + offset
  if new_pitch < 0 or new_pitch > 127 then
    return false, "Inversion would move notes outside MIDI pitch range."
  end

  reaper.Undo_BeginBlock()
  set_note_ref_pitch(target, new_pitch)
  reaper.Undo_EndBlock("Oz Chord Track: invert chord block", -1)

  update_takes_after_note_changes({ target })
  return true, "Chord inversion applied."
end

local function apply_block_formula(block, root_pc, intervals, undo_label)
  local note_refs = sorted_block_note_refs(block)
  if #note_refs == 0 then
    return false, "No notes found for this chord block."
  end
  if root_pc == nil then
    return false, "Unable to determine a chord root for this block."
  end
  if not intervals or #intervals == 0 then
    return false, "No chord formula was provided."
  end

  local lowest_pitch = note_refs[1].pitch
  local root_base_pitch = lowest_pitch - ((lowest_pitch - root_pc) % 12)

  local targets = {}
  for i = 1, #note_refs do
    local interval = intervals[((i - 1) % #intervals) + 1]
    local octave = math.floor((i - 1) / #intervals)
    targets[i] = root_base_pitch + interval + (octave * 12)
  end

  while targets[#targets] and targets[#targets] > 127 do
    for i = 1, #targets do
      targets[i] = targets[i] - 12
    end
  end

  while targets[1] and targets[1] < 0 do
    for i = 1, #targets do
      targets[i] = targets[i] + 12
    end
  end

  reaper.Undo_BeginBlock()
  for i = 1, #note_refs do
    set_note_ref_pitch(note_refs[i], targets[i])
  end
  reaper.Undo_EndBlock(undo_label, -1)

  update_takes_after_note_changes(note_refs)
  return true, "Chord block updated."
end

local function open_block_in_midi_editor(block)
  local note_refs = sorted_block_note_refs(block)
  if #note_refs == 0 then
    return false, "No notes found for this chord block."
  end

  local take = note_refs[1].take
  if not take then
    return false, "Could not resolve the MIDI take for this chord block."
  end

  local item = reaper.GetMediaItemTake_Item(take)
  if not item then
    return false, "Could not resolve the MIDI item for this chord block."
  end

  local editor = nil
  if reaper.APIExists("MIDIEditor_Open") then
    editor = reaper.MIDIEditor_Open(item)
  end

  if not editor then
    reaper.Main_OnCommand(40153, 0)
    editor = reaper.MIDIEditor_GetActive()
  end

  if not editor then
    return false, "Could not open MIDI editor for this chord block."
  end

  local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, block.start_time)
  local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, block.end_time)
  local _, note_count = reaper.MIDI_CountEvts(take)

  for i = 0, note_count - 1 do
    local ok, _, muted, note_start_ppq, note_end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, i)
    if ok then
      local should_select = note_start_ppq < end_ppq and note_end_ppq > start_ppq
      reaper.MIDI_SetNote(take, i, should_select, muted, note_start_ppq, note_end_ppq, channel, pitch, velocity, true)
    end
  end
  reaper.MIDI_Sort(take)

  reaper.SetEditCurPos2(0, block.start_time, true, false)
  reaper.GetSet_LoopTimeRange2(0, true, false, block.start_time, block.end_time, false)

  reaper.MIDIEditor_OnCommand(editor, 40466)
  reaper.MIDIEditor_OnCommand(editor, 40726)

  return true, "Opened MIDI editor for chord block: " .. (block.chord_name or "")
end

local function apply_block_context_action(block, action_id)
  if action_id == 1 then
    return open_block_in_midi_editor(block)
  elseif action_id == 2 then
    return apply_block_inversion(block, true)
  elseif action_id == 3 then
    return apply_block_inversion(block, false)
  elseif action_id == 4 then
    return apply_block_formula(block, block.root_pc, CHORD_FORMULAS.major, "Oz Chord Track: set chord block major")
  elseif action_id == 5 then
    return apply_block_formula(block, block.root_pc, CHORD_FORMULAS.minor, "Oz Chord Track: set chord block minor")
  elseif action_id == 6 then
    return apply_block_formula(block, block.root_pc, CHORD_FORMULAS.dominant7, "Oz Chord Track: set chord block dominant 7")
  elseif action_id == 7 then
    return apply_block_formula(block, block.root_pc, CHORD_FORMULAS.major7, "Oz Chord Track: set chord block major 7")
  elseif action_id == 8 then
    return apply_block_formula(block, (block.root_pc + 9) % 12, CHORD_FORMULAS.minor, "Oz Chord Track: substitute relative minor")
  elseif action_id == 9 then
    return apply_block_formula(block, (block.root_pc + 3) % 12, CHORD_FORMULAS.major, "Oz Chord Track: substitute relative major")
  elseif action_id == 10 then
    return apply_block_formula(block, (block.root_pc + 6) % 12, CHORD_FORMULAS.dominant7, "Oz Chord Track: substitute tritone")
  end

  return false, "No chord action was chosen."
end

local function nearest_pitch(original_pitch, allowed_pcs)
  for distance = 0, 127 do
    local lower = original_pitch - distance
    if lower >= 0 and allowed_pcs[lower % 12] then
      return lower
    end

    if distance > 0 then
      local upper = original_pitch + distance
      if upper <= 127 and allowed_pcs[upper % 12] then
        return upper
      end
    end
  end

  return original_pitch
end
local function melodic_flow_pitch(original_pitch, chord_set, scale_set)
  local root_pc = nil
  for pc = 0, 11 do
    if chord_set[pc] then
      root_pc = pc
      break
    end
  end
  if root_pc == nil then
    return nil
  end

  local source_set = set_count(scale_set) > 0 and scale_set or chord_set
  local ordered_intervals = {}
  for offset = 0, 11 do
    local pc = (root_pc + offset) % 12
    if source_set[pc] then
      ordered_intervals[#ordered_intervals + 1] = offset
    end
  end
  if #ordered_intervals == 0 then
    return nil
  end

  local degree_offsets = {}
  for i = 1, 7 do
    local third_index = (i - 1) * 2
    local wrapped_index = (third_index % #ordered_intervals) + 1
    local octave_offset = math.floor(third_index / #ordered_intervals) * 12
    degree_offsets[i] = ordered_intervals[wrapped_index] + octave_offset
  end

  local function clamp_midi_pitch(pitch)
    if pitch < 0 then return 0 end
    if pitch > 127 then return 127 end
    return pitch
  end

  local base_oct = math.floor(original_pitch / 12) * 12
  local white_targets = {}
  for i = 1, 7 do
    white_targets[i] = base_oct + root_pc + degree_offsets[i]
  end

  local pc = original_pitch % 12
  local white_index = nil
  if pc == 0 then white_index = 1
  elseif pc == 2 then white_index = 2
  elseif pc == 4 then white_index = 3
  elseif pc == 5 then white_index = 4
  elseif pc == 7 then white_index = 5
  elseif pc == 9 then white_index = 6
  elseif pc == 11 then white_index = 7
  end

  if white_index then
    return clamp_midi_pitch(white_targets[white_index])
  end

  local black_neighbors = {
    [1] = { 1, 2 },
    [3] = { 2, 3 },
    [6] = { 4, 5 },
    [8] = { 5, 6 },
    [10] = { 6, 7 },
  }
  local pair = black_neighbors[pc]
  if not pair then
    return nil
  end

  local lower_target = white_targets[pair[1]]
  local upper_target = white_targets[pair[2]]
  if upper_target <= lower_target then
    upper_target = lower_target + 1
  end

  local low_candidate = lower_target + 1
  local high_candidate = upper_target - 1
  if high_candidate < low_candidate then
    high_candidate = low_candidate
  end

  local passing = low_candidate
  if math.abs(original_pitch - high_candidate) < math.abs(original_pitch - low_candidate) then
    passing = high_candidate
  end

  return clamp_midi_pitch(passing)
end

local function build_allowed_set(mode, chord_set, chord_count, scale_set)
  local scale_count = set_count(scale_set)

  if mode == "scale_only" then
    return copy_set(scale_set)
  end

  if mode == "chord_only" then
    if chord_count > 0 then
      return copy_set(chord_set)
    end
    return {}
  end

  if chord_count > 0 and scale_count > 0 then
    local both = intersect_sets(chord_set, scale_set)
    if set_count(both) > 0 then
      return both
    end
    return copy_set(chord_set)
  end

  if chord_count > 0 then
    return copy_set(chord_set)
  end

  return copy_set(scale_set)
end

local function count_selected_notes(take, note_count)
  local selected_count = 0
  for note_index = 0, note_count - 1 do
    local ok, selected = reaper.MIDI_GetNote(take, note_index)
    if ok and selected then selected_count = selected_count + 1 end
  end
  return selected_count
end

local function truncate_overlapping_notes_in_take(take)
  local _, note_count = reaper.MIDI_CountEvts(take)
  if note_count < 2 then return 0 end

  local grouped = {}

  for note_index = 0, note_count - 1 do
    local ok, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, note_index)
    if ok and not muted and end_ppq > start_ppq then
      local key = tostring(channel) .. "|" .. tostring(pitch)
      if not grouped[key] then
        grouped[key] = {}
      end
      grouped[key][#grouped[key] + 1] = {
        index = note_index,
        selected = selected,
        muted = muted,
        start_ppq = start_ppq,
        end_ppq = end_ppq,
        channel = channel,
        pitch = pitch,
        velocity = velocity,
      }
    end
  end

  local changed = 0

  for _, notes in pairs(grouped) do
    if #notes > 1 then
      table.sort(notes, function(a, b)
        if a.start_ppq == b.start_ppq then
          return a.index < b.index
        end
        return a.start_ppq < b.start_ppq
      end)

      local previous = notes[1]
      for i = 2, #notes do
        local current = notes[i]
        if current.start_ppq < previous.end_ppq then
          local new_end_ppq = math.max(previous.start_ppq + 1, current.start_ppq)
          if new_end_ppq < previous.end_ppq then
            reaper.MIDI_SetNote(
              take,
              previous.index,
              previous.selected,
              previous.muted,
              previous.start_ppq,
              new_end_ppq,
              previous.channel,
              previous.pitch,
              previous.velocity,
              true
            )
            previous.end_ppq = new_end_ppq
            changed = changed + 1
          end
        end
        previous = current
      end
    end
  end

  return changed
end

local function snap_take_notes(take, chord_notes, scale_set, mode, start_note_index, cut_overlaps)
  local _, note_count = reaper.MIDI_CountEvts(take)
  if note_count == 0 then return 0, 0, note_count end

  local selected_count = count_selected_notes(take, note_count)
  local selected_only = selected_count > 0 and (start_note_index == nil)
  local from_index = start_note_index or 0
  if from_index < 0 then from_index = 0 end
  if from_index >= note_count then return 0, 0, note_count end

  local changed = 0
  local processed = 0
  local allow_inversions = SnapSettings.get_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, false)
  local current_group_start_ppq = nil
  local current_group_channel = nil
  local last_group_snapped_pitch = nil

  for note_index = from_index, note_count - 1 do
    local ok, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, note_index)
    if ok and not muted and (not selected_only or selected) then
      if (not allow_inversions) and (current_group_start_ppq ~= start_ppq or current_group_channel ~= channel) then
        current_group_start_ppq = start_ppq
        current_group_channel = channel
        last_group_snapped_pitch = nil
      end

      local note_time = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
      local chord_set, chord_count = chord_pcs_at_time(chord_notes, note_time)
      local allowed_set = build_allowed_set(mode, chord_set, chord_count, scale_set)
      if set_count(allowed_set) > 0 then
        local snapped_pitch = nil
        if normalize_snap_mode(mode) == SNAP_MODE_MELODIC_FLOW then
          snapped_pitch = melodic_flow_pitch(pitch, chord_set, scale_set)
        end
        if snapped_pitch == nil then
          snapped_pitch = nearest_pitch(pitch, allowed_set)
        end

        if (not allow_inversions) and last_group_snapped_pitch ~= nil and snapped_pitch < last_group_snapped_pitch then
          local floor_pitch = math.max(0, math.floor(last_group_snapped_pitch))
          local non_inverted = nil
          local best_distance = math.huge
          for candidate = floor_pitch, 127 do
            if allowed_set[candidate % 12] then
              local distance = math.abs(candidate - pitch)
              if distance < best_distance or (distance == best_distance and (non_inverted == nil or candidate < non_inverted)) then
                non_inverted = candidate
                best_distance = distance
              end
            end
          end
          if non_inverted then
            snapped_pitch = non_inverted
          end
        end

        if (not allow_inversions) then
          last_group_snapped_pitch = snapped_pitch
        end

        processed = processed + 1
        if snapped_pitch ~= pitch then
          reaper.MIDI_SetNote(take, note_index, selected, muted, start_ppq, end_ppq, channel, snapped_pitch, velocity, true)
          changed = changed + 1
        end
      end
    end
  end

  if cut_overlaps then
    changed = changed + truncate_overlapping_notes_in_take(take)
  end

  if changed > 0 then
    reaper.MIDI_Sort(take)
  end

  return changed, processed, note_count
end

local function gather_target_takes(chord_track)
  local takes = {}

  local midi_editor = reaper.MIDIEditor_GetActive()
  if midi_editor then
    local take = reaper.MIDIEditor_GetTake(midi_editor)
    if take and reaper.TakeIsMIDI(take) then
      takes[#takes + 1] = take
      return takes, "active MIDI editor take"
    end
  end

  local selected_items = reaper.CountSelectedMediaItems(0)
  for i = 0, selected_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      takes[#takes + 1] = take
    end
  end

  if #takes > 0 then
    return takes, "selected MIDI items"
  end

  local selected_tracks = reaper.CountSelectedTracks(0)
  for i = 0, selected_tracks - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track ~= chord_track then
      local item_count = reaper.CountTrackMediaItems(track)
      for item_index = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, item_index)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
          takes[#takes + 1] = take
        end
      end
    end
  end

  if #takes > 0 then
    return takes, "all MIDI items on selected tracks"
  end

  return takes, ""
end

local function load_chord_track_from_state()
  local state = load_state()
  if not state.track_guid or state.track_guid == "" then
    return nil, state, "No chord track is stored yet. Run the set chord track action first."
  end

  local chord_track = find_track_by_guid(state.track_guid)
  if not chord_track then
    return nil, state, "Stored chord track no longer exists in this project. Set it again."
  end

  return chord_track, state, nil
end

local function set_chord_track(track)
  if not track then
    return false, "Select the MIDI chord source track first."
  end

  local state = load_state()
  state.track_guid = get_track_guid(track)
  save_state(state)

  return true, get_track_name(track)
end

local function sync_scale_from_midi_editor_internal()
  local midi_editor = reaper.MIDIEditor_GetActive()
  if not midi_editor then
    return false, "Open a MIDI editor and choose Key snap root/scale first."
  end

  local take = reaper.MIDIEditor_GetTake(midi_editor)
  if not take or not reaper.TakeIsMIDI(take) then
    return false, "Active MIDI editor does not have a valid MIDI take."
  end

  if not reaper.APIExists("MIDI_GetScale") then
    return false, "This REAPER version does not support MIDI editor scale capture via MIDI_GetScale."
  end

  local scale_enabled = reaper.MIDIEditor_GetSetting_int(midi_editor, "scale_enabled")
  local root_setting = reaper.MIDIEditor_GetSetting_int(midi_editor, "scale_root")
  local root_pc = math.floor(tonumber(root_setting) or 0) % 12

  local has_scale, take_root, scale_mask, scale_name = reaper.MIDI_GetScale(take)
  if has_scale and tonumber(take_root) then
    root_pc = math.floor(tonumber(take_root)) % 12
  end

  local scale_pcs = {}
  if has_scale and tonumber(scale_mask) then
    scale_pcs = pitch_set_from_scale_mask(root_pc, tonumber(scale_mask))
  end

  if set_count(scale_pcs) == 0 then
    return false, "Could not read scale from the active MIDI editor. Enable Key snap and choose a root/scale first."
  end

  local state = load_state()
  state.root_pc = root_pc
  state.root_name = pc_to_note_name(root_pc)
  state.scale_name = (scale_name and scale_name ~= "") and scale_name or "custom"
  state.scale_pcs = scale_pcs
  save_state(state)

  local suffix = ""
  if scale_enabled ~= 1 then
    suffix = " (Key snap is currently off, but the selected scale was captured)"
  end

  return true, state, suffix
end

local function snap_selected_midi_internal(mode)
  local snap_mode = normalize_snap_mode(mode)
  local chord_track, state, err = load_chord_track_from_state()
  if not chord_track then
    return false, err
  end

  if SnapSettings.mode_requires_scale(snap_mode, SNAP_MODE_SCALE_ONLY, SNAP_MODE_CHORD_SCALE) and set_count(state.scale_pcs) == 0 then
    return false, "No scale is stored yet. Run the sync scale action from the MIDI editor first."
  end

  local chord_notes = gather_chord_notes(chord_track)
  if #chord_notes == 0 then
    return false, "Chord track has no MIDI notes to define chords."
  end

  local takes, take_source = gather_target_takes(chord_track)
  if #takes == 0 then
    return false, "No MIDI targets found. Select MIDI items, or open a MIDI editor, or select target tracks."
  end

  reaper.Undo_BeginBlock()

  local changed_total = 0
  local processed_total = 0
  local cut_overlaps = get_cut_overlaps_after_snap_enabled()

  for i = 1, #takes do
    local changed, processed = snap_take_notes(takes[i], chord_notes, state.scale_pcs, snap_mode, nil, cut_overlaps)
    changed_total = changed_total + changed
    processed_total = processed_total + processed
  end

  reaper.Undo_EndBlock("Oz Chord Track: snap MIDI notes", -1)
  reaper.UpdateArrange()

  return true, {
    take_source = take_source,
    processed_total = processed_total,
    changed_total = changed_total,
  }
end

local function find_first_track_with_reascale()
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if find_reascale_fx(track) then
      return track
    end
  end
  return nil
end

local function normalize_auto_snap_arm_status_text(status)
  local text = tostring(status or "")
  text = text:gsub("follow mode", "auto-snap arm")
  text = text:gsub("Follow", "Auto-snap")
  return text
end

local function format_scale_capture_status(result, suffix)
  return "Captured: " .. tostring(result.root_name or "") .. " - " .. tostring(result.scale_name or "") .. tostring(suffix or "")
end

local function format_snap_midi_status(mode, result)
  return
    "Snap MIDI (" .. snap_mode_to_label(mode) .. "): processed " ..
    tostring(result.processed_total or 0) .. " notes, changed " ..
    tostring(result.changed_total or 0) .. " (" .. tostring(result.take_source or "") .. ")."
end

local function format_one_click_status(result)
  return
    "One-click: " .. tostring(result.chord_track_name or "") .. " | " ..
    tostring(result.scale_result and result.scale_result.root_name or "") .. " " ..
    tostring(result.scale_result and result.scale_result.scale_name or "") ..
    " | changed " .. tostring(result.snap_result and result.snap_result.changed_total or 0) .. " notes." ..
    tostring(result.scale_suffix or "")
end

local function format_auto_snap_status(result)
  local suffix = ""
  if (result.skipped_off or 0) > 0 then
    suffix = " " .. tostring(result.skipped_off) .. " selected track(s) were Auto-snap Off."
  end

  return
    "Auto-snap: " .. tostring(result.track_count or 0) .. " tracks, " ..
    tostring(result.take_count or 0) .. " takes, " ..
    tostring(result.changed_total or 0) .. " notes changed." .. suffix
end

local function format_snap_armed_status(result)
  return
    "Snap armed: " .. tostring(result.track_count or 0) .. " tracks, " ..
    tostring(result.take_count or 0) .. " takes, " ..
    tostring(result.changed_total or 0) .. " notes changed."
end

local function format_snap_selected_status(snap_mode, result)
  return
    "Snap selected (" .. snap_mode_to_label(snap_mode) .. "): " ..
    tostring(result.track_count or 0) .. " tracks, " ..
    tostring(result.take_count or 0) .. " takes, " ..
    tostring(result.changed_total or 0) .. " notes changed."
end

local function format_cut_overlaps_status(enabled)
  if enabled then
    return "Cut overlaps after snap enabled."
  end
  return "Cut overlaps after snap disabled."
end

local function format_theme_set_status(theme)
  return "Chord block theme set to " .. chord_block_theme_to_display_label(theme) .. "."
end

local function format_timeline_calibration_status(px)
  return "Timeline alignment offset set to " .. timeline_calibration_to_label(px) .. "."
end

function OzChordTrack.set_selected_track_as_chord_track()
  local track = reaper.GetSelectedTrack(0, 0)
  local ok, result = set_chord_track(track)
  if not ok then
    message(result)
    return
  end

  message("Chord track set to: " .. result)
end

function OzChordTrack.sync_scale_from_selected_track()
  local ok, result, suffix = sync_scale_from_midi_editor_internal()
  if not ok then
    message(result)
    return
  end

  message(format_scale_capture_status(result, suffix))
end

function OzChordTrack.sync_scale_from_midi_editor()
  local ok, result, suffix = sync_scale_from_midi_editor_internal()
  if not ok then
    message(result)
    return
  end

  message(format_scale_capture_status(result, suffix))
end

function OzChordTrack.snap_selected_midi(mode)
  local snap_mode = normalize_snap_mode(mode)
  local ok, result = snap_selected_midi_internal(mode)
  if not ok then
    message(result)
    return
  end

  message(format_snap_midi_status(snap_mode, result))
end

local function targets_need_scale(targets)
  for i = 1, #targets do
    local target_mode = normalize_snap_mode(targets[i].snap_mode)
    if SnapSettings.mode_requires_scale(target_mode, SNAP_MODE_SCALE_ONLY, SNAP_MODE_CHORD_SCALE) then
      return true
    end
  end
  return false
end

local function snap_track_targets_internal(targets, chord_notes, state, undo_label)
  reaper.Undo_BeginBlock()

  local track_count = 0
  local take_count = 0
  local processed_total = 0
  local changed_total = 0
  local cut_overlaps = get_cut_overlaps_after_snap_enabled()

  for i = 1, #targets do
    local target = targets[i]
    track_count = track_count + 1

    for_each_midi_take_on_track(target.track, function(take)
      local changed, processed = snap_take_notes(take, chord_notes, state.scale_pcs, target.snap_mode, nil, cut_overlaps)
      take_count = take_count + 1
      processed_total = processed_total + processed
      changed_total = changed_total + changed
    end)
  end

  reaper.Undo_EndBlock(undo_label, -1)
  reaper.UpdateArrange()

  return {
    track_count = track_count,
    take_count = take_count,
    processed_total = processed_total,
    changed_total = changed_total,
  }
end

local function snap_selected_tracks_in_mode_internal(mode)
  local snap_mode = normalize_snap_mode(mode)
  local chord_track, state, err = load_chord_track_from_state()
  if not chord_track then
    return false, err
  end

  local chord_notes = gather_chord_notes(chord_track)
  if #chord_notes == 0 then
    return false, "Chord track has no MIDI notes to define chords."
  end

  local selected_count = reaper.CountSelectedTracks(0)
  if selected_count == 0 then
    return false, "No tracks selected."
  end

  local targets = {}
  for i = 0, selected_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track ~= chord_track then
      targets[#targets + 1] = {
        track = track,
        snap_mode = snap_mode,
      }
    end
  end

  if #targets == 0 then
    return false, "Select target tracks (not the chord track)."
  end

  if targets_need_scale(targets) and set_count(state.scale_pcs) == 0 then
    return false, "No scale is stored yet. Run the sync scale action from the MIDI editor first."
  end

  local result = snap_track_targets_internal(targets, chord_notes, state, "Oz Chord Track: snap selected tracks")
  result.snap_mode = snap_mode
  return true, result
end

local function gather_armed_track_targets(chord_track)
  local targets = {}
  local skipped_off = 0

  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track ~= chord_track then
      local auto_snap_arm_mode = get_auto_snap_arm_mode_for_track(track)
      local snap_mode = auto_snap_arm_mode_to_snap_mode(auto_snap_arm_mode)
      if snap_mode then
        targets[#targets + 1] = {
          track = track,
          snap_mode = snap_mode,
        }
      else
        skipped_off = skipped_off + 1
      end
    end
  end

  return targets, skipped_off
end

local function snap_armed_tracks_in_assigned_modes_internal()
  local chord_track, state, err = load_chord_track_from_state()
  if not chord_track then
    return false, err
  end

  local chord_notes = gather_chord_notes(chord_track)
  if #chord_notes == 0 then
    return false, "Chord track has no MIDI notes to define chords."
  end

  local targets, skipped_off = gather_armed_track_targets(chord_track)
  if #targets == 0 then
    return false, "No tracks are armed for auto snap."
  end

  if targets_need_scale(targets) and set_count(state.scale_pcs) == 0 then
    return false, "No scale is stored yet. Run the sync scale action from the MIDI editor first."
  end

  local result = snap_track_targets_internal(targets, chord_notes, state, "Oz Chord Track: snap armed tracks")
  result.skipped_off = skipped_off
  return true, result
end

local function snap_selected_tracks_by_auto_snap_arm_mode_internal()
  local chord_track, state, err = load_chord_track_from_state()
  if not chord_track then
    return false, err
  end

  local chord_notes = gather_chord_notes(chord_track)
  if #chord_notes == 0 then
    return false, "Chord track has no MIDI notes to define chords."
  end

  local selected_count = reaper.CountSelectedTracks(0)
  if selected_count == 0 then
    return false, "No tracks selected."
  end

  local targets = {}
  local skipped_off = 0

  for i = 0, selected_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track ~= chord_track then
      local auto_snap_arm_mode = get_auto_snap_arm_mode_for_track(track)
      local snap_mode = auto_snap_arm_mode_to_snap_mode(auto_snap_arm_mode)
      if snap_mode then
        targets[#targets + 1] = {
          track = track,
          snap_mode = snap_mode,
        }
      else
        skipped_off = skipped_off + 1
      end
    end
  end

  if #targets == 0 then
    if skipped_off > 0 then
      return false, "Selected tracks are set to Auto-snap Off."
    end
    return false, "Select target tracks (not the chord track)."
  end

  if targets_need_scale(targets) and set_count(state.scale_pcs) == 0 then
    return false, "No scale is stored yet. Run the sync scale action from the MIDI editor first."
  end

  local result = snap_track_targets_internal(targets, chord_notes, state, "Oz Chord Track: snap selected tracks by auto-snap arm")
  result.skipped_off = skipped_off
  return true, result
end

function OzChordTrack.set_selected_tracks_auto_snap_arm_mode(mode)
  local ok, status = set_auto_snap_arm_mode_for_selected_tracks(mode)
  if not ok then
    message(status)
    return
  end
  message(normalize_auto_snap_arm_status_text(status))
end

function OzChordTrack.snap_selected_tracks_by_auto_snap_arm_mode()
  local ok, result = snap_selected_tracks_by_auto_snap_arm_mode_internal()
  if not ok then
    message(result)
    return
  end

  message(format_auto_snap_status(result))
end

function OzChordTrack.arm_selected_tracks_for_auto_snap(mode)
  local normalized = normalize_auto_snap_arm_mode(mode)
  local ok, status = set_auto_snap_arm_mode_for_selected_tracks(normalized)
  if not ok then
    message(status)
    return
  end
  message(normalize_auto_snap_arm_status_text(status))
end

function OzChordTrack.disarm_selected_tracks_auto_snap()
  OzChordTrack.arm_selected_tracks_for_auto_snap(AUTO_SNAP_ARM_MODE_OFF)
end

function OzChordTrack.disarm_all_tracks_auto_snap()
  local ok, status = set_auto_snap_arm_mode_for_all_target_tracks(AUTO_SNAP_ARM_MODE_OFF)
  if not ok then
    message(normalize_auto_snap_arm_status_text(status))
    return
  end

  local _, stop_status = stop_new_note_snap_internal()
  local text = "All target tracks disarmed."
  if stop_status and stop_status ~= "" then
    text = text .. " " .. tostring(stop_status)
  end

  message(text)
end

function OzChordTrack.snap_selected_tracks_now(mode)
  local ok, result = snap_selected_tracks_in_mode_internal(mode)
  if not ok then
    message(result)
    return
  end

  message(format_snap_selected_status(result.snap_mode, result))
end

function OzChordTrack.snap_armed_tracks_now()
  local ok, result = snap_armed_tracks_in_assigned_modes_internal()
  if not ok then
    message(result)
    return
  end

  message(format_snap_armed_status(result))
end

local function one_click_setup_sync_snap_internal(mode)
  local selected_track = reaper.GetSelectedTrack(0, 0)

  local chord_track = selected_track
  local chord_track_name = nil

  if chord_track then
    local ok_set, set_result = set_chord_track(chord_track)
    if not ok_set then
      message(set_result)
      return
    end
    chord_track_name = set_result
  else
    local stored_track = load_chord_track_from_state()
    if not stored_track then
      return false, "No selected chord track and no stored chord track. Select the chord source track and run again."
    end
    chord_track = stored_track
    chord_track_name = get_track_name(chord_track)
  end

  local ok_scale, scale_result, scale_suffix = sync_scale_from_midi_editor_internal()
  if not ok_scale then
    return false, scale_result
  end

  local ok_snap, snap_result = snap_selected_midi_internal(mode or SNAP_MODE_DEFAULT)
  if not ok_snap then
    return false, snap_result
  end

  return true, {
    chord_track_name = chord_track_name,
    scale_result = scale_result,
    scale_suffix = scale_suffix,
    snap_result = snap_result,
  }
end

local function is_live_target_track(track, mode)
  if not track then return false end

  local armed_snap_mode = auto_snap_arm_mode_to_snap_mode(get_auto_snap_arm_mode_for_track(track))
  if not armed_snap_mode then
    return false
  end

  local rec_arm = reaper.GetMediaTrackInfo_Value(track, "I_RECARM") or 0
  if rec_arm >= 1 then
    return true
  end

  if mode == "track_auto_snap_arm_record" then
    return false
  end

  local rec_mon = reaper.GetMediaTrackInfo_Value(track, "I_RECMON") or 0
  return rec_mon > 0
end

local function has_live_target_tracks(chord_track, mode)
  local total_targets = 0
  local eligible_targets = 0

  local track_count = reaper.CountTracks(0)
  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    if track ~= chord_track and is_live_target_track(track, mode) then
      total_targets = total_targets + 1
      if is_auto_snap_arm_live_mode(mode) then
        local snap_mode = auto_snap_arm_mode_to_snap_mode(get_auto_snap_arm_mode_for_track(track))
        if snap_mode then
          eligible_targets = eligible_targets + 1
        end
      else
        eligible_targets = eligible_targets + 1
      end
    end
  end

  return eligible_targets > 0, eligible_targets, total_targets
end

local function count_live_target_takes(chord_track, mode)
  local take_count = 0
  local track_count = reaper.CountTracks(0)
  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    if track ~= chord_track and is_live_target_track(track, mode) then
      local snap_mode = nil
      if is_auto_snap_arm_live_mode(mode) then
        snap_mode = auto_snap_arm_mode_to_snap_mode(get_auto_snap_arm_mode_for_track(track))
      else
        snap_mode = normalize_snap_mode(mode)
      end

      if snap_mode then
        for_each_midi_take_on_track(track, function()
          take_count = take_count + 1
        end)
      end
    end
  end

  return take_count
end

local function track_guid_in_set(track, guid_set)
  if not track or not guid_set then return false end
  local guid = get_track_guid(track)
  if not guid or guid == "" then return false end
  return guid_set[guid] == true
end

local function normalize_live_mode(mode)
  if mode == "track_auto_snap_arm" or mode == "track_auto_snap_arm_record" then
    return mode
  end
  return normalize_snap_mode(mode)
end

local live_state

local function live_mode_to_label(mode)
  if mode == "track_auto_snap_arm" then
    return "Auto-snap Arm"
  end
  if mode == "track_auto_snap_arm_record" then
    return "Auto-snap Arm on record"
  end
  return snap_mode_to_label(normalize_snap_mode(mode))
end

local function resolve_running_live_mode()
  local stored_mode = reaper.GetExtState(LIVE_SECTION, LIVE_MODE_KEY)
  if stored_mode ~= "" then
    return normalize_live_mode(stored_mode)
  end
  if live_state and live_state.mode then
    return normalize_live_mode(live_state.mode)
  end
  return nil
end

local function describe_live_runtime_status()
  local running = reaper.GetExtState(LIVE_SECTION, "RUN_TOKEN") ~= ""
  if not running then
    return {
      running = false,
      active = false,
      running_label = "[ ] Live Engine Running",
      detail = "Inactive: mode off (start live mode).",
      detail_r = 0.80,
      detail_g = 0.80,
      detail_b = 0.84,
    }
  end

  local mode = resolve_running_live_mode() or SNAP_MODE_DEFAULT
  local mode_label = live_mode_to_label(mode)
  local last_suffix = ""
  if live_state and tonumber(live_state.last_pass_time) and live_state.last_pass_time > 0 then
    local age = reaper.time_precise() - live_state.last_pass_time
    if age <= 12 then
      local fallback_tag = (live_state.last_pass_used_fallback == true) and " [fallback]" or ""
      last_suffix = " Last pass: processed " .. tostring(live_state.last_processed or 0) .. ", changed " .. tostring(live_state.last_changed or 0) .. "."
      last_suffix = last_suffix .. fallback_tag
    end
  end

  local chord_track, _, chord_err = load_chord_track_from_state()
  if not chord_track then
    return {
      running = true,
      active = false,
      running_label = "[x] Live Engine Running",
      detail = "Inactive: " .. tostring(chord_err or "chord track missing") .. "",
      detail_r = 0.92,
      detail_g = 0.76,
      detail_b = 0.62,
      mode_label = mode_label,
    }
  end

  local has_targets, eligible_targets, total_targets = has_live_target_tracks(chord_track, mode)
  if not has_targets then
    local detail = nil
    if mode == "track_auto_snap_arm_record" then
      detail = "Inactive: no record-armed live targets."
    elseif is_auto_snap_arm_live_mode(mode) and total_targets > 0 then
      detail = "Inactive: target tracks are Auto-snap Off."
    else
      detail = "Inactive: no live targets (arm or monitor tracks)."
    end

    return {
      running = true,
      active = false,
      running_label = "[x] Live Engine Running",
      detail = detail,
      detail_r = 0.92,
      detail_g = 0.76,
      detail_b = 0.62,
      mode_label = mode_label,
    }
  end

  local take_count = count_live_target_takes(chord_track, mode)
  if take_count == 0 then
    return {
      running = true,
      active = false,
      running_label = "[x] Live Engine Running",
      detail = "Inactive: no MIDI takes on live targets yet (first take appears after recording starts/stops)." .. last_suffix,
      detail_r = 0.92,
      detail_g = 0.76,
      detail_b = 0.62,
      mode_label = mode_label,
    }
  end

  local play_state = reaper.GetPlayState()
  local is_playing = (play_state & 1) == 1
  local is_recording = (play_state & 4) == 4

  if mode == "track_auto_snap_arm_record" and not is_recording then
    if live_state and live_state.pending_record_flush then
      return {
        running = true,
        active = false,
        running_label = "[x] Live Engine Running",
        detail = "Inactive: finalizing post-record snap..." .. last_suffix,
        detail_r = 0.92,
        detail_g = 0.76,
        detail_b = 0.62,
        mode_label = mode_label,
      }
    end

    return {
      running = true,
      active = false,
      running_label = "[x] Live Engine Running",
      detail = "Inactive: waiting for recording." .. last_suffix,
      detail_r = 0.92,
      detail_g = 0.76,
      detail_b = 0.62,
      mode_label = mode_label,
    }
  end

  if not (is_playing or is_recording) then
    return {
      running = true,
      active = false,
      running_label = "[x] Live Engine Running",
      detail = "Inactive: waiting for playback/record.",
      detail_r = 0.92,
      detail_g = 0.76,
      detail_b = 0.62,
      mode_label = mode_label,
    }
  end

  return {
    running = true,
    active = true,
    running_label = "[x] Live Engine Running",
    detail = "Active: " .. tostring(eligible_targets or 0) .. " target track(s), " .. tostring(take_count) .. " MIDI take(s).",
    detail_r = 0.72,
    detail_g = 0.90,
    detail_b = 0.72,
    mode_label = mode_label,
  }
end

function OzChordTrack.one_click_setup_sync_snap(mode)
  local ok, result = one_click_setup_sync_snap_internal(mode)
  if not ok then
    message(result)
    return
  end

  message(format_one_click_status(result))
end

local function gather_live_takes(chord_track, mode, include_track_guids, include_track_modes)
  local takes = {}
  local target_guids = {}
  local target_modes = {}
  local track_count = reaper.CountTracks(0)

  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    local track_guid = get_track_guid(track)
    local include_track = false
    if track ~= chord_track then
      if is_live_target_track(track, mode) then
        include_track = true
      elseif mode == "track_auto_snap_arm_record" and track_guid_in_set(track, include_track_guids) then
        include_track = true
      end
    end

    if include_track then
      local snap_mode = nil
      if is_auto_snap_arm_live_mode(mode) then
        snap_mode = auto_snap_arm_mode_to_snap_mode(get_auto_snap_arm_mode_for_track(track))
        if (not snap_mode) and mode == "track_auto_snap_arm_record" and track_guid and include_track_modes then
          snap_mode = normalize_snap_mode(include_track_modes[track_guid])
        end
      else
        snap_mode = normalize_snap_mode(mode)
      end

      if snap_mode then
        if track_guid and track_guid ~= "" then
          target_guids[track_guid] = true
          target_modes[track_guid] = snap_mode
        end

        for_each_midi_take_on_track(track, function(take)
          takes[#takes + 1] = {
            take = take,
            snap_mode = snap_mode,
          }
        end)
      end
    end
  end

  return takes, target_guids, target_modes
end

local function armed_tracks_need_scale(chord_track, mode)
  local track_count = reaper.CountTracks(0)
  for track_index = 0, track_count - 1 do
    local track = reaper.GetTrack(0, track_index)
    if track ~= chord_track and is_live_target_track(track, mode) then
      local auto_snap_arm_mode = get_auto_snap_arm_mode_for_track(track)
      local snap_mode = auto_snap_arm_mode_to_snap_mode(auto_snap_arm_mode)
      if snap_mode and SnapSettings.mode_requires_scale(snap_mode, SNAP_MODE_SCALE_ONLY, SNAP_MODE_CHORD_SCALE) then
        return true
      end
    end
  end

  return false
end

local function take_id(take)
  local _, guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
  if guid and guid ~= "" then return guid end
  return tostring(take)
end

live_state = {
  token = nil,
  mode = nil,
  take_note_counts = {},
  chord_notes = {},
  last_refresh = 0,
  last_play_position = nil,
  was_recording = false,
  record_target_guids = {},
  record_target_modes = {},
  pending_record_flush = false,
  record_stop_time = 0,
  last_processed = 0,
  last_changed = 0,
  last_pass_time = 0,
  last_pass_used_fallback = false,
}

local function live_loop()
  local running_token = reaper.GetExtState(LIVE_SECTION, "RUN_TOKEN")
  if running_token == "" or running_token ~= live_state.token then
    return
  end

  local play_state = reaper.GetPlayState()
  local is_playing = (play_state & 1) == 1
  local is_recording = (play_state & 4) == 4
  local was_recording = live_state.was_recording == true
  local should_flush_after_record = false

  if is_recording then
    live_state.was_recording = true
    live_state.pending_record_flush = false
  end

  if live_state.mode == "track_auto_snap_arm_record" and (not is_recording) and was_recording and (not live_state.pending_record_flush) then
    live_state.pending_record_flush = true
    live_state.record_stop_time = reaper.time_precise()
  end

  if live_state.mode == "track_auto_snap_arm_record" and live_state.pending_record_flush then
    should_flush_after_record = true
  end

  if live_state.mode == "track_auto_snap_arm_record" then
    if not is_recording and not should_flush_after_record then
      live_state.was_recording = false
      live_state.record_target_guids = {}
      live_state.record_target_modes = {}
      live_state.pending_record_flush = false
      live_state.record_stop_time = 0
      reaper.defer(live_loop)
      return
    end
  elseif not (is_playing or is_recording) then
    live_state.was_recording = false
    reaper.defer(live_loop)
    return
  end

  local chord_track, state = load_chord_track_from_state()
  if not chord_track then
    reaper.defer(live_loop)
    return
  end

  local now = reaper.time_precise()
  if now - live_state.last_refresh > 0.35 then
    live_state.chord_notes = gather_chord_notes(chord_track)
    live_state.last_refresh = now
  end

  if #live_state.chord_notes == 0 then
    reaper.defer(live_loop)
    return
  end

  local play_position = nil
  if reaper.GetPlayPosition2Ex then
    play_position = reaper.GetPlayPosition2Ex(0)
  elseif reaper.GetPlayPosition then
    play_position = reaper.GetPlayPosition()
  end

  if tonumber(play_position) and tonumber(live_state.last_play_position) then
    if play_position < (live_state.last_play_position - 0.05) then
      live_state.take_note_counts = {}
    end
  end
  live_state.last_play_position = play_position

  local include_track_guids = nil
  local include_track_modes = nil
  if should_flush_after_record then
    include_track_guids = live_state.record_target_guids
    include_track_modes = live_state.record_target_modes
  end

  local take_entries, target_guids, target_modes = gather_live_takes(chord_track, live_state.mode, include_track_guids, include_track_modes)
  if is_recording and live_state.mode == "track_auto_snap_arm_record" then
    for guid in pairs(target_guids or {}) do
      live_state.record_target_guids[guid] = true
    end
    for guid, snap_mode in pairs(target_modes or {}) do
      live_state.record_target_modes[guid] = snap_mode
    end
  end

  local changed_total = 0
  local processed_total = 0
  local used_fallback = false
  local seen_take_ids = {}
  for i = 1, #take_entries do
    local take = take_entries[i].take
    local snap_mode = take_entries[i].snap_mode
    local id = take_id(take)
    seen_take_ids[id] = true

    local last_count = tonumber(live_state.take_note_counts[id]) or 0
    local from_index = should_flush_after_record and 0 or last_count
    if (not should_flush_after_record) and is_recording and from_index > 24 then
      from_index = from_index - 24
    end
    if from_index < 0 then
      from_index = 0
    end

    local changed, processed, current_count = snap_take_notes(take, live_state.chord_notes, state.scale_pcs, snap_mode, from_index, false)

    if is_recording and (not should_flush_after_record) and current_count > last_count and last_count > 0 and from_index > 0 then
      local rescue_changed, rescue_processed = snap_take_notes(take, live_state.chord_notes, state.scale_pcs, snap_mode, 0, false)
      changed = changed + (tonumber(rescue_changed) or 0)
      processed_total = processed_total + (tonumber(rescue_processed) or 0)
    end

    live_state.take_note_counts[id] = current_count
    changed_total = changed_total + (tonumber(changed) or 0)
    processed_total = processed_total + (tonumber(processed) or 0)

    if changed > 0 then
      reaper.UpdateItemInProject(reaper.GetMediaItemTake_Item(take))
    end
  end

  if should_flush_after_record and processed_total == 0 then
    used_fallback = true
    for guid, snap_mode in pairs(live_state.record_target_modes or {}) do
      local track = find_track_by_guid(guid)
      if track and track ~= chord_track then
        for_each_midi_take_on_track(track, function(take)
          local changed, processed = snap_take_notes(take, live_state.chord_notes, state.scale_pcs, snap_mode, 0, false)
          changed_total = changed_total + (tonumber(changed) or 0)
          processed_total = processed_total + (tonumber(processed) or 0)
          if (tonumber(changed) or 0) > 0 then
            reaper.UpdateItemInProject(reaper.GetMediaItemTake_Item(take))
          end
        end)
      end
    end
  end

  for id in pairs(live_state.take_note_counts) do
    if not seen_take_ids[id] then
      live_state.take_note_counts[id] = nil
    end
  end

  if #take_entries > 0 or should_flush_after_record then
    live_state.last_processed = processed_total
    live_state.last_changed = changed_total
    live_state.last_pass_time = reaper.time_precise()
    live_state.last_pass_used_fallback = used_fallback
  end

  if should_flush_after_record then
    local flush_age = reaper.time_precise() - (tonumber(live_state.record_stop_time) or 0)
    local keep_waiting = (#take_entries == 0) and processed_total == 0 and flush_age < 6.0

    if not keep_waiting then
      live_state.pending_record_flush = false
      live_state.record_stop_time = 0
      live_state.was_recording = false
      live_state.record_target_guids = {}
      live_state.record_target_modes = {}
    end
  end

  reaper.defer(live_loop)
end

local function start_live_snap_internal(mode)
  local chord_track, state, err = load_chord_track_from_state()
  if not chord_track then
    return false, err
  end

  local live_mode = mode or SNAP_MODE_DEFAULT

  local has_targets = has_live_target_tracks(chord_track, live_mode)
  if not has_targets then
    if live_mode == "track_auto_snap_arm_record" then
      return false, "No live targets found. Record-arm target tracks and set their Auto-snap Arm mode to Chords, Scales, or Chords + Scales."
    end

    if is_auto_snap_arm_live_mode(live_mode) then
      return false, "No live targets found. Arm or monitor target tracks and set their Auto-snap Arm mode to Chords, Scales, or Chords + Scales."
    end

    return false, "No live targets found. Arm or monitor target MIDI tracks (not the chord track)."
  end

  if is_auto_snap_arm_live_mode(live_mode) then
    if set_count(state.scale_pcs) == 0 and armed_tracks_need_scale(chord_track, live_mode) then
      return false, "No scale is stored yet. Sync scale from MIDI editor first, or set armed tracks to Auto-snap Arm Chords only."
    end
  else
    local normalized_mode = normalize_snap_mode(live_mode)
    if SnapSettings.mode_requires_scale(normalized_mode, SNAP_MODE_SCALE_ONLY, SNAP_MODE_CHORD_SCALE) and set_count(state.scale_pcs) == 0 then
      return false, "No scale is stored yet. Run the sync scale action from the MIDI editor first."
    end
    live_mode = normalized_mode
  end

  live_state.token = tostring(reaper.time_precise())
  live_state.mode = live_mode
  live_state.take_note_counts = {}
  live_state.chord_notes = gather_chord_notes(chord_track)
  live_state.last_refresh = 0
  live_state.last_play_position = nil
  live_state.was_recording = false
  live_state.record_target_guids = {}
  live_state.record_target_modes = {}
  live_state.pending_record_flush = false
  live_state.record_stop_time = 0
  live_state.last_processed = 0
  live_state.last_changed = 0
  live_state.last_pass_time = 0
  live_state.last_pass_used_fallback = false

  reaper.SetExtState(LIVE_SECTION, "RUN_TOKEN", live_state.token, false)
  reaper.SetExtState(LIVE_SECTION, LIVE_MODE_KEY, tostring(live_mode or ""), false)

  reaper.atexit(function()
    local current_token = reaper.GetExtState(LIVE_SECTION, "RUN_TOKEN")
    if current_token == live_state.token then
      reaper.SetExtState(LIVE_SECTION, "RUN_TOKEN", "", false)
      reaper.SetExtState(LIVE_SECTION, LIVE_MODE_KEY, "", false)
    end
  end)

  local status = nil
  if live_mode == "track_auto_snap_arm" then
    status = "Live auto-snap arm mode started (experimental). Armed tracks use their Auto-snap Arm modes. Run the stop action to end it."
  elseif live_mode == "track_auto_snap_arm_record" then
    status = "Auto snap on record started (experimental). Only record-armed tracks use their Auto-snap Arm mode."
  else
    status = "Live snap started (experimental). Arm or monitor target MIDI tracks and play/record. Run the stop action to end it."
  end

  live_loop()

  return true, status
end

function OzChordTrack.start_live_snap(mode)
  local ok, status = start_live_snap_internal(mode)
  message(status)
  if not ok then
    return
  end
end

function OzChordTrack.start_live_snap_by_auto_snap_arm_mode()
  OzChordTrack.start_live_snap("track_auto_snap_arm")
end

function OzChordTrack.start_auto_snap_armed_tracks_on_record()
  OzChordTrack.start_live_snap("track_auto_snap_arm_record")
end

local function stop_live_snap_internal()
  reaper.SetExtState(LIVE_SECTION, "RUN_TOKEN", "", false)
  reaper.SetExtState(LIVE_SECTION, LIVE_MODE_KEY, "", false)
  return true, "Live snap stop signal sent."
end

local function point_in_rect(px, py, x, y, w, h)
  return px >= x and px <= (x + w) and py >= y and py <= (y + h)
end

local function draw_button(x, y, w, h, label, click)
  local mx, my = gfx.mouse_x, gfx.mouse_y
  local hovered = point_in_rect(mx, my, x, y, w, h)

  if hovered then
    gfx.set(0.28, 0.28, 0.30, 1)
  else
    gfx.set(0.21, 0.21, 0.23, 1)
  end
  gfx.rect(x, y, w, h, 1)

  gfx.set(0.10, 0.10, 0.10, 1)
  gfx.rect(x, y, w, h, 0)

  gfx.set(0.92, 0.92, 0.92, 1)
  gfx.x = x + 10
  gfx.y = y + 5
  gfx.drawstr(label)

  return hovered and click
end

local function draw_icon_button(x, y, size, label, click)
  local mx, my = gfx.mouse_x, gfx.mouse_y
  local hovered = point_in_rect(mx, my, x, y, size, size)

  if hovered then
    gfx.set(0.32, 0.32, 0.35, 1)
  else
    gfx.set(0.22, 0.22, 0.25, 1)
  end
  gfx.rect(x, y, size, size, 1)

  gfx.set(0.11, 0.11, 0.12, 1)
  gfx.rect(x, y, size, size, 0)

  gfx.setfont(1, "Segoe UI", math.max(10, size - 16))
  gfx.set(0.94, 0.94, 0.96, 1)
  local text_w, text_h = gfx.measurestr(label)
  gfx.x = x + math.max(2, (size - text_w) * 0.5)
  gfx.y = y + math.max(2, (size - text_h) * 0.5)
  gfx.drawstr(label)

  return hovered and click, hovered
end

local function get_core_script_directory()
  local source = debug.getinfo(1, "S").source or ""
  source = source:gsub("^@", "")
  local directory = source:match("^(.*[\\/])") or ""

  local use_backslash = directory:find("\\", 1, true) ~= nil
  local normalized = directory:gsub("\\", "/")
  normalized = normalized:gsub("/+$", "") .. "/"

  if normalized:sub(-6) == "/libs/" then
    normalized = normalized:sub(1, #normalized - 5)
  end

  if use_backslash then
    return normalized:gsub("/", "\\")
  end

  return normalized
end

local function run_script_action_by_file_name(file_name)
  local script_path = get_core_script_directory() .. tostring(file_name or "")
  local chunk, load_err = loadfile(script_path)
  if type(chunk) ~= "function" then
    return false, "Could not load script: " .. tostring(file_name or "") .. " (" .. tostring(load_err or "unknown error") .. ")"
  end

  local ok, runtime_err = pcall(chunk)
  if not ok then
    return false, "Could not run script: " .. tostring(file_name or "") .. " (" .. tostring(runtime_err or "unknown error") .. ")"
  end

  return true, nil
end

local function get_input_manager_runtime_status()
  local running = reaper.GetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_RUN_TOKEN_KEY) ~= ""
  local status_text = reaper.GetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_STATUS_KEY)
  if not status_text or status_text == "" then
    status_text = running and "running" or "stopped"
  end
  return running, status_text
end

local function find_input_snap_jsfx_file_path()
  if not reaper.GetResourcePath or not reaper.EnumerateFiles or not reaper.EnumerateSubdirectories then
    return nil
  end

  local effects_root = tostring(reaper.GetResourcePath() or "") .. "/Effects"
  local found_path = nil

  local function scan_dir(abs_dir)
    if found_path then return end

    local file_index = 0
    while true do
      local file_name = reaper.EnumerateFiles(abs_dir, file_index)
      if not file_name then break end

      local normalized_file = tostring(file_name):lower()
      if normalized_file:find("oz chord track input snap", 1, true) then
        found_path = abs_dir .. "/" .. tostring(file_name)
        return
      end

      file_index = file_index + 1
    end

    local sub_index = 0
    while not found_path do
      local sub_name = reaper.EnumerateSubdirectories(abs_dir, sub_index)
      if not sub_name then break end
      scan_dir(abs_dir .. "/" .. tostring(sub_name))
      sub_index = sub_index + 1
    end
  end

  scan_dir(effects_root)
  return found_path
end

local function has_input_snap_jsfx_installed()
  return find_input_snap_jsfx_file_path() ~= nil
end

local function is_legacy_input_snap_jsfx(path)
  local handle = io.open(path, "rb")
  if not handle then return false end
  local content = handle:read("*a") or ""
  handle:close()
  return content:find("gmem_attach", 1, true) ~= nil
end

local function install_input_snap_jsfx()
  if not reaper.GetResourcePath then
    return false, "Could not resolve REAPER resource path for JSFX install."
  end

  local resource_path = tostring(reaper.GetResourcePath() or "")
  if resource_path == "" then
    return false, "Could not resolve REAPER resource path for JSFX install."
  end

  local effects_root = resource_path .. "/Effects"
  local target_rel = INPUT_SNAP_JSFX_RELATIVE_PATH:gsub("\\", "/")
  local target_abs = effects_root .. "/" .. target_rel
  local target_dir = target_abs:match("^(.*)[/\\][^/\\]+$")

  if target_dir and reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(target_dir, 0)
  end

  local handle, write_err = io.open(target_abs, "wb")
  if not handle then
    return false, "Could not write Input Snap JSFX: " .. tostring(write_err or target_abs)
  end

  handle:write(INPUT_SNAP_JSFX_SOURCE)
  handle:close()

  if has_input_snap_jsfx_installed() then
    return true, "Installed Input snap JSFX at REAPER/Effects/" .. target_rel
  end

  return false, "Input snap JSFX install was attempted but REAPER could not detect it yet."
end

local function ensure_input_snap_jsfx_installed()
  local existing = find_input_snap_jsfx_file_path()
  if existing then
    if is_legacy_input_snap_jsfx(existing) then
      return install_input_snap_jsfx()
    end
    return true, nil
  end

  return install_input_snap_jsfx()
end

local function start_new_note_snap_internal(pipeline_mode, snap_mode)
  local selected_pipeline = nil
  if pipeline_mode == nil then
    selected_pipeline = get_new_note_snap_pipeline_mode()
  else
    selected_pipeline = set_new_note_snap_pipeline_mode(pipeline_mode)
  end

  local selected_snap_mode = nil
  if snap_mode == nil then
    selected_snap_mode = get_new_note_snap_mode()
  else
    selected_snap_mode = set_new_note_snap_mode(snap_mode)
  end

  if selected_pipeline == NEW_NOTE_SNAP_PIPELINE_PRE then
    local ok_jsfx, jsfx_status = ensure_input_snap_jsfx_installed()
    if not ok_jsfx then
      return false, jsfx_status or "Input snap JSFX not found and auto-install failed."
    end

    set_input_manager_snap_mode_override(selected_snap_mode)
    local ok_manager, manager_err = run_script_action_by_file_name(INPUT_MANAGER_START_SCRIPT)
    if not ok_manager then
      return false, manager_err
    end

    stop_live_snap_internal()
    return true, "New-note snap started: Pre (" .. snap_mode_to_label(selected_snap_mode) .. ")."
  end

  clear_input_manager_snap_mode_override()
  run_script_action_by_file_name(INPUT_MANAGER_STOP_SCRIPT)

  local ok_live, live_status = start_live_snap_internal(selected_snap_mode)
  if not ok_live then
    return false, live_status
  end

  return true, "New-note snap started: Post (" .. snap_mode_to_label(selected_snap_mode) .. ")."
end

local function stop_new_note_snap_internal()
  clear_input_manager_snap_mode_override()
  stop_live_snap_internal()

  local ok_manager, manager_err = run_script_action_by_file_name(INPUT_MANAGER_STOP_SCRIPT)
  if ok_manager then
    return true, "New-note snap stop signal sent."
  end

  return true, "New-note snap stop signal sent. " .. tostring(manager_err or "")
end

function OzChordTrack.start_new_note_snap(pipeline_mode, snap_mode)
  local ok, status = start_new_note_snap_internal(pipeline_mode, snap_mode)
  message(status)
  if not ok then
    return
  end
end

function OzChordTrack.stop_new_note_snap()
  local _, status = stop_new_note_snap_internal()
  message(status)
end

function OzChordTrack.ensure_input_snap_jsfx()
  local ok, status = ensure_input_snap_jsfx_installed()
  if ok then
    message(status or "Input snap JSFX is installed.")
  else
    message(status or "Could not ensure Input snap JSFX is installed.")
  end
  return ok, status
end

function OzChordTrack.run_dockable_panel()
  local dock_state = tonumber(reaper.GetExtState(PANEL_SECTION, "DOCK_STATE")) or 0
  if dock_state < 0 then dock_state = 0 end
  local stored_block_theme = normalize_chord_block_theme(reaper.GetExtState(PANEL_SECTION, "BLOCK_THEME"))
  local stored_compact_mode = reaper.GetExtState(PANEL_SECTION, "COMPACT_MODE") == "1"
  local stored_cut_overlaps = get_cut_overlaps_after_snap_enabled()
  local stored_timeline_calibration = get_timeline_calibration_px()

  gfx.init("Chord Track", 680, 980, dock_state, 150, 120)

  local ui_state = {
    prev_lmb = false,
    prev_rmb = false,
    status_text = "",
    status_expires = 0,
    last_dock_state = dock_state,
    last_project_state = -1,
    last_scale_signature = "",
    chord_blocks = {},
    block_theme = stored_block_theme,
    compact_mode = stored_compact_mode,
    cut_overlaps_after_snap = stored_cut_overlaps,
    allow_snap_inversions = SnapSettings.get_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, false),
    timeline_calibration_px = stored_timeline_calibration,
    new_note_snap_pipeline_mode = get_new_note_snap_pipeline_mode(),
    new_note_snap_mode = get_new_note_snap_mode(),
    active_tab = "home",
    tab_scroll = { home = 0, snap = 0, theme = 0 },
    last_block_click_id = nil,
    last_block_click_time = 0,
  }

  local function set_status(text)
    ui_state.status_text = text or ""
    ui_state.status_expires = reaper.time_precise() + 6.0
  end

  local function launch_compact_popout_window(tab_id)
    local normalized_tab = normalize_popout_tab_id(tab_id)
    reaper.SetExtState(PANEL_SECTION, POPOUT_INITIAL_TAB_KEY, normalized_tab, false)

    local script_path = get_core_script_directory() .. "actions/Oz Chord Track - Open compact popout panel.lua"
    if not reaper.AddRemoveReaScript then
      return false, "Could not open popout window automatically. Run the compact popout action manually."
    end

    local command_id = reaper.AddRemoveReaScript(true, 0, script_path, true)
    if type(command_id) ~= "number" or command_id <= 0 then
      return false, "Could not load compact popout action. Import 'actions/Oz Chord Track - Open compact popout panel.lua' in Actions."
    end

    reaper.Main_OnCommand(command_id, 0)
    return true, "Opened " .. normalized_tab:gsub("^%l", string.upper) .. " tools window."
  end

  local function apply_block_theme_menu(x, y)
    gfx.x = x
    gfx.y = y
    local menu_result = gfx.showmenu("Auto|Blue|Purple|Neutral")
    if menu_result > 0 then
      local theme = CHORD_BLOCK_THEME_ORDER[menu_result]
      ui_state.block_theme = normalize_chord_block_theme(theme)
      reaper.SetExtState(PANEL_SECTION, "BLOCK_THEME", ui_state.block_theme, true)
      set_status(format_theme_set_status(ui_state.block_theme))
    end
  end

  local function apply_timeline_calibration_menu(x, y)
    local selected_px = show_timeline_calibration_menu(x, y, ui_state.timeline_calibration_px)
    if selected_px == nil then
      return
    end

    ui_state.timeline_calibration_px = set_timeline_calibration_px(selected_px)
    set_status(format_timeline_calibration_status(ui_state.timeline_calibration_px))
  end

  local function apply_snap_selected_midi_menu(x, y)
    gfx.x = x
    gfx.y = y
    local menu_result = gfx.showmenu("Chords + Scales|Chords Only|Scales Only|Melodic Flow")
    if menu_result <= 0 then
      return
    end

    local mode = SNAP_MODE_CHORD_SCALE
    if menu_result == 2 then
      mode = SNAP_MODE_CHORD_ONLY
    elseif menu_result == 3 then
      mode = SNAP_MODE_SCALE_ONLY
    elseif menu_result == 4 then
      mode = SNAP_MODE_MELODIC_FLOW
    end

    local ok, result = snap_selected_midi_internal(mode)
    if not ok then
      set_status(result)
      return
    end

    set_status(format_snap_midi_status(mode, result))
  end

  local function apply_one_click_menu(x, y)
    gfx.x = x
    gfx.y = y
    local menu_result = gfx.showmenu("Chords + Scales|Chords Only|Scales Only|Melodic Flow")
    if menu_result <= 0 then
      return
    end

    local mode = SNAP_MODE_CHORD_SCALE
    if menu_result == 2 then
      mode = SNAP_MODE_CHORD_ONLY
    elseif menu_result == 3 then
      mode = SNAP_MODE_SCALE_ONLY
    elseif menu_result == 4 then
      mode = SNAP_MODE_MELODIC_FLOW
    end

    local ok, result = one_click_setup_sync_snap_internal(mode)
    if not ok then
      set_status(result)
      return
    end

    set_status(format_one_click_status(result))
  end

  local function run_set_selected_as_chord_track_action()
    local track = reaper.GetSelectedTrack(0, 0)
    local ok, result = set_chord_track(track)
    if ok then
      ui_state.last_project_state = -1
      set_status("Chord track set to: " .. result)
    else
      set_status(result)
    end
  end

  local function run_sync_scale_action()
    local ok, result, suffix = sync_scale_from_midi_editor_internal()
    if ok then
      set_status("Captured: " .. result.root_name .. " - " .. result.scale_name .. (suffix or ""))
    else
      set_status(result)
    end
  end

  local function run_snap_selected_tracks_by_arm_action()
    local ok, result = snap_selected_tracks_by_auto_snap_arm_mode_internal()
    if ok then
      set_status(format_auto_snap_status(result))
    else
      set_status(result)
    end
  end

  local function run_snap_armed_tracks_action()
    local ok, result = snap_armed_tracks_in_assigned_modes_internal()
    if ok then
      set_status(format_snap_armed_status(result))
    else
      set_status(result)
    end
  end

  local function run_snap_selected_tracks_now_action(mode)
    local snap_mode = normalize_snap_mode(mode)
    local ok, result = snap_selected_tracks_in_mode_internal(snap_mode)
    if ok then
      set_status(format_snap_selected_status(snap_mode, result))
    else
      set_status(result)
    end
  end

  local function run_ensure_input_snap_jsfx_action()
    local ok, status = ensure_input_snap_jsfx_installed()
    if ok then
      set_status(status or "Input snap JSFX is installed.")
    else
      set_status(status or "Could not ensure Input snap JSFX is installed.")
    end
  end

  local function run_repair_input_snap_fx_action()
    local previous_override = reaper.GetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY)

    local ok_stop, stop_err = run_script_action_by_file_name(INPUT_MANAGER_STOP_SCRIPT)
    if not ok_stop then
      set_status(stop_err or "Could not stop input snap manager for repair.")
      return
    end

    if previous_override and previous_override ~= "" then
      reaper.SetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY, previous_override, false)
    end

    local ok_start, start_err = run_script_action_by_file_name(INPUT_MANAGER_START_SCRIPT)
    if ok_start then
      set_status("Repaired input snap FX instances.")
    else
      set_status(start_err or "Could not restart input snap manager after repair.")
    end
  end

  local function sync_new_note_snap_runtime_for_armed_targets()
    local armed_target_count = count_follow_armed_target_tracks()
    if armed_target_count <= 0 then
      local ok, status = stop_new_note_snap_internal()
      if ok then
        reaper.UpdateArrange()
      end
      return ok, status
    end

    local pipeline_mode = normalize_new_note_snap_pipeline_mode(ui_state.new_note_snap_pipeline_mode)

    if pipeline_mode == NEW_NOTE_SNAP_PIPELINE_PRE then
      clear_input_manager_snap_mode_override()

      local manager_running = reaper.GetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_RUN_TOKEN_KEY) ~= ""
      local manager_hint = "Input manager already running."
      if not manager_running then
        local ok_manager, manager_err = run_script_action_by_file_name(INPUT_MANAGER_START_SCRIPT)
        if not ok_manager then
          return false, manager_err
        end
        manager_hint = "Input manager started."
      end

      stop_live_snap_internal()
      reaper.UpdateArrange()
      local status_prefix = manager_running and "New-note snap synced: Pre (per-track Follow modes). " or "New-note snap started: Pre (per-track Follow modes). "
      return true, status_prefix .. manager_hint, manager_running and "already_running" or "started"
    end

    clear_input_manager_snap_mode_override()
    run_script_action_by_file_name(INPUT_MANAGER_STOP_SCRIPT)

    local ok_live, live_status = start_live_snap_internal(ui_state.new_note_snap_mode)
    if ok_live then
      reaper.UpdateArrange()
    end
    return ok_live, live_status
  end

  local function apply_selected_tracks_follow_mode_from_snap_mode(snap_mode, infos)
    local normalized_snap_mode = normalize_snap_mode(snap_mode)
    local auto_mode = snap_mode_to_auto_snap_arm_mode(normalized_snap_mode)
    if not auto_mode then
      set_status("Invalid snap method.")
      return false
    end

    ui_state.new_note_snap_mode = set_new_note_snap_mode_runtime(normalized_snap_mode, ui_state.new_note_snap_pipeline_mode)

    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      set_status("No target tracks selected.")
      return false
    end

    if arming.all_disarmed then
      set_status("Snap method set to " .. snap_mode_to_label(normalized_snap_mode) .. ". Arm selected tracks to start snapping.")
      return true
    end

    local updated = 0
    for i = 1, #(infos or {}) do
      local info = infos[i]
      if info and not info.is_chord_track then
        local current_mode = normalize_auto_snap_arm_mode(get_auto_snap_arm_mode_for_track(info.track))
        if current_mode ~= AUTO_SNAP_ARM_MODE_OFF then
          if set_auto_snap_arm_mode_for_track(info.track, auto_mode) then
            updated = updated + 1
          end
        end
      end
    end

    if updated <= 0 then
      set_status("No armed selected tracks were updated.")
      return false
    end

    local ok_sync, sync_status, sync_detail = sync_new_note_snap_runtime_for_armed_targets()
    if not ok_sync then
      set_status(sync_status or "Could not apply snap method to running snap engine.")
      return false
    end

    local status_text = "Set snap method to " .. snap_mode_to_label(normalized_snap_mode) .. " for " .. tostring(updated) .. " armed selected track(s)."
    if sync_detail == "already_running" then
      status_text = status_text .. " Input manager already running."
    elseif sync_detail == "started" then
      status_text = status_text .. " Input manager started."
    end

    set_status(status_text)
    return true
  end

  local function disarm_all_target_tracks_follow()
    local ok, status = set_auto_snap_arm_mode_for_all_target_tracks(AUTO_SNAP_ARM_MODE_OFF)
    if not ok then
      set_status(normalize_auto_snap_arm_status_text(status))
      return
    end

    local ok_sync, sync_status = sync_new_note_snap_runtime_for_armed_targets()
    if not ok_sync and sync_status and sync_status ~= "" then
      set_status(sync_status)
      return
    end

    set_status("All target tracks disarmed.")
  end

  local function toggle_selected_tracks_follow_arming(infos)
    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      set_status("No target tracks selected.")
      return
    end

    if arming.all_armed then
      local ok, status = set_auto_snap_arm_mode_for_selected_tracks(AUTO_SNAP_ARM_MODE_OFF)
      if not ok then
        set_status(normalize_auto_snap_arm_status_text(status))
        return
      end

      if count_follow_armed_target_tracks() <= 0 then
        local ok_sync, sync_status = sync_new_note_snap_runtime_for_armed_targets()
        if not ok_sync and sync_status and sync_status ~= "" then
          set_status(sync_status)
          return
        end
      else
        reaper.UpdateArrange()
      end

      set_status("Selected tracks disarmed.")
      return
    end

    local auto_mode = snap_mode_to_auto_snap_arm_mode(ui_state.new_note_snap_mode) or AUTO_SNAP_ARM_MODE_CHORDS_SCALES
    local ok, status = set_auto_snap_arm_mode_for_selected_tracks(auto_mode)
    if not ok then
      set_status(normalize_auto_snap_arm_status_text(status))
      return
    end

    local ok_sync, sync_status = sync_new_note_snap_runtime_for_armed_targets()
    if not ok_sync then
      set_status(sync_status or "Could not start new-note snap for armed selected tracks.")
      return
    end

    set_status("Selected tracks armed (" .. snap_mode_to_label(ui_state.new_note_snap_mode) .. ").")
  end

  local function arming_toggle_label_for_selected_tracks(infos)
    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      return "[ ] Arm selected tracks (ready to snap)"
    end
    if arming.all_armed then
      return "[x] Arm selected tracks (ready to snap)"
    end
    if arming.mixed then
      return "[-] Arm selected tracks (ready to snap)"
    end
    return "[ ] Arm selected tracks (ready to snap)"
  end

  local function arming_status_text_for_selected_tracks(infos)
    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      return "No target tracks selected"
    end
    if arming.all_armed then
      return "Armed"
    end
    if arming.mixed then
      return "Mixed"
    end
    return "Disarmed"
  end

  local function apply_new_note_pipeline_mode(mode)
    ui_state.new_note_snap_pipeline_mode = set_new_note_snap_pipeline_mode(mode)
    if count_follow_armed_target_tracks() > 0 then
      local _, status = sync_new_note_snap_runtime_for_armed_targets()
      if status and status ~= "" then
        set_status(status)
      end
    end
  end

  local function maybe_refresh_chord_blocks(chord_track, current_state)
    local project_state = reaper.GetProjectStateChangeCount(0)
    local scale_signature = tostring(current_state.root_pc or "") .. "|" .. set_to_csv(current_state.scale_pcs or {})

    if not chord_track then
      ui_state.chord_blocks = {}
      ui_state.last_project_state = project_state
      ui_state.last_scale_signature = scale_signature
      return
    end

    if project_state ~= ui_state.last_project_state or scale_signature ~= ui_state.last_scale_signature then
      ui_state.chord_blocks = collect_chord_blocks(chord_track, current_state)
      ui_state.last_project_state = project_state
      ui_state.last_scale_signature = scale_signature
    end
  end

  local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
  end

  local function desaturate_color(r, g, b, amount)
    local gray = (r * 0.299) + (g * 0.587) + (b * 0.114)
    local mix = clamp01(amount)
    return
      (r * (1 - mix)) + (gray * mix),
      (g * (1 - mix)) + (gray * mix),
      (b * (1 - mix)) + (gray * mix)
  end

  local function block_style_for_quality(quality, hovered, theme)
    local body_r, body_g, body_b = 0.16, 0.30, 0.45
    local accent_r, accent_g, accent_b = 0.35, 0.62, 0.90
    local badge_r, badge_g, badge_b = 0.25, 0.42, 0.62

    if quality == "minor" then
      body_r, body_g, body_b = 0.24, 0.18, 0.44
      accent_r, accent_g, accent_b = 0.62, 0.50, 0.94
      badge_r, badge_g, badge_b = 0.36, 0.29, 0.62
    elseif quality == "dominant" then
      body_r, body_g, body_b = 0.35, 0.24, 0.12
      accent_r, accent_g, accent_b = 0.96, 0.68, 0.20
      badge_r, badge_g, badge_b = 0.56, 0.39, 0.17
    elseif quality == "diminished" then
      body_r, body_g, body_b = 0.35, 0.15, 0.18
      accent_r, accent_g, accent_b = 0.90, 0.34, 0.39
      badge_r, badge_g, badge_b = 0.56, 0.24, 0.28
    elseif quality == "augmented" then
      body_r, body_g, body_b = 0.31, 0.17, 0.26
      accent_r, accent_g, accent_b = 0.86, 0.45, 0.76
      badge_r, badge_g, badge_b = 0.50, 0.28, 0.43
    elseif quality == "suspended" then
      body_r, body_g, body_b = 0.16, 0.29, 0.27
      accent_r, accent_g, accent_b = 0.39, 0.80, 0.73
      badge_r, badge_g, badge_b = 0.23, 0.49, 0.45
    elseif quality == "single" then
      body_r, body_g, body_b = 0.23, 0.23, 0.26
      accent_r, accent_g, accent_b = 0.58, 0.58, 0.64
      badge_r, badge_g, badge_b = 0.36, 0.36, 0.42
    end

    local normalized_theme = normalize_chord_block_theme(theme)

    if normalized_theme == CHORD_BLOCK_THEME_PURPLE then
      body_r, body_g, body_b =
        clamp01(body_r + 0.08),
        clamp01(body_g - 0.03),
        clamp01(body_b + 0.10)

      accent_r, accent_g, accent_b =
        clamp01(accent_r + 0.12),
        clamp01(accent_g - 0.04),
        clamp01(accent_b + 0.08)

      badge_r, badge_g, badge_b =
        clamp01(badge_r + 0.10),
        clamp01(badge_g - 0.02),
        clamp01(badge_b + 0.07)
    elseif normalized_theme == CHORD_BLOCK_THEME_NEUTRAL then
      body_r, body_g, body_b = desaturate_color(body_r, body_g, body_b, 0.82)
      accent_r, accent_g, accent_b = desaturate_color(accent_r, accent_g, accent_b, 0.70)
      badge_r, badge_g, badge_b = desaturate_color(badge_r, badge_g, badge_b, 0.74)

      accent_r, accent_g, accent_b =
        clamp01(accent_r + 0.03),
        clamp01(accent_g + 0.03),
        clamp01(accent_b + 0.04)
    end

    local hover_boost = hovered and 0.08 or 0

    return {
      body_r = clamp01(body_r + hover_boost),
      body_g = clamp01(body_g + hover_boost),
      body_b = clamp01(body_b + hover_boost),
      accent_r = clamp01(accent_r + (hovered and 0.05 or 0)),
      accent_g = clamp01(accent_g + (hovered and 0.05 or 0)),
      accent_b = clamp01(accent_b + (hovered and 0.05 or 0)),
      badge_r = clamp01(badge_r + (hovered and 0.05 or 0)),
      badge_g = clamp01(badge_g + (hovered and 0.05 or 0)),
      badge_b = clamp01(badge_b + (hovered and 0.05 or 0)),
    }
  end

  local function fit_text_to_width(text, max_width, font_size)
    local source = tostring(text or "")
    if source == "" then return "" end

    gfx.setfont(1, "Segoe UI", font_size)
    local width = gfx.measurestr(source)
    if width <= max_width then
      return source
    end

    local trimmed = source
    while #trimmed > 1 do
      trimmed = trimmed:sub(1, #trimmed - 1)
      if gfx.measurestr(trimmed .. "…") <= max_width then
        return trimmed .. "…"
      end
    end

    return ""
  end

  local function fit_text_and_font(text, max_width, max_height, preferred_font, minimum_font)
    local source = tostring(text or "")
    if source == "" then source = "?" end

    local preferred = math.max(1, math.floor(preferred_font or 12))
    local minimum = math.max(1, math.floor(minimum_font or 8))
    if preferred < minimum then
      preferred = minimum
    end

    local best_text = ""
    local best_w, best_h = 0, 0
    local best_font = minimum

    for font_size = preferred, minimum, -1 do
      local candidate = fit_text_to_width(source, max_width, font_size)
      if candidate ~= "" then
        gfx.setfont(1, "Segoe UI", font_size)
        local cand_w, cand_h = gfx.measurestr(candidate)
        best_text = candidate
        best_w = cand_w
        best_h = cand_h
        best_font = font_size
        if cand_w <= max_width and cand_h <= max_height then
          return candidate, font_size, cand_w, cand_h
        end
      end
    end

    if best_text == "" then
      best_text = fit_text_to_width(source, max_width, minimum)
      gfx.setfont(1, "Segoe UI", minimum)
      best_w, best_h = gfx.measurestr(best_text)
      best_font = minimum
    end

    return best_text, best_font, best_w, best_h
  end

  local function compact_quality_label(quality)
    local q = tostring(quality or "")
    if q == "major" then return "maj" end
    if q == "minor" then return "min" end
    if q == "dominant" then return "dom" end
    if q == "diminished" then return "dim" end
    if q == "augmented" then return "aug" end
    if q == "suspended" then return "sus" end
    if q == "single" then return "single" end
    return q
  end

  local function draw_chord_blocks_lane(x, y, w, h, arrange_start, arrange_end, click, right_click, now)
    gfx.set(0.08, 0.08, 0.09, 1)
    gfx.rect(x, y, w, h, 1)

    gfx.set(0.20, 0.20, 0.22, 1)
    gfx.rect(x, y, w, h, 0)

    gfx.setfont(1, "Segoe UI", 13)
    gfx.set(0.86, 0.86, 0.90, 1)
    gfx.x = x + 8
    gfx.y = y + 4
    gfx.drawstr("Chord Blocks (double-click=open/zoom, right-click=chord tools)")

    gfx.setfont(1, "Segoe UI", 12)
    gfx.set(0.70, 0.72, 0.78, 1)
    local active_theme = resolve_chord_block_theme(ui_state.block_theme)
    local blocks_summary = tostring(#ui_state.chord_blocks) .. " blocks | " .. chord_block_theme_to_display_label(ui_state.block_theme)
    local summary_w = gfx.measurestr(blocks_summary)
    gfx.x = x + w - summary_w - 10
    gfx.y = y + 5
    gfx.drawstr(blocks_summary)

    local lane_top = y + 24
    local lane_h = h - 30
    local lane_x = x + 1
    local lane_w = w - 2
    local timeline_x = lane_x
    local timeline_w = lane_w

    gfx.set(0.07, 0.07, 0.08, 1)
    gfx.rect(lane_x, lane_top, lane_w, lane_h, 1)

    local view_len = arrange_end - arrange_start
    if view_len <= 0 then
      return
    end

    local arrange_hzoom = tonumber(reaper.GetHZoomLevel()) or 0
    if arrange_hzoom > 0 and lane_w > 0 then
      local arrange_content_w = math.floor((view_len * arrange_hzoom) + 0.5)
      if arrange_content_w > 0 then
        timeline_w = math.max(10, math.min(lane_w, arrange_content_w))
        timeline_x = lane_x + math.max(0, lane_w - timeline_w)
      end
    end

    if timeline_w < 10 then
      timeline_x = lane_x
      timeline_w = lane_w
    end

    local timeline_calibration_px = clamp_timeline_calibration_px(ui_state.timeline_calibration_px)
    if timeline_calibration_px ~= 0 then
      timeline_x = timeline_x + timeline_calibration_px
      timeline_w = timeline_w - timeline_calibration_px
    end

    if timeline_x < lane_x then
      local push = lane_x - timeline_x
      timeline_x = lane_x
      timeline_w = timeline_w - push
    end

    local lane_right = lane_x + lane_w
    local timeline_right = timeline_x + timeline_w
    if timeline_right > lane_right then
      timeline_w = timeline_w - (timeline_right - lane_right)
    end

    if timeline_w < 10 then
      timeline_w = math.min(lane_w, 10)
      timeline_x = lane_x + math.max(0, lane_w - timeline_w)
    end

    local qn_start = tonumber(reaper.TimeMap2_timeToQN(0, arrange_start)) or 0
    local qn_end = tonumber(reaper.TimeMap2_timeToQN(0, arrange_end)) or qn_start
    local grid_division = reaper.GetSetProjectGrid(0, false, 0, 0, 0)
    grid_division = tonumber(grid_division) or 0.25
    if grid_division <= 0 then
      grid_division = 0.25
    end

    local drew_grid = false
    local qn_span = qn_end - qn_start
    if qn_span > 0 and timeline_w > 0 then
      local px_per_qn = timeline_w / qn_span
      local px_per_div = px_per_qn * grid_division
      local min_px_step = 10
      local skip = 1
      if px_per_div > 0 then
        skip = math.max(1, math.floor(min_px_step / px_per_div))
      end

      local quarter_step = math.max(1, math.floor((1 / grid_division) + 0.5))
      local strong_step = quarter_step * 4
      local start_index = math.floor(qn_start / grid_division) - 1
      local end_index = math.ceil(qn_end / grid_division) + 1

      for index = start_index, end_index, skip do
        local qn_pos = index * grid_division
        local line_time = reaper.TimeMap2_QNToTime(0, qn_pos)
        if line_time >= arrange_start and line_time <= arrange_end then
          local ratio = (line_time - arrange_start) / view_len
          local gx = timeline_x + math.floor((ratio * timeline_w) + 0.5)

          if strong_step > 0 and (index % strong_step) == 0 then
            gfx.set(0.23, 0.23, 0.29, 1)
          elseif quarter_step > 0 and (index % quarter_step) == 0 then
            gfx.set(0.18, 0.18, 0.22, 1)
          else
            gfx.set(0.12, 0.12, 0.14, 1)
          end

          gfx.line(gx, lane_top + 1, gx, lane_top + lane_h - 2)
          drew_grid = true
        end
      end
    end

    if not drew_grid then
      local fallback_lines = 24
      for step = 0, fallback_lines do
        local ratio = step / fallback_lines
        local gx = timeline_x + math.floor((ratio * timeline_w) + 0.5)
        if step % 4 == 0 then
          gfx.set(0.18, 0.18, 0.22, 1)
        else
          gfx.set(0.12, 0.12, 0.14, 1)
        end
        gfx.line(gx, lane_top + 1, gx, lane_top + lane_h - 2)
      end
    end

    local mx, my = gfx.mouse_x, gfx.mouse_y
    local hovered_block = nil

    for i = 1, #ui_state.chord_blocks do
      local block = ui_state.chord_blocks[i]
      local visible_start = math.max(block.start_time, arrange_start)
      local visible_end = math.min(block.end_time, arrange_end)

      if visible_end > visible_start then
        local bx = timeline_x + ((visible_start - arrange_start) / view_len) * timeline_w
        local bw = ((visible_end - visible_start) / view_len) * timeline_w
        if bw < 4 then bw = 4 end
        local timeline_right = timeline_x + timeline_w
        if (bx + bw) > timeline_right then
          bw = timeline_right - bx
        end
        if bw < 1 then
          bw = 1
        end
        local by = lane_top + 4
        local bh = lane_h - 8

        local is_hovered = point_in_rect(mx, my, bx, by, bw, bh)
        if is_hovered then
          hovered_block = block
        end

        local style = block_style_for_quality(block.quality, is_hovered, active_theme)

        local block_pad = math.max(3, math.floor(math.min(bw, bh) * 0.08))
        local accent_h = math.max(3, math.min(7, math.floor(bh * 0.12)))
        local shadow_h = math.max(2, math.min(6, math.floor(bh * 0.10)))

        gfx.set(style.body_r, style.body_g, style.body_b, 1)
        gfx.rect(bx, by, bw, bh, 1)

        gfx.set(style.accent_r, style.accent_g, style.accent_b, 1)
        gfx.rect(bx, by, bw, accent_h, 1)

        gfx.set(0.06, 0.06, 0.07, 0.45)
        gfx.rect(bx + 1, by + bh - shadow_h - 1, bw - 2, shadow_h, 1)

        gfx.set(0.08, 0.08, 0.08, 1)
        gfx.rect(bx, by, bw, bh, 0)

        local has_badge = (bw >= 42) and (bh >= 30)
        local badge_h = 0
        local badge_y = by + block_pad
        if has_badge then
          badge_h = math.max(12, math.min(18, math.floor(bh * 0.22)))
          local badge_w = math.min(math.max(22, math.floor(bw * 0.34)), bw - (block_pad * 2))
          local badge_x = bx + block_pad

          gfx.set(style.badge_r, style.badge_g, style.badge_b, 1)
          gfx.rect(badge_x, badge_y, badge_w, badge_h, 1)
          gfx.set(0.07, 0.07, 0.08, 0.9)
          gfx.rect(badge_x, badge_y, badge_w, badge_h, 0)

          local badge_font = math.max(8, math.min(12, badge_h - 3))
          gfx.setfont(1, "Segoe UI", badge_font)
          local degree_text = fit_text_to_width(block.degree_label or "?", badge_w - 6, badge_font)
          local degree_w, degree_h = gfx.measurestr(degree_text)
          gfx.set(0.95, 0.95, 0.98, 1)
          gfx.x = badge_x + math.max(3, (badge_w - degree_w) * 0.5)
          gfx.y = badge_y + math.max(0, (badge_h - degree_h) * 0.5)
          gfx.drawstr(degree_text)

          local quality_slot_w = bw - badge_w - (block_pad * 3)
          local show_quality = (bw >= 92) and (bh >= 36) and (quality_slot_w >= 28)
          if show_quality then
            local quality_font = math.max(8, math.min(10, badge_h - 4))
            local quality_label = compact_quality_label(block.quality)
            local quality_text = fit_text_to_width(quality_label, quality_slot_w, quality_font)
            if quality_text ~= "" then
              gfx.setfont(1, "Segoe UI", quality_font)
              local quality_w, quality_h = gfx.measurestr(quality_text)
              gfx.set(0.82, 0.84, 0.90, 1)
              gfx.x = bx + bw - quality_w - block_pad
              gfx.y = badge_y + math.max(0, (badge_h - quality_h) * 0.5)
              gfx.drawstr(quality_text)
            end
          end
        end

        if bw > 22 then
          local chord_label = block.chord_name or ""
          if chord_label == "" then
            chord_label = "?"
          end
          if not has_badge and bw <= 64 then
            chord_label = (block.degree_label or "?") .. " " .. chord_label
          end

          local text_top = by + block_pad
          if has_badge then
            text_top = badge_y + badge_h + math.max(2, math.floor(bh * 0.05))
          end
          local text_h = math.max(8, (by + bh - block_pad - 1) - text_top)
          local text_w = math.max(10, bw - (block_pad * 2))
          local preferred_font = math.max(9, math.min(22, math.floor(math.min(text_h * 0.95, bw * 0.22))))
          local minimum_font = (bw < 34 or bh < 26) and 7 or 8

          local fitted_label, fitted_font, chord_w, chord_h = fit_text_and_font(
            chord_label,
            text_w,
            text_h,
            preferred_font,
            minimum_font
          )

          if fitted_label ~= "" then
            gfx.setfont(1, "Segoe UI", fitted_font)
            gfx.set(0.98, 0.98, 0.99, 1)
            gfx.x = bx + math.max(block_pad, (bw - chord_w) * 0.5)
            gfx.y = text_top + math.max(0, (text_h - chord_h) * 0.5)
            gfx.drawstr(fitted_label)
          end
        end
      end
    end

    if #ui_state.chord_blocks == 0 then
      gfx.setfont(1, "Segoe UI", 13)
      gfx.set(0.70, 0.70, 0.74, 1)
      gfx.x = x + 8
      gfx.y = lane_top + 12
      gfx.drawstr("No chord blocks available yet. Add MIDI chords on the selected chord track.")
    end

    if click then
      if hovered_block then
        if ui_state.last_block_click_id == hovered_block.block_id and (now - ui_state.last_block_click_time) <= 0.35 then
          local ok, status = open_block_in_midi_editor(hovered_block)
          set_status(status)
          if ok then
            ui_state.last_project_state = -1
          end
          ui_state.last_block_click_id = nil
          ui_state.last_block_click_time = 0
        else
          ui_state.last_block_click_id = hovered_block.block_id
          ui_state.last_block_click_time = now
        end
      else
        ui_state.last_block_click_id = nil
      end
    end

    if right_click and hovered_block then
      gfx.x = mx
      gfx.y = my
      local action = gfx.showmenu(
        "Open in MIDI Editor (zoom)|Invert Up|Invert Down|Set Chord Major|Set Chord Minor|Set Chord Dominant 7|Set Chord Major 7|Substitute Relative Minor|Substitute Relative Major|Substitute Tritone"
      )

      if action > 0 then
        local ok, status = apply_block_context_action(hovered_block, action)
        set_status(status)
        if ok then
          ui_state.last_project_state = -1
        end
      end
    end
  end

  local function loop()
    local key = gfx.getchar()
    if key < 0 then
      return
    end

    local now = reaper.time_precise()
    local lmb_down = (gfx.mouse_cap & 1) == 1
    local rmb_down = (gfx.mouse_cap & 2) == 2
    local click = lmb_down and not ui_state.prev_lmb
    local right_click = rmb_down and not ui_state.prev_rmb
    ui_state.prev_lmb = lmb_down
    ui_state.prev_rmb = rmb_down

    local current_state = load_state()
    ui_state.cut_overlaps_after_snap = get_cut_overlaps_after_snap_enabled()
    ui_state.allow_snap_inversions = SnapSettings.get_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, false)
    ui_state.timeline_calibration_px = get_timeline_calibration_px()
    ui_state.new_note_snap_pipeline_mode = get_new_note_snap_pipeline_mode()
    ui_state.new_note_snap_mode = get_new_note_snap_mode()
    local chord_track = find_track_by_guid(current_state.track_guid)
    local chord_track_name = chord_track and get_track_name(chord_track) or "(not set)"
    local auto_snap_arm_summary, selected_infos = selected_tracks_auto_snap_arm_summary(chord_track)
    local scale_notes = pitch_set_to_note_names(current_state.scale_pcs)
    if scale_notes == "" then scale_notes = "(none)" end

    maybe_refresh_chord_blocks(chord_track, current_state)

    local arrange_start, arrange_end = reaper.GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
    arrange_start = tonumber(arrange_start) or 0
    arrange_end = tonumber(arrange_end) or (arrange_start + 8)
    if arrange_end <= arrange_start then
      arrange_end = arrange_start + 8
    end

    gfx.set(0.14, 0.14, 0.15, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    local margin = (gfx.w < 500) and 8 or 16
    local x = margin
    local w = gfx.w - (margin * 2)
    if w < 140 then
      x = 1
      w = math.max(80, gfx.w - 2)
    end

    local status_h = (gfx.h < 320) and 24 or 28
    local status_y = gfx.h - status_h
    if status_y < 0 then
      status_y = 0
    end

    local tabs = {
      { id = "home", label = "Home", short = "Home", icon = "H" },
      { id = "snap", label = "Snap", short = "Snap", icon = "S" },
      { id = "theme", label = "Theme", short = "Them", icon = "T" },
    }

    if not ui_state.active_tab then
      ui_state.active_tab = "home"
    end
    if ui_state.active_tab == "follow" then
      ui_state.active_tab = "snap"
    end
    if not ui_state.tab_scroll then
      ui_state.tab_scroll = { home = 0, snap = 0, theme = 0 }
    end
    if ui_state.compact_mode then
      ui_state.active_tab = "home"
    end

    local function selected_target_mode_summary()
      local first_mode = nil
      local mixed = false
      local has_target = false
      for i = 1, #selected_infos do
        local info = selected_infos[i]
        if not info.is_chord_track then
          has_target = true
          if not first_mode then
            first_mode = info.auto_snap_arm_mode
          elseif first_mode ~= info.auto_snap_arm_mode then
            mixed = true
            break
          end
        end
      end

      if not has_target then
        return nil, "No target tracks selected"
      end
      if mixed then
        return nil, "Mixed"
      end
      return first_mode, auto_snap_arm_mode_to_label(first_mode)
    end

    local function selected_follow_modes_summary()
      local target_count = 0
      local labels = {}
      local seen = {}
      local first_label = nil
      local mixed = false

      for i = 1, #selected_infos do
        local info = selected_infos[i]
        if not info.is_chord_track then
          target_count = target_count + 1
          local label = auto_snap_arm_mode_to_label(info.auto_snap_arm_mode)

          if not first_label then
            first_label = label
          elseif label ~= first_label then
            mixed = true
          end

          if not seen[label] then
            seen[label] = true
            labels[#labels + 1] = label
          end
        end
      end

      if target_count <= 0 then
        return "No target tracks selected", false, 0
      end

      if mixed then
        return table.concat(labels, ", "), true, target_count
      end

      return tostring(first_label or "No target tracks selected"), false, target_count
    end

    local function apply_selected_mode(mode)
      local mapped_snap_mode = auto_snap_arm_mode_to_snap_mode(mode) or normalize_snap_mode(mode)
      if not mapped_snap_mode then
        set_status("Invalid snap method.")
        return
      end

      apply_selected_tracks_follow_mode_from_snap_mode(mapped_snap_mode, selected_infos)
    end

    local top_y = (gfx.h < 320) and 8 or 12
    local top_space_h = math.max(80, status_y - top_y)
    local dense_top = (w < 620) or (top_space_h < 360)
    local very_dense_top = (w < 500) or (top_space_h < 300)
    local title_font = very_dense_top and 19 or (dense_top and 21 or 24)
    local title_h = very_dense_top and 28 or (dense_top and 31 or 34)
    local compact_icon_size = very_dense_top and 20 or 22
    local compact_icon_x = x + w - compact_icon_size
    local compact_icon_y = top_y + math.max(0, math.floor((title_h - compact_icon_size) * 0.5))
    local compact_icon_label = ui_state.compact_mode and "C" or "N"

    local function draw_title_chrome(allow_click)
      gfx.setfont(1, "Segoe UI", title_font)
      gfx.set(0.96, 0.96, 0.96, 1)
      gfx.x = x
      gfx.y = top_y
      gfx.drawstr("Chord Track")

      local icon_clicked = draw_icon_button(
        compact_icon_x,
        compact_icon_y,
        compact_icon_size,
        compact_icon_label,
        allow_click and click
      )

      if icon_clicked then
        ui_state.compact_mode = not ui_state.compact_mode
        reaper.SetExtState(PANEL_SECTION, "COMPACT_MODE", ui_state.compact_mode and "1" or "0", true)
        if ui_state.compact_mode then
          ui_state.active_tab = "home"
        end
        set_status(ui_state.compact_mode and "Compact view enabled." or "Compact view disabled.")
      end
    end

    draw_title_chrome(true)

    local panel_y = top_y + title_h
    local panel_bottom = status_y - 8
    if panel_bottom < (panel_y + 84) then
      panel_bottom = panel_y + 84
    end
    if panel_bottom > (gfx.h - 1) then
      panel_bottom = gfx.h - 1
    end
    local panel_h = panel_bottom - panel_y

    gfx.set(0.10, 0.10, 0.11, 1)
    gfx.rect(x, panel_y, w, panel_h, 1)
    gfx.set(0.20, 0.20, 0.22, 1)
    gfx.rect(x, panel_y, w, panel_h, 0)

    local tab_bar_h = very_dense_top and 24 or (dense_top and 27 or 30)
    local tab_gap = (w < 420) and 2 or ((w < 700) and 4 or 6)
    local tab_count = #tabs
    local tab_w = math.floor((w - ((tab_count - 1) * tab_gap) - 2) / tab_count)
    if tab_w < 14 then
      tab_gap = 1
      tab_w = math.floor((w - ((tab_count - 1) * tab_gap) - 2) / tab_count)
    end
    if tab_w < 12 then
      tab_w = 12
    end
    local tab_y = panel_y + 4
    local tab_label_mode = "full"
    if tab_w < 70 then tab_label_mode = "short" end
    if tab_w < 42 then tab_label_mode = "icon" end
    local tab_label_font = very_dense_top and 12 or (dense_top and 13 or 14)
    if tab_label_mode == "icon" then
      tab_label_font = math.max(10, tab_label_font - 1)
    end

    local function draw_main_tabs(allow_click)
      local tab_x = x + 1
      for i = 1, tab_count do
        local tab = tabs[i]
        local selected = false

        if ui_state.compact_mode then
          selected = (tab.id == "home")
        else
          selected = (ui_state.active_tab == tab.id)
        end

        if selected then
          gfx.set(0.28, 0.28, 0.33, 1)
        else
          gfx.set(0.18, 0.18, 0.20, 1)
        end
        gfx.rect(tab_x, tab_y, tab_w, tab_bar_h, 1)
        gfx.set(0.10, 0.10, 0.11, 1)
        gfx.rect(tab_x, tab_y, tab_w, tab_bar_h, 0)

        local label_source = tab.label
        if tab_label_mode == "short" then
          label_source = tab.short or tab.label
        elseif tab_label_mode == "icon" then
          label_source = tab.icon or string.sub(tab.label or "?", 1, 1)
        end

        gfx.setfont(1, "Segoe UI", tab_label_font)
        gfx.set(selected and 0.97 or 0.84, selected and 0.97 or 0.84, selected and 0.99 or 0.86, 1)
        local label_pad = (tab_label_mode == "icon") and 6 or 10
        local tab_label = fit_text_to_width(label_source, math.max(4, tab_w - label_pad), tab_label_font)
        local label_w, label_h = gfx.measurestr(tab_label)
        gfx.x = tab_x + math.max(3, (tab_w - label_w) * 0.5)
        gfx.y = tab_y + math.max(3, (tab_bar_h - label_h) * 0.5)
        gfx.drawstr(tab_label)

        if allow_click and click and point_in_rect(gfx.mouse_x, gfx.mouse_y, tab_x, tab_y, tab_w, tab_bar_h) then
          if ui_state.compact_mode and tab.id ~= "home" then
            local _, status = launch_compact_popout_window(tab.id)
            set_status(status)
          else
            ui_state.active_tab = tab.id
          end
        end

        tab_x = tab_x + tab_w + tab_gap
      end
    end

    draw_main_tabs(true)

    local content_x = x + 1
    local content_y = tab_y + tab_bar_h + 6
    local content_w = w - 2
    local content_h = panel_y + panel_h - content_y - 8
    if content_h < 40 then content_h = 40 end

    local function density_for_area(area_w, area_h)
      local dense = (area_w < 560) or (area_h < 320)
      local very_dense = (area_w < 430) or (area_h < 250)
      return {
        dense = dense,
        very_dense = very_dense,
        heading_font = very_dense and 14 or (dense and 15 or 17),
        body_font = very_dense and 12 or (dense and 13 or 14),
        meta_font = very_dense and 11 or (dense and 12 or 13),
        label_padding = very_dense and 5 or (dense and 6 or 8),
        button_h = very_dense and 24 or (dense and 26 or 30),
        button_row_gap = very_dense and 3 or (dense and 4 or 6),
        button_font = very_dense and 12 or (dense and 13 or 14),
        spacer_h = very_dense and 6 or (dense and 7 or 8),
        wheel_step = very_dense and 18 or (dense and 22 or 28),
      }
    end

    local function render_tab_content(target_tab, area_x, area_y, area_w, area_h, do_draw, allow_click, density)
      local scroll = ui_state.tab_scroll[target_tab] or 0
      local virtual_y = 8
      local area_bottom = area_y + area_h

      local function row(height, painter)
        local draw_y = area_y + virtual_y - scroll
        if do_draw and (draw_y + height) > area_y and draw_y < area_bottom then
          painter(draw_y, height)
        end
        virtual_y = virtual_y + height
      end

      local function spacer(height)
        row(height, function() end)
      end

      local function label(text, size, r, g, b)
        local font_size = size or density.body_font
        local display_text = fit_text_to_width(text, area_w - 24, font_size)
        row(font_size + density.label_padding, function(draw_y)
          gfx.setfont(1, "Segoe UI", font_size)
          gfx.set(r or 0.86, g or 0.86, b or 0.90, 1)
          gfx.x = area_x + 10
          gfx.y = draw_y
          gfx.drawstr(display_text)
        end)
      end

      local function button_row(text, callback)
        row(density.button_h + density.button_row_gap, function(draw_y)
          gfx.setfont(1, "Segoe UI", density.button_font)
          local button_text = fit_text_to_width(text, area_w - 26, density.button_font)
          local can_click = allow_click and do_draw and point_in_rect(gfx.mouse_x, gfx.mouse_y, area_x, area_y, area_w, area_h)
          if draw_button(area_x + 8, draw_y, area_w - 16, density.button_h, button_text, can_click) then
            callback(draw_y)
          end
        end)
      end

      local function menu_button_row(text, callback)
        row(density.button_h + density.button_row_gap, function(draw_y)
          gfx.setfont(1, "Segoe UI", density.button_font)
          local button_text = fit_text_to_width(text, area_w - 26, density.button_font)
          local can_click = allow_click and do_draw and point_in_rect(gfx.mouse_x, gfx.mouse_y, area_x, area_y, area_w, area_h)
          if draw_button(area_x + 8, draw_y, area_w - 16, density.button_h, button_text, can_click) then
            callback(area_x + 16, draw_y + density.button_h + 2)
          end
        end)
      end

      if target_tab == "home" then
        local selected_follow_modes_text, selected_follow_has_multiple_modes, selected_follow_target_count = selected_follow_modes_summary()
        local selected_follow_section_title = (selected_follow_target_count > 1) and "Selected Tracks Follow" or "Selected Track Follow"
        local selected_follow_label = selected_follow_has_multiple_modes and "Follow modes: " or "Follow mode: "

        if ui_state.compact_mode then
          local card_gap_x = density.dense and 6 or 8
          local inner_w = area_w - 16
          local col_count = 3
          if inner_w < 640 then col_count = 2 end
          if inner_w < 420 then col_count = 1 end
          local card_gap_y = (col_count == 1) and 0 or card_gap_x
          local card_w = math.floor((inner_w - ((col_count - 1) * card_gap_x)) / col_count)
          local scale_card_h = density.heading_font + (density.body_font * 2) + density.meta_font + density.button_h + 34
          local chord_card_h = density.heading_font + density.body_font + density.button_h + 30
          local follow_card_h = density.heading_font + (density.body_font * 2) + density.meta_font + 30
          local base_card_h = math.max(
            (density.button_h * 2) + (density.very_dense and 44 or (density.dense and 50 or 56)),
            scale_card_h,
            follow_card_h
          )
          local card_h_values = { base_card_h, base_card_h, base_card_h }

          if col_count == 1 then
            card_h_values[1] = scale_card_h
            card_h_values[2] = chord_card_h
            card_h_values[3] = follow_card_h
          end

          local card_y_offsets = { 0, 0, 0 }
          if col_count == 1 then
            local running_offset = 0
            for i = 1, 3 do
              card_y_offsets[i] = running_offset
              running_offset = running_offset + card_h_values[i] + card_gap_y
            end
          end

          local function draw_card(index, title, painter)
            local card_h = card_h_values[index] or base_card_h
            local card_x = area_x + 8
            local card_y = area_y + 8 - scroll

            if col_count == 1 then
              card_y = area_y + 8 + (card_y_offsets[index] or 0) - scroll
            else
              local col = (index - 1) % col_count
              local row_index = math.floor((index - 1) / col_count)
              card_x = area_x + 8 + (col * (card_w + card_gap_x))
              card_y = area_y + 8 + (row_index * (base_card_h + card_gap_y)) - scroll
            end

            if do_draw and (card_y + card_h) > area_y and card_y < area_bottom then
              gfx.set(0.12, 0.12, 0.14, 1)
              gfx.rect(card_x, card_y, card_w, card_h, 1)
              gfx.set(0.22, 0.22, 0.25, 1)
              gfx.rect(card_x, card_y, card_w, card_h, 0)

              gfx.setfont(1, "Segoe UI", density.heading_font)
              gfx.set(0.95, 0.95, 0.98, 1)
              local title_text = fit_text_to_width(title, card_w - 14, density.heading_font)
              gfx.x = card_x + 7
              gfx.y = card_y + 6
              gfx.drawstr(title_text)

              painter(card_x, card_y, card_w, card_h)
            end
          end

          draw_card(1, "Scale", function(card_x, card_y, card_w_value, card_h_value)
            gfx.setfont(1, "Segoe UI", density.body_font)
            gfx.set(0.86, 0.86, 0.90, 1)
            local y1 = card_y + density.heading_font + 12
            gfx.x = card_x + 7
            gfx.y = y1
            gfx.drawstr(fit_text_to_width("Key: " .. (current_state.root_name ~= "" and current_state.root_name or "(not synced)"), card_w_value - 14, density.body_font))

            gfx.x = card_x + 7
            gfx.y = y1 + density.body_font + 4
            gfx.drawstr(fit_text_to_width("Scale: " .. (current_state.scale_name ~= "" and current_state.scale_name or "(not synced)"), card_w_value - 14, density.body_font))

            gfx.setfont(1, "Segoe UI", density.meta_font)
            gfx.set(0.80, 0.80, 0.84, 1)
            gfx.x = card_x + 7
            gfx.y = y1 + (density.body_font * 2) + 8
            gfx.drawstr(fit_text_to_width("Notes: " .. scale_notes, card_w_value - 14, density.meta_font))

            gfx.setfont(1, "Segoe UI", density.button_font)
            local button_text = fit_text_to_width("Sync key+scale from MIDI Editor", card_w_value - 18, density.button_font)
            local button_y = card_y + card_h_value - density.button_h - 8
            if draw_button(card_x + 6, button_y, card_w_value - 12, density.button_h, button_text, allow_click and do_draw) then
              run_sync_scale_action()
            end
          end)

          draw_card(2, "Chord Track", function(card_x, card_y, card_w_value, card_h_value)
            gfx.setfont(1, "Segoe UI", density.body_font)
            gfx.set(0.86, 0.86, 0.90, 1)
            local y1 = card_y + density.heading_font + 12
            gfx.x = card_x + 7
            gfx.y = y1
            gfx.drawstr(fit_text_to_width("Track: " .. chord_track_name, card_w_value - 14, density.body_font))

            gfx.setfont(1, "Segoe UI", density.button_font)
            local button_text = fit_text_to_width("Set selected as Chord Track", card_w_value - 18, density.button_font)
            local button_y = card_y + card_h_value - density.button_h - 8
            if draw_button(card_x + 6, button_y, card_w_value - 12, density.button_h, button_text, allow_click and do_draw) then
              run_set_selected_as_chord_track_action()
            end
          end)

          draw_card(3, selected_follow_section_title, function(card_x, card_y, card_w_value, card_h_value)
            gfx.setfont(1, "Segoe UI", density.body_font)
            gfx.set(0.86, 0.86, 0.90, 1)
            local y1 = card_y + density.heading_font + 12
            gfx.x = card_x + 7
            gfx.y = y1
            gfx.drawstr(fit_text_to_width(selected_follow_label .. tostring(selected_follow_modes_text or "No target tracks selected"), card_w_value - 14, density.body_font))

            gfx.x = card_x + 7
            gfx.y = y1 + density.body_font + 4
            gfx.drawstr(fit_text_to_width("Arming: " .. arming_status_text_for_selected_tracks(selected_infos), card_w_value - 14, density.body_font))

            gfx.setfont(1, "Segoe UI", density.meta_font)
            gfx.set(0.80, 0.80, 0.84, 1)
            gfx.x = card_x + 7
            gfx.y = y1 + (density.body_font * 2) + 8
            gfx.drawstr(fit_text_to_width("Use Snap tab for controls", card_w_value - 14, density.meta_font))
          end)

          if col_count == 1 then
            virtual_y = 8 + card_h_values[1] + card_h_values[2] + card_h_values[3] + (card_gap_y * 2)
          else
            local row_count = math.floor((3 + col_count - 1) / col_count)
            virtual_y = 8 + (row_count * (base_card_h + card_gap_y)) - card_gap_y
          end
        else
          label("Scale", density.heading_font, 0.95, 0.95, 0.98)
          label("Key: " .. (current_state.root_name ~= "" and current_state.root_name or "(not synced)"), density.body_font)
          label("Scale: " .. (current_state.scale_name ~= "" and current_state.scale_name or "(not synced)"), density.body_font)
          label("Scale Notes: " .. scale_notes, density.meta_font, 0.80, 0.80, 0.84)
          button_row("Sync key+scale from MIDI Editor", run_sync_scale_action)

          spacer(density.spacer_h)
          label("Chord Track", density.heading_font, 0.95, 0.95, 0.98)
          label("Track Label: " .. chord_track_name, density.body_font)
          button_row("Set selected as Chord Track", run_set_selected_as_chord_track_action)

          spacer(density.spacer_h)
          label(selected_follow_section_title, density.heading_font, 0.95, 0.95, 0.98)
          label(selected_follow_label .. tostring(selected_follow_modes_text or "No target tracks selected"), density.body_font)
          label("Arming: " .. arming_status_text_for_selected_tracks(selected_infos), density.body_font)
          label("Use Snap tab for controls", density.meta_font, 0.80, 0.80, 0.84)
        end

      elseif target_tab == "snap" then
        local selected_mode, mode_text = selected_target_mode_summary()
        local pipeline_mode = normalize_new_note_snap_pipeline_mode(ui_state.new_note_snap_pipeline_mode)
        local selected_snap_mode = normalize_snap_mode(ui_state.new_note_snap_mode)
        local selected_mode_snap = selected_mode and auto_snap_arm_mode_to_snap_mode(selected_mode) or nil
        if selected_snap_mode == SNAP_MODE_MELODIC_FLOW and selected_mode_snap == SNAP_MODE_CHORD_SCALE then
          selected_mode_snap = SNAP_MODE_MELODIC_FLOW
        end
        local effective_snap_mode = normalize_snap_mode(selected_mode_snap or selected_snap_mode)

        local runtime_running = false
        local runtime_label = ""
        local runtime_detail = ""
        local runtime_r, runtime_g, runtime_b = 0.84, 0.84, 0.88

        if pipeline_mode == NEW_NOTE_SNAP_PIPELINE_PRE then
          local manager_running, manager_status = get_input_manager_runtime_status()
          runtime_running = manager_running
          runtime_label = manager_running and "[x] Pre Snap Running" or "[ ] Pre Snap Running"
          runtime_detail = "Manager: " .. tostring(manager_status or "")
          if manager_running then
            runtime_r, runtime_g, runtime_b = 0.84, 0.90, 0.84
          end
        else
          local runtime = describe_live_runtime_status()
          runtime_running = runtime.running
          runtime_label = runtime.running and "[x] Post Snap Running" or "[ ] Post Snap Running"
          runtime_detail = runtime.detail or ""
          runtime_r = runtime.detail_r or 0.84
          runtime_g = runtime.detail_g or 0.84
          runtime_b = runtime.detail_b or 0.88
        end

        label("Selected Track Snap", density.heading_font, 0.95, 0.95, 0.98)
        label("Selected tracks: " .. mode_text, density.body_font)
        button_row(arming_toggle_label_for_selected_tracks(selected_infos), function() toggle_selected_tracks_follow_arming(selected_infos) end)
        button_row("UnArm All", disarm_all_target_tracks_follow)
        button_row("Snap selected tracks now (Follow mode)", run_snap_selected_tracks_by_arm_action)

        spacer(density.spacer_h)
        label("Pre/Post Recording", density.heading_font, 0.95, 0.95, 0.98)
        button_row(
          ((pipeline_mode == NEW_NOTE_SNAP_PIPELINE_PRE) and "(●) " or "(○) ") .. "Pre Recording (Input JSFX)",
          function() apply_new_note_pipeline_mode(NEW_NOTE_SNAP_PIPELINE_PRE) end
        )
        button_row(
          ((pipeline_mode == NEW_NOTE_SNAP_PIPELINE_POST) and "(●) " or "(○) ") .. "Post Recording (Live engine)",
          function() apply_new_note_pipeline_mode(NEW_NOTE_SNAP_PIPELINE_POST) end
        )

        spacer(density.spacer_h)
        label("Snap Method", density.heading_font, 0.95, 0.95, 0.98)

        local modes = {
          { id = AUTO_SNAP_ARM_MODE_CHORDS, label = "Chords" },
          { id = AUTO_SNAP_ARM_MODE_SCALES, label = "Scales" },
          { id = AUTO_SNAP_ARM_MODE_CHORDS_SCALES, label = "Chords + Scales" },
          { id = SNAP_MODE_MELODIC_FLOW, label = "Melodic Flow" },
        }

        for i = 1, #modes do
          local mode = modes[i]
          local mode_snap = auto_snap_arm_mode_to_snap_mode(mode.id) or normalize_snap_mode(mode.id)
          local marker = (mode_snap == effective_snap_mode) and "(●) " or "(○) "
          button_row(marker .. mode.label, function() apply_selected_mode(mode.id) end)
        end

        spacer(density.spacer_h)
        label("Runtime", density.heading_font, 0.95, 0.95, 0.98)
        label(runtime_label, density.body_font, runtime_r, runtime_g, runtime_b)
        label(runtime_detail, density.meta_font, runtime_r, runtime_g, runtime_b)
        label("Current method: " .. snap_mode_to_label(effective_snap_mode), density.meta_font, 0.80, 0.80, 0.84)

        spacer(density.spacer_h)
        label("Voicing", density.heading_font, 0.95, 0.95, 0.98)
        button_row((ui_state.allow_snap_inversions and "[x] " or "[ ] ") .. "Allow snap inversions", function()
          local next_value = not ui_state.allow_snap_inversions
          SnapSettings.set_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, next_value)
          ui_state.allow_snap_inversions = next_value
          set_status(SnapSettings.toggle_status("Allow snap inversions", next_value))
        end)

        spacer(density.spacer_h)
        label("Input Snap Utilities", density.heading_font, 0.95, 0.95, 0.98)
        button_row("Ensure input snap JSFX installed", run_ensure_input_snap_jsfx_action)
        button_row("Repair input snap FX instances", run_repair_input_snap_fx_action)

      elseif target_tab == "theme" then
        local resolved = resolve_chord_block_theme(ui_state.block_theme)

        label("Chord Block Theme", density.heading_font, 0.95, 0.95, 0.98)
        label("Current: " .. chord_block_theme_to_display_label(ui_state.block_theme), density.body_font)
        label("Resolved: " .. chord_block_theme_to_label(resolved), density.meta_font, 0.80, 0.80, 0.84)

        local themes = {
          CHORD_BLOCK_THEME_AUTO,
          CHORD_BLOCK_THEME_BLUE,
          CHORD_BLOCK_THEME_PURPLE,
          CHORD_BLOCK_THEME_NEUTRAL,
        }
        for i = 1, #themes do
          local theme = themes[i]
          local marker = (ui_state.block_theme == theme) and "(●) " or "(○) "
          button_row(marker .. chord_block_theme_to_label(theme), function()
            ui_state.block_theme = normalize_chord_block_theme(theme)
            reaper.SetExtState(PANEL_SECTION, "BLOCK_THEME", ui_state.block_theme, true)
            set_status(format_theme_set_status(ui_state.block_theme))
          end)
        end

        spacer(density.spacer_h)
        label("Timeline Align Offset: " .. timeline_calibration_to_label(ui_state.timeline_calibration_px), density.body_font)
        menu_button_row("Set timeline align offset (coarse/fine) ▼", apply_timeline_calibration_menu)

        spacer(density.spacer_h)
        menu_button_row("Theme menu ▼", apply_block_theme_menu)
      end

      return virtual_y + 8
    end

    local function clamp_scroll(tab_id, max_scroll)
      if ui_state.tab_scroll[tab_id] == nil then
        ui_state.tab_scroll[tab_id] = 0
      end
      if ui_state.tab_scroll[tab_id] < 0 then
        ui_state.tab_scroll[tab_id] = 0
      end
      if ui_state.tab_scroll[tab_id] > max_scroll then
        ui_state.tab_scroll[tab_id] = max_scroll
      end
    end

    local function draw_scrollbar(area_x, area_y, area_w, area_h, content_total, max_scroll, tab_id)
      if max_scroll <= 0 then
        return
      end

      local scroll = ui_state.tab_scroll[tab_id] or 0
      local track_x = area_x + area_w - 8
      local track_y = area_y + 6
      local track_h = area_h - 12
      gfx.set(0.16, 0.16, 0.17, 1)
      gfx.rect(track_x, track_y, 4, track_h, 1)

      local thumb_h = math.max(24, (area_h / content_total) * track_h)
      local thumb_y = track_y + ((scroll / max_scroll) * (track_h - thumb_h))
      gfx.set(0.52, 0.52, 0.57, 1)
      gfx.rect(track_x, thumb_y, 4, thumb_h, 1)
    end

    local workspace_x = x + 1
    local workspace_y = tab_y + tab_bar_h + 6
    local workspace_w = w - 2
    local workspace_bottom = panel_y + panel_h - 8
    if workspace_bottom < (workspace_y + 40) then
      workspace_bottom = workspace_y + 40
    end
    local workspace_h = workspace_bottom - workspace_y
    local lane_gap = (workspace_h < 220) and 6 or 8

    content_x = workspace_x
    content_y = workspace_y
    content_w = workspace_w
    content_h = workspace_h

    local lane_x = workspace_x
    local lane_y = workspace_y
    local lane_w = workspace_w
    local lane_h = workspace_h

    if ui_state.compact_mode then
      local min_content_w = 200
      local min_content_h = 82
      local min_lane_h = 82

      local arrange_view_len_for_layout = arrange_end - arrange_start
      local arrange_hzoom_for_layout = tonumber(reaper.GetHZoomLevel()) or 0
      local aligned_lane_w = workspace_w
      if arrange_view_len_for_layout > 0 and arrange_hzoom_for_layout > 0 then
        local arrange_content_w = math.floor((arrange_view_len_for_layout * arrange_hzoom_for_layout) + 0.5)
        if arrange_content_w > 0 then
          aligned_lane_w = math.min(workspace_w, math.max(80, arrange_content_w))
        end
      end

      local aligned_lane_x = workspace_x + math.max(0, workspace_w - aligned_lane_w)
      local left_alignment_space_w = aligned_lane_x - workspace_x
      local can_place_content_left = left_alignment_space_w >= (min_content_w + lane_gap)

      if can_place_content_left then
        content_x = workspace_x
        content_y = workspace_y
        content_w = left_alignment_space_w - lane_gap
        content_h = workspace_h

        lane_x = aligned_lane_x
        lane_y = workspace_y
        lane_w = workspace_w - (aligned_lane_x - workspace_x)
        lane_h = workspace_h
      else
        local target_lane_h = math.floor(workspace_h * 0.44)
        local max_lane_h = workspace_h - min_content_h - lane_gap
        if max_lane_h < min_lane_h then
          max_lane_h = min_lane_h
        end
        if target_lane_h < min_lane_h then
          target_lane_h = min_lane_h
        end
        if target_lane_h > max_lane_h then
          target_lane_h = max_lane_h
        end

        lane_h = target_lane_h
        content_h = workspace_h - lane_h - lane_gap
        if content_h < min_content_h then
          content_h = min_content_h
          lane_h = workspace_h - content_h - lane_gap
        end
        if lane_h < 44 then
          lane_h = 44
          content_h = workspace_h - lane_h - lane_gap
        end
        if content_h < 44 then
          content_h = 44
          lane_h = workspace_h - content_h - lane_gap
        end

        content_x = workspace_x
        content_y = workspace_y
        content_w = workspace_w

        lane_x = workspace_x
        lane_y = content_y + content_h + lane_gap
        lane_w = workspace_w
      end
    else
      local min_content_h = 110
      local min_lane_h = 88
      local target_lane_h = math.floor(workspace_h * 0.34)
      if target_lane_h < min_lane_h then
        target_lane_h = min_lane_h
      end
      local max_lane_h = math.min(170, workspace_h - min_content_h - lane_gap)
      if max_lane_h < min_lane_h then
        max_lane_h = min_lane_h
      end
      if target_lane_h > max_lane_h then
        target_lane_h = max_lane_h
      end

      lane_h = target_lane_h
      content_h = workspace_h - lane_h - lane_gap
      if content_h < 70 then
        content_h = 70
        lane_h = workspace_h - content_h - lane_gap
      end
      if lane_h < 56 then
        lane_h = 56
        content_h = workspace_h - lane_h - lane_gap
      end

      content_x = workspace_x
      content_y = workspace_y
      content_w = workspace_w

      lane_x = workspace_x
      lane_y = content_y + content_h + lane_gap
      lane_w = workspace_w
    end

    if content_w < 80 then content_w = 80 end
    if content_h < 30 then content_h = 30 end
    if lane_w < 80 then lane_w = 80 end
    if lane_h < 30 then lane_h = 30 end

    local main_tab_id = ui_state.compact_mode and "home" or ui_state.active_tab
    local main_density = density_for_area(content_w, content_h)

    gfx.set(0.08, 0.08, 0.09, 1)
    gfx.rect(content_x, content_y, content_w, content_h, 1)

    local main_content_total = render_tab_content(main_tab_id, content_x, content_y, content_w, content_h, false, false, main_density)
    local main_max_scroll = math.max(0, main_content_total - content_h)

    local wheel_delta = gfx.mouse_wheel
    gfx.mouse_wheel = 0

    if wheel_delta ~= 0 and point_in_rect(gfx.mouse_x, gfx.mouse_y, content_x, content_y, content_w, content_h) then
      local scroll = (ui_state.tab_scroll[main_tab_id] or 0) - ((wheel_delta / 120) * main_density.wheel_step)
      ui_state.tab_scroll[main_tab_id] = scroll
    end

    clamp_scroll(main_tab_id, main_max_scroll)
    render_tab_content(main_tab_id, content_x, content_y, content_w, content_h, true, click, main_density)
    draw_scrollbar(content_x, content_y, content_w, content_h, main_content_total, main_max_scroll, main_tab_id)

    local content_bottom = content_y + content_h
    local panel_bottom = panel_y + panel_h
    local lower_panel_clip = math.min(gfx.h, panel_bottom)
    if content_bottom < lower_panel_clip then
      gfx.set(0.10, 0.10, 0.11, 1)
      gfx.rect(content_x, content_bottom, content_w, lower_panel_clip - content_bottom, 1)
    end
    if panel_bottom < gfx.h then
      gfx.set(0.14, 0.14, 0.15, 1)
      gfx.rect(content_x, panel_bottom, content_w, gfx.h - panel_bottom, 1)
    end
    gfx.set(0.20, 0.20, 0.22, 1)
    gfx.rect(content_x, content_y, content_w, content_h, 0)

    draw_chord_blocks_lane(lane_x, lane_y, lane_w, lane_h, arrange_start, arrange_end, click, right_click, now)

    local top_bg_h = math.min(content_y, panel_y)
    if top_bg_h > 0 then
      gfx.set(0.14, 0.14, 0.15, 1)
      gfx.rect(content_x, 0, content_w, top_bg_h, 1)
    end
    if content_y > panel_y then
      gfx.set(0.10, 0.10, 0.11, 1)
      gfx.rect(content_x, panel_y, content_w, content_y - panel_y, 1)
      gfx.set(0.20, 0.20, 0.22, 1)
      gfx.line(content_x, content_y - 1, content_x + content_w, content_y - 1)
    end
    draw_title_chrome(false)
    draw_main_tabs(false)

    gfx.set(0.10, 0.10, 0.11, 1)
    gfx.rect(0, status_y, gfx.w, status_h, 1)
    gfx.set(0.20, 0.20, 0.22, 1)
    gfx.line(0, status_y, gfx.w, status_y)

    if ui_state.status_text ~= "" and now <= ui_state.status_expires then
      local status_font = (status_h <= 24) and 11 or 12
      local status_text = fit_text_to_width(ui_state.status_text, math.max(20, gfx.w - 16), status_font)
      gfx.setfont(1, "Segoe UI", status_font)
      gfx.set(0.90, 0.92, 0.78, 1)
      gfx.x = 8
      gfx.y = status_y + math.max(2, math.floor((status_h - (status_font + 2)) * 0.5))
      gfx.drawstr(status_text)
    end

    local current_dock = gfx.dock(-1)
    if current_dock ~= ui_state.last_dock_state then
      ui_state.last_dock_state = current_dock
      reaper.SetExtState(PANEL_SECTION, "DOCK_STATE", tostring(current_dock), true)
    end

    gfx.update()
    reaper.defer(loop)
  end

  loop()
end

function OzChordTrack.run_compact_popout_panel()
  local initial_tab = consume_popout_initial_tab()

  local default_popout_x = 220
  local default_popout_y = 160
  local default_popout_w = 560
  local default_popout_h = 620
  local min_popout_w = 260
  local min_popout_h = 180

  local function read_popout_window_geometry()
    local stored_x = tonumber(reaper.GetExtState(PANEL_SECTION, POPOUT_WINDOW_X_KEY))
    local stored_y = tonumber(reaper.GetExtState(PANEL_SECTION, POPOUT_WINDOW_Y_KEY))
    local stored_w = tonumber(reaper.GetExtState(PANEL_SECTION, POPOUT_WINDOW_W_KEY))
    local stored_h = tonumber(reaper.GetExtState(PANEL_SECTION, POPOUT_WINDOW_H_KEY))

    local start_x = stored_x and math.floor(stored_x + 0.5) or default_popout_x
    local start_y = stored_y and math.floor(stored_y + 0.5) or default_popout_y
    local start_w = stored_w and math.max(min_popout_w, math.floor(stored_w + 0.5)) or default_popout_w
    local start_h = stored_h and math.max(min_popout_h, math.floor(stored_h + 0.5)) or default_popout_h
    return start_x, start_y, start_w, start_h
  end

  local function write_popout_window_geometry(x, y, w, h)
    if x == nil or y == nil or w == nil or h == nil then
      return
    end

    reaper.SetExtState(PANEL_SECTION, POPOUT_WINDOW_X_KEY, tostring(math.floor(x + 0.5)), true)
    reaper.SetExtState(PANEL_SECTION, POPOUT_WINDOW_Y_KEY, tostring(math.floor(y + 0.5)), true)
    reaper.SetExtState(PANEL_SECTION, POPOUT_WINDOW_W_KEY, tostring(math.max(min_popout_w, math.floor(w + 0.5))), true)
    reaper.SetExtState(PANEL_SECTION, POPOUT_WINDOW_H_KEY, tostring(math.max(min_popout_h, math.floor(h + 0.5))), true)
  end

  local start_x, start_y, start_w, start_h = read_popout_window_geometry()

  gfx.init("Chord Track Tools", start_w, start_h, 0, start_x, start_y)

  local ui_state = {
    prev_lmb = false,
    status_text = "",
    status_expires = 0,
    active_tab = (initial_tab == "follow") and "snap" or initial_tab,
    tab_scroll = { snap = 0, theme = 0 },
    cut_overlaps_after_snap = get_cut_overlaps_after_snap_enabled(),
    allow_snap_inversions = SnapSettings.get_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, false),
    block_theme = normalize_chord_block_theme(reaper.GetExtState(PANEL_SECTION, "BLOCK_THEME")),
    timeline_calibration_px = get_timeline_calibration_px(),
    new_note_snap_pipeline_mode = get_new_note_snap_pipeline_mode(),
    new_note_snap_mode = get_new_note_snap_mode(),
    last_window_x = start_x,
    last_window_y = start_y,
    last_window_w = start_w,
    last_window_h = start_h,
  }

  local tabs = {
    { id = "snap", label = "Snap" },
    { id = "theme", label = "Theme" },
  }

  local function set_status(text)
    ui_state.status_text = text or ""
    ui_state.status_expires = reaper.time_precise() + 6.0
  end

  local function persist_popout_window_geometry(force)
    local _, window_x, window_y, window_w, window_h = gfx.dock(-1, 0, 0, 0, 0)
    if type(window_x) ~= "number" or type(window_y) ~= "number" or type(window_w) ~= "number" or type(window_h) ~= "number" then
      return
    end

    window_x = math.floor(window_x + 0.5)
    window_y = math.floor(window_y + 0.5)
    window_w = math.max(min_popout_w, math.floor(window_w + 0.5))
    window_h = math.max(min_popout_h, math.floor(window_h + 0.5))

    if force
      or window_x ~= ui_state.last_window_x
      or window_y ~= ui_state.last_window_y
      or window_w ~= ui_state.last_window_w
      or window_h ~= ui_state.last_window_h then
      write_popout_window_geometry(window_x, window_y, window_w, window_h)
      ui_state.last_window_x = window_x
      ui_state.last_window_y = window_y
      ui_state.last_window_w = window_w
      ui_state.last_window_h = window_h
    end
  end

  local function fit_text_to_width(text, max_width, font_size)
    local source = tostring(text or "")
    if source == "" then return "" end

    gfx.setfont(1, "Segoe UI", font_size)
    local width = gfx.measurestr(source)
    if width <= max_width then
      return source
    end

    local trimmed = source
    while #trimmed > 1 do
      trimmed = trimmed:sub(1, #trimmed - 1)
      if gfx.measurestr(trimmed .. "…") <= max_width then
        return trimmed .. "…"
      end
    end

    return ""
  end

  local function apply_block_theme_menu(x, y)
    gfx.x = x
    gfx.y = y
    local menu_result = gfx.showmenu("Auto|Blue|Purple|Neutral")
    if menu_result > 0 then
      local theme = CHORD_BLOCK_THEME_ORDER[menu_result]
      ui_state.block_theme = normalize_chord_block_theme(theme)
      reaper.SetExtState(PANEL_SECTION, "BLOCK_THEME", ui_state.block_theme, true)
      set_status(format_theme_set_status(ui_state.block_theme))
    end
  end

  local function apply_timeline_calibration_menu(x, y)
    local selected_px = show_timeline_calibration_menu(x, y, ui_state.timeline_calibration_px)
    if selected_px == nil then
      return
    end

    ui_state.timeline_calibration_px = set_timeline_calibration_px(selected_px)
    set_status(format_timeline_calibration_status(ui_state.timeline_calibration_px))
  end

  local function apply_snap_selected_midi_menu(x, y)
    gfx.x = x
    gfx.y = y
    local menu_result = gfx.showmenu("Chords + Scales|Chords Only|Scales Only|Melodic Flow")
    if menu_result <= 0 then
      return
    end

    local mode = SNAP_MODE_CHORD_SCALE
    if menu_result == 2 then
      mode = SNAP_MODE_CHORD_ONLY
    elseif menu_result == 3 then
      mode = SNAP_MODE_SCALE_ONLY
    elseif menu_result == 4 then
      mode = SNAP_MODE_MELODIC_FLOW
    end

    local ok, result = snap_selected_midi_internal(mode)
    if not ok then
      set_status(result)
      return
    end

    set_status(format_snap_midi_status(mode, result))
  end

  local function apply_one_click_menu(x, y)
    gfx.x = x
    gfx.y = y
    local menu_result = gfx.showmenu("Chords + Scales|Chords Only|Scales Only|Melodic Flow")
    if menu_result <= 0 then
      return
    end

    local mode = SNAP_MODE_CHORD_SCALE
    if menu_result == 2 then
      mode = SNAP_MODE_CHORD_ONLY
    elseif menu_result == 3 then
      mode = SNAP_MODE_SCALE_ONLY
    elseif menu_result == 4 then
      mode = SNAP_MODE_MELODIC_FLOW
    end

    local ok, result = one_click_setup_sync_snap_internal(mode)
    if not ok then
      set_status(result)
      return
    end

    set_status(format_one_click_status(result))
  end

  local function run_snap_selected_tracks_by_arm_action()
    local ok, result = snap_selected_tracks_by_auto_snap_arm_mode_internal()
    if ok then
      set_status(format_auto_snap_status(result))
    else
      set_status(result)
    end
  end

  local function run_snap_armed_tracks_action()
    local ok, result = snap_armed_tracks_in_assigned_modes_internal()
    if ok then
      set_status(format_snap_armed_status(result))
    else
      set_status(result)
    end
  end

  local function run_snap_selected_tracks_now_action(mode)
    local snap_mode = normalize_snap_mode(mode)
    local ok, result = snap_selected_tracks_in_mode_internal(snap_mode)
    if ok then
      set_status(format_snap_selected_status(snap_mode, result))
    else
      set_status(result)
    end
  end

  local function run_ensure_input_snap_jsfx_action()
    local ok, status = ensure_input_snap_jsfx_installed()
    if ok then
      set_status(status or "Input snap JSFX is installed.")
    else
      set_status(status or "Could not ensure Input snap JSFX is installed.")
    end
  end

  local function run_repair_input_snap_fx_action()
    local previous_override = reaper.GetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY)

    local ok_stop, stop_err = run_script_action_by_file_name(INPUT_MANAGER_STOP_SCRIPT)
    if not ok_stop then
      set_status(stop_err or "Could not stop input snap manager for repair.")
      return
    end

    if previous_override and previous_override ~= "" then
      reaper.SetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_SNAP_MODE_OVERRIDE_KEY, previous_override, false)
    end

    local ok_start, start_err = run_script_action_by_file_name(INPUT_MANAGER_START_SCRIPT)
    if ok_start then
      set_status("Repaired input snap FX instances.")
    else
      set_status(start_err or "Could not restart input snap manager after repair.")
    end
  end

  local function sync_new_note_snap_runtime_for_armed_targets()
    local armed_target_count = count_follow_armed_target_tracks()
    if armed_target_count <= 0 then
      local ok, status = stop_new_note_snap_internal()
      if ok then
        reaper.UpdateArrange()
      end
      return ok, status
    end

    local pipeline_mode = normalize_new_note_snap_pipeline_mode(ui_state.new_note_snap_pipeline_mode)

    if pipeline_mode == NEW_NOTE_SNAP_PIPELINE_PRE then
      clear_input_manager_snap_mode_override()

      local manager_running = reaper.GetExtState(INPUT_MANAGER_SECTION, INPUT_MANAGER_RUN_TOKEN_KEY) ~= ""
      local manager_hint = "Input manager already running."
      if not manager_running then
        local ok_manager, manager_err = run_script_action_by_file_name(INPUT_MANAGER_START_SCRIPT)
        if not ok_manager then
          return false, manager_err
        end
        manager_hint = "Input manager started."
      end

      stop_live_snap_internal()
      reaper.UpdateArrange()
      local status_prefix = manager_running and "New-note snap synced: Pre (per-track Follow modes). " or "New-note snap started: Pre (per-track Follow modes). "
      return true, status_prefix .. manager_hint, manager_running and "already_running" or "started"
    end

    clear_input_manager_snap_mode_override()
    run_script_action_by_file_name(INPUT_MANAGER_STOP_SCRIPT)

    local ok_live, live_status = start_live_snap_internal(ui_state.new_note_snap_mode)
    if ok_live then
      reaper.UpdateArrange()
    end
    return ok_live, live_status
  end

  local function apply_selected_tracks_follow_mode_from_snap_mode(snap_mode, infos)
    local normalized_snap_mode = normalize_snap_mode(snap_mode)
    local auto_mode = snap_mode_to_auto_snap_arm_mode(normalized_snap_mode)
    if not auto_mode then
      set_status("Invalid snap method.")
      return false
    end

    ui_state.new_note_snap_mode = set_new_note_snap_mode_runtime(normalized_snap_mode, ui_state.new_note_snap_pipeline_mode)

    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      set_status("No target tracks selected.")
      return false
    end

    if arming.all_disarmed then
      set_status("Snap method set to " .. snap_mode_to_label(normalized_snap_mode) .. ". Arm selected tracks to start snapping.")
      return true
    end

    local updated = 0
    for i = 1, #(infos or {}) do
      local info = infos[i]
      if info and not info.is_chord_track then
        local current_mode = normalize_auto_snap_arm_mode(get_auto_snap_arm_mode_for_track(info.track))
        if current_mode ~= AUTO_SNAP_ARM_MODE_OFF then
          if set_auto_snap_arm_mode_for_track(info.track, auto_mode) then
            updated = updated + 1
          end
        end
      end
    end

    if updated <= 0 then
      set_status("No armed selected tracks were updated.")
      return false
    end

    local ok_sync, sync_status, sync_detail = sync_new_note_snap_runtime_for_armed_targets()
    if not ok_sync then
      set_status(sync_status or "Could not apply snap method to running snap engine.")
      return false
    end

    local status_text = "Set snap method to " .. snap_mode_to_label(normalized_snap_mode) .. " for " .. tostring(updated) .. " armed selected track(s)."
    if sync_detail == "already_running" then
      status_text = status_text .. " Input manager already running."
    elseif sync_detail == "started" then
      status_text = status_text .. " Input manager started."
    end

    set_status(status_text)
    return true
  end

  local function disarm_all_target_tracks_follow()
    local ok, status = set_auto_snap_arm_mode_for_all_target_tracks(AUTO_SNAP_ARM_MODE_OFF)
    if not ok then
      set_status(normalize_auto_snap_arm_status_text(status))
      return
    end

    local ok_sync, sync_status = sync_new_note_snap_runtime_for_armed_targets()
    if not ok_sync and sync_status and sync_status ~= "" then
      set_status(sync_status)
      return
    end

    set_status("All target tracks disarmed.")
  end

  local function toggle_selected_tracks_follow_arming(infos)
    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      set_status("No target tracks selected.")
      return
    end

    if arming.all_armed then
      local ok, status = set_auto_snap_arm_mode_for_selected_tracks(AUTO_SNAP_ARM_MODE_OFF)
      if not ok then
        set_status(normalize_auto_snap_arm_status_text(status))
        return
      end

      if count_follow_armed_target_tracks() <= 0 then
        local ok_sync, sync_status = sync_new_note_snap_runtime_for_armed_targets()
        if not ok_sync and sync_status and sync_status ~= "" then
          set_status(sync_status)
          return
        end
      else
        reaper.UpdateArrange()
      end

      set_status("Selected tracks disarmed.")
      return
    end

    local auto_mode = snap_mode_to_auto_snap_arm_mode(ui_state.new_note_snap_mode) or AUTO_SNAP_ARM_MODE_CHORDS_SCALES
    local ok, status = set_auto_snap_arm_mode_for_selected_tracks(auto_mode)
    if not ok then
      set_status(normalize_auto_snap_arm_status_text(status))
      return
    end

    local ok_sync, sync_status = sync_new_note_snap_runtime_for_armed_targets()
    if not ok_sync then
      set_status(sync_status or "Could not start new-note snap for armed selected tracks.")
      return
    end

    set_status("Selected tracks armed (" .. snap_mode_to_label(ui_state.new_note_snap_mode) .. ").")
  end

  local function arming_toggle_label_for_selected_tracks(infos)
    local arming = selected_tracks_follow_arming_state(infos)
    if not arming.has_target then
      return "[ ] Arm selected tracks (ready to snap)"
    end
    if arming.all_armed then
      return "[x] Arm selected tracks (ready to snap)"
    end
    if arming.mixed then
      return "[-] Arm selected tracks (ready to snap)"
    end
    return "[ ] Arm selected tracks (ready to snap)"
  end

  local function apply_new_note_pipeline_mode(mode)
    ui_state.new_note_snap_pipeline_mode = set_new_note_snap_pipeline_mode(mode)
    if count_follow_armed_target_tracks() > 0 then
      local _, status = sync_new_note_snap_runtime_for_armed_targets()
      if status and status ~= "" then
        set_status(status)
      end
    end
  end

  local function loop()
    local key = gfx.getchar()
    if key < 0 or key == 27 then
      persist_popout_window_geometry(true)
      return
    end

    local now = reaper.time_precise()
    local lmb_down = (gfx.mouse_cap & 1) == 1
    local click = lmb_down and not ui_state.prev_lmb
    ui_state.prev_lmb = lmb_down

    local current_state = load_state()
    ui_state.cut_overlaps_after_snap = get_cut_overlaps_after_snap_enabled()
    ui_state.allow_snap_inversions = SnapSettings.get_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, false)
    local chord_track = find_track_by_guid(current_state.track_guid)
    local _, selected_infos = selected_tracks_auto_snap_arm_summary(chord_track)
    ui_state.block_theme = normalize_chord_block_theme(reaper.GetExtState(PANEL_SECTION, "BLOCK_THEME"))
    ui_state.timeline_calibration_px = get_timeline_calibration_px()
    ui_state.new_note_snap_pipeline_mode = get_new_note_snap_pipeline_mode()
    ui_state.new_note_snap_mode = get_new_note_snap_mode()

    gfx.set(0.14, 0.14, 0.15, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    local margin = 12
    local x = margin
    local y = margin
    local w = gfx.w - (margin * 2)
    local h = gfx.h - (margin * 2)
    if w < 260 then w = 260 end
    if h < 180 then h = 180 end

    gfx.set(0.10, 0.10, 0.11, 1)
    gfx.rect(x, y, w, h, 1)
    gfx.set(0.20, 0.20, 0.22, 1)
    gfx.rect(x, y, w, h, 0)

    gfx.setfont(1, "Segoe UI", 19)
    gfx.set(0.96, 0.96, 0.96, 1)
    gfx.x = x + 8
    gfx.y = y + 4
    gfx.drawstr("Chord Track Tools")

    local close_size = 20
    local close_x = x + w - close_size - 8
    local close_y = y + 4
    if draw_icon_button(close_x, close_y, close_size, "X", click) then
      persist_popout_window_geometry(true)
      return
    end

    local tab_y = y + 32
    local tab_h = 26
    local tab_gap = 6
    local tab_count = #tabs
    local tab_w = math.floor((w - ((tab_count - 1) * tab_gap) - 2) / tab_count)
    local tab_x = x + 1

    for i = 1, tab_count do
      local tab = tabs[i]
      local selected = (ui_state.active_tab == tab.id)

      gfx.set(selected and 0.28 or 0.18, selected and 0.28 or 0.18, selected and 0.33 or 0.20, 1)
      gfx.rect(tab_x, tab_y, tab_w, tab_h, 1)
      gfx.set(0.10, 0.10, 0.11, 1)
      gfx.rect(tab_x, tab_y, tab_w, tab_h, 0)

      gfx.setfont(1, "Segoe UI", 13)
      gfx.set(selected and 0.97 or 0.84, selected and 0.97 or 0.84, selected and 0.99 or 0.86, 1)
      local tab_label = fit_text_to_width(tab.label, tab_w - 10, 13)
      local label_w, label_h = gfx.measurestr(tab_label)
      gfx.x = tab_x + math.max(3, (tab_w - label_w) * 0.5)
      gfx.y = tab_y + math.max(3, (tab_h - label_h) * 0.5)
      gfx.drawstr(tab_label)

      if click and point_in_rect(gfx.mouse_x, gfx.mouse_y, tab_x, tab_y, tab_w, tab_h) then
        ui_state.active_tab = tab.id
      end

      tab_x = tab_x + tab_w + tab_gap
    end

    local content_x = x + 1
    local content_y = tab_y + tab_h + 6
    local content_w = w - 2
    local content_h = (y + h) - content_y - 12
    if content_h < 90 then content_h = 90 end

    local dense = (content_w < 560) or (content_h < 320)
    local very_dense = (content_w < 430) or (content_h < 250)
    local heading_font = very_dense and 14 or (dense and 15 or 17)
    local body_font = very_dense and 12 or (dense and 13 or 14)
    local meta_font = very_dense and 11 or (dense and 12 or 13)
    local label_padding = very_dense and 5 or (dense and 6 or 8)
    local button_h = very_dense and 24 or (dense and 26 or 30)
    local button_row_gap = very_dense and 3 or (dense and 4 or 6)
    local button_font = very_dense and 12 or (dense and 13 or 14)
    local spacer_h = very_dense and 6 or (dense and 7 or 8)
    local wheel_step = very_dense and 18 or (dense and 22 or 28)

    gfx.set(0.08, 0.08, 0.09, 1)
    gfx.rect(content_x, content_y, content_w, content_h, 1)

    local function selected_target_mode_summary()
      local first_mode = nil
      local mixed = false
      local has_target = false
      for i = 1, #selected_infos do
        local info = selected_infos[i]
        if not info.is_chord_track then
          has_target = true
          if not first_mode then
            first_mode = info.auto_snap_arm_mode
          elseif first_mode ~= info.auto_snap_arm_mode then
            mixed = true
            break
          end
        end
      end

      if not has_target then
        return nil, "No target tracks selected"
      end
      if mixed then
        return nil, "Mixed"
      end
      return first_mode, auto_snap_arm_mode_to_label(first_mode)
    end

    local function apply_selected_mode(mode)
      local mapped_snap_mode = auto_snap_arm_mode_to_snap_mode(mode) or normalize_snap_mode(mode)
      if not mapped_snap_mode then
        set_status("Invalid snap method.")
        return
      end

      apply_selected_tracks_follow_mode_from_snap_mode(mapped_snap_mode, selected_infos)
    end

    local function render_tab(do_draw)
      local scroll = ui_state.tab_scroll[ui_state.active_tab] or 0
      local virtual_y = 8
      local area_bottom = content_y + content_h

      local function row(height, painter)
        local draw_y = content_y + virtual_y - scroll
        if do_draw and draw_y >= content_y and draw_y < area_bottom then
          painter(draw_y)
        end
        virtual_y = virtual_y + height
      end

      local function spacer(height)
        row(height, function() end)
      end

      local function label(text, size, r, g, b)
        local font_size = size or body_font
        local display_text = fit_text_to_width(text, content_w - 24, font_size)
        row(font_size + label_padding, function(draw_y)
          gfx.setfont(1, "Segoe UI", font_size)
          gfx.set(r or 0.86, g or 0.86, b or 0.90, 1)
          gfx.x = content_x + 10
          gfx.y = draw_y
          gfx.drawstr(display_text)
        end)
      end

      local function button_row(text, callback)
        row(button_h + button_row_gap, function(draw_y)
          gfx.setfont(1, "Segoe UI", button_font)
          local button_text = fit_text_to_width(text, content_w - 26, button_font)
          local can_click = click and do_draw and point_in_rect(gfx.mouse_x, gfx.mouse_y, content_x, content_y, content_w, content_h)
          if draw_button(content_x + 8, draw_y, content_w - 16, button_h, button_text, can_click) then
            callback(draw_y)
          end
        end)
      end

      local function menu_button_row(text, callback)
        row(button_h + button_row_gap, function(draw_y)
          gfx.setfont(1, "Segoe UI", button_font)
          local button_text = fit_text_to_width(text, content_w - 26, button_font)
          local can_click = click and do_draw and point_in_rect(gfx.mouse_x, gfx.mouse_y, content_x, content_y, content_w, content_h)
          if draw_button(content_x + 8, draw_y, content_w - 16, button_h, button_text, can_click) then
            callback(content_x + 16, draw_y + button_h + 2)
          end
        end)
      end

      if ui_state.active_tab == "snap" then
        local selected_mode, mode_text = selected_target_mode_summary()
        local pipeline_mode = normalize_new_note_snap_pipeline_mode(ui_state.new_note_snap_pipeline_mode)
        local selected_snap_mode = normalize_snap_mode(ui_state.new_note_snap_mode)
        local selected_mode_snap = selected_mode and auto_snap_arm_mode_to_snap_mode(selected_mode) or nil
        if selected_snap_mode == SNAP_MODE_MELODIC_FLOW and selected_mode_snap == SNAP_MODE_CHORD_SCALE then
          selected_mode_snap = SNAP_MODE_MELODIC_FLOW
        end
        local effective_snap_mode = normalize_snap_mode(selected_mode_snap or selected_snap_mode)

        local runtime_running = false
        local runtime_label = ""
        local runtime_detail = ""
        local runtime_r, runtime_g, runtime_b = 0.84, 0.84, 0.88

        if pipeline_mode == NEW_NOTE_SNAP_PIPELINE_PRE then
          local manager_running, manager_status = get_input_manager_runtime_status()
          runtime_running = manager_running
          runtime_label = manager_running and "[x] Pre Snap Running" or "[ ] Pre Snap Running"
          runtime_detail = "Manager: " .. tostring(manager_status or "")
          if manager_running then
            runtime_r, runtime_g, runtime_b = 0.84, 0.90, 0.84
          end
        else
          local runtime = describe_live_runtime_status()
          runtime_running = runtime.running
          runtime_label = runtime.running and "[x] Post Snap Running" or "[ ] Post Snap Running"
          runtime_detail = runtime.detail or ""
          runtime_r = runtime.detail_r or 0.84
          runtime_g = runtime.detail_g or 0.84
          runtime_b = runtime.detail_b or 0.88
        end

        label("Selected Track Snap", heading_font, 0.95, 0.95, 0.98)
        label("Selected tracks: " .. mode_text, body_font)
        button_row(arming_toggle_label_for_selected_tracks(selected_infos), function() toggle_selected_tracks_follow_arming(selected_infos) end)
        button_row("UnArm All", disarm_all_target_tracks_follow)
        button_row("Snap selected tracks now (Follow mode)", run_snap_selected_tracks_by_arm_action)

        spacer(spacer_h)
        label("Pre/Post Recording", heading_font, 0.95, 0.95, 0.98)
        button_row(
          ((pipeline_mode == NEW_NOTE_SNAP_PIPELINE_PRE) and "(●) " or "(○) ") .. "Pre Recording (Input JSFX)",
          function() apply_new_note_pipeline_mode(NEW_NOTE_SNAP_PIPELINE_PRE) end
        )
        button_row(
          ((pipeline_mode == NEW_NOTE_SNAP_PIPELINE_POST) and "(●) " or "(○) ") .. "Post Recording (Live engine)",
          function() apply_new_note_pipeline_mode(NEW_NOTE_SNAP_PIPELINE_POST) end
        )

        spacer(spacer_h)
        label("Snap Method", heading_font, 0.95, 0.95, 0.98)

        local modes = {
          { id = AUTO_SNAP_ARM_MODE_CHORDS, label = "Chords" },
          { id = AUTO_SNAP_ARM_MODE_SCALES, label = "Scales" },
          { id = AUTO_SNAP_ARM_MODE_CHORDS_SCALES, label = "Chords + Scales" },
          { id = SNAP_MODE_MELODIC_FLOW, label = "Melodic Flow" },
        }

        for i = 1, #modes do
          local mode = modes[i]
          local mode_snap = auto_snap_arm_mode_to_snap_mode(mode.id) or normalize_snap_mode(mode.id)
          local marker = (mode_snap == effective_snap_mode) and "(●) " or "(○) "
          button_row(marker .. mode.label, function() apply_selected_mode(mode.id) end)
        end

        spacer(spacer_h)
        label("Runtime", heading_font, 0.95, 0.95, 0.98)
        if runtime_running then
          label(runtime_label, body_font, 0.84, 0.90, 0.84)
        else
          label(runtime_label, body_font, 0.84, 0.84, 0.88)
        end
        label(runtime_detail, meta_font, runtime_r, runtime_g, runtime_b)
        label("Current method: " .. snap_mode_to_label(effective_snap_mode), meta_font, 0.80, 0.80, 0.84)

        spacer(spacer_h)
        label("Voicing", heading_font, 0.95, 0.95, 0.98)
        button_row((ui_state.allow_snap_inversions and "[x] " or "[ ] ") .. "Allow snap inversions", function()
          local next_value = not ui_state.allow_snap_inversions
          SnapSettings.set_proj_bool(0, EXT_SECTION, ALLOW_SNAP_INVERSIONS_KEY, next_value)
          ui_state.allow_snap_inversions = next_value
          set_status(SnapSettings.toggle_status("Allow snap inversions", next_value))
        end)

        spacer(spacer_h)
        label("Input Snap Utilities", heading_font, 0.95, 0.95, 0.98)
        button_row("Ensure input snap JSFX installed", run_ensure_input_snap_jsfx_action)
        button_row("Repair input snap FX instances", run_repair_input_snap_fx_action)

      elseif ui_state.active_tab == "theme" then
        local resolved = resolve_chord_block_theme(ui_state.block_theme)

        label("Chord Block Theme", heading_font, 0.95, 0.95, 0.98)
        label("Current: " .. chord_block_theme_to_display_label(ui_state.block_theme), body_font)
        label("Resolved: " .. chord_block_theme_to_label(resolved), meta_font, 0.80, 0.80, 0.84)

        local themes = {
          CHORD_BLOCK_THEME_AUTO,
          CHORD_BLOCK_THEME_BLUE,
          CHORD_BLOCK_THEME_PURPLE,
          CHORD_BLOCK_THEME_NEUTRAL,
        }
        for i = 1, #themes do
          local theme = themes[i]
          local marker = (ui_state.block_theme == theme) and "(●) " or "(○) "
          button_row(marker .. chord_block_theme_to_label(theme), function()
            ui_state.block_theme = normalize_chord_block_theme(theme)
            reaper.SetExtState(PANEL_SECTION, "BLOCK_THEME", ui_state.block_theme, true)
            set_status(format_theme_set_status(ui_state.block_theme))
          end)
        end

        spacer(spacer_h)
        label("Timeline Align Offset: " .. timeline_calibration_to_label(ui_state.timeline_calibration_px), body_font)
        menu_button_row("Set timeline align offset (coarse/fine) ▼", apply_timeline_calibration_menu)

        spacer(spacer_h)
        menu_button_row("Theme menu ▼", apply_block_theme_menu)
      end

      return virtual_y + 8
    end

    local content_total = render_tab(false)
    local max_scroll = math.max(0, content_total - content_h)

    local wheel_delta = gfx.mouse_wheel
    gfx.mouse_wheel = 0
    if wheel_delta ~= 0 and point_in_rect(gfx.mouse_x, gfx.mouse_y, content_x, content_y, content_w, content_h) then
      local scroll = (ui_state.tab_scroll[ui_state.active_tab] or 0) - ((wheel_delta / 120) * wheel_step)
      ui_state.tab_scroll[ui_state.active_tab] = scroll
    end

    if ui_state.tab_scroll[ui_state.active_tab] == nil then
      ui_state.tab_scroll[ui_state.active_tab] = 0
    end
    if ui_state.tab_scroll[ui_state.active_tab] < 0 then
      ui_state.tab_scroll[ui_state.active_tab] = 0
    end
    if ui_state.tab_scroll[ui_state.active_tab] > max_scroll then
      ui_state.tab_scroll[ui_state.active_tab] = max_scroll
    end

    render_tab(true)

    if max_scroll > 0 then
      local scroll = ui_state.tab_scroll[ui_state.active_tab] or 0
      local track_x = content_x + content_w - 8
      local track_y = content_y + 6
      local track_h = content_h - 12
      gfx.set(0.16, 0.16, 0.17, 1)
      gfx.rect(track_x, track_y, 4, track_h, 1)

      local thumb_h = math.max(24, (content_h / content_total) * track_h)
      local thumb_y = track_y + ((scroll / max_scroll) * (track_h - thumb_h))
      gfx.set(0.52, 0.52, 0.57, 1)
      gfx.rect(track_x, thumb_y, 4, thumb_h, 1)
    end

    if ui_state.status_text ~= "" and now <= ui_state.status_expires then
      gfx.set(0.90, 0.92, 0.78, 1)
      gfx.x = x + 8
      gfx.y = y + h - 18
      gfx.drawstr(ui_state.status_text)
    end

    persist_popout_window_geometry(false)

    gfx.update()
    reaper.defer(loop)
  end

  loop()
end

function OzChordTrack.stop_live_snap()
  local _, status = stop_live_snap_internal()
  message(status)
end

return OzChordTrack

local SnapSettings = {}

function SnapSettings.get_proj_bool(proj, section, key, default_value)
  local _, stored = reaper.GetProjExtState(proj or 0, section, key)
  if not stored or stored == "" then
    return default_value == true
  end

  stored = tostring(stored):lower()
  return stored == "1" or stored == "true" or stored == "yes" or stored == "on"
end

function SnapSettings.set_proj_bool(proj, section, key, enabled)
  reaper.SetProjExtState(proj or 0, section, key, enabled and "1" or "0")
end

function SnapSettings.mode_requires_scale(mode, scale_only_mode, chord_scale_mode)
  return mode == scale_only_mode or mode == chord_scale_mode
end

function SnapSettings.toggle_status(label, enabled)
  if enabled then
    return label .. " enabled."
  end
  return label .. " disabled."
end

return SnapSettings

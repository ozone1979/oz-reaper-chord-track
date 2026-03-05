local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""

local function message(text)
  reaper.MB(tostring(text or ""), "Oz Reaper Chord Track", 0)
end

if not reaper.AddRemoveReaScript or not reaper.EnumerateFiles then
  message("This REAPER version does not support action cleanup helpers.")
  return
end

local function path_join(base, relative)
  local left = tostring(base or "")
  local right = tostring(relative or "")
  if left == "" then return right end
  if right == "" then return left end

  local sep = left:find("\\", 1, true) and "\\" or "/"
  left = left:gsub("[/\\]+$", "")
  right = right:gsub("^[/\\]+", "")
  if sep == "\\" then
    right = right:gsub("/", "\\")
  else
    right = right:gsub("\\", "/")
  end
  return left .. sep .. right
end

local actions_dir = path_join(script_path, "actions")
local action_files = {}

local idx = 0
while true do
  local name = reaper.EnumerateFiles(actions_dir, idx)
  if not name then break end

  if name:match("^Oz Chord Track %- .+%.lua$") then
    action_files[#action_files + 1] = name
  end

  idx = idx + 1
end

if #action_files == 0 then
  message("No action scripts found in actions folder.")
  return
end

table.sort(action_files)

local removed = 0
local not_present = 0
for i = 1, #action_files do
  local name = action_files[i]
  local old_top_level_path = path_join(script_path, name)
  local command_id = reaper.AddRemoveReaScript(false, 0, old_top_level_path, true)
  if type(command_id) == "number" and command_id > 0 then
    removed = removed + 1
  else
    not_present = not_present + 1
  end
end

message(
  "Removed stale top-level action registrations: " .. tostring(removed) ..
  "\nAlready absent: " .. tostring(not_present) ..
  "\n\nNext: run 'Oz Chord Track - Register actions from actions folder' to ensure canonical actions are registered."
)

local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""

local function message(text)
  reaper.MB(tostring(text or ""), "Oz Reaper Chord Track", 0)
end

if not reaper.AddRemoveReaScript or not reaper.EnumerateFiles then
  message("This REAPER version does not support action registration helpers.")
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
local files = {}

local idx = 0
while true do
  local name = reaper.EnumerateFiles(actions_dir, idx)
  if not name then break end

  if name:match("^Oz Chord Track %- .+%.lua$") then
    files[#files + 1] = name
  end

  idx = idx + 1
end

if #files == 0 then
  message("No action scripts found in actions folder.")
  return
end

table.sort(files)

local added = 0
local failed = {}
for i = 1, #files do
  local name = files[i]
  local full_path = path_join(actions_dir, name)
  local command_id = reaper.AddRemoveReaScript(true, 0, full_path, true)
  if type(command_id) == "number" and command_id > 0 then
    added = added + 1
  else
    failed[#failed + 1] = name
  end
end

if #failed > 0 then
  message("Registered " .. tostring(added) .. " action(s). Failed: " .. tostring(#failed) .. ".\n\nFirst failed: " .. tostring(failed[1]))
  return
end

message("Registered " .. tostring(added) .. " action(s) from actions folder.")

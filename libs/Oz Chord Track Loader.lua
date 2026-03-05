local Loader = {}

function Loader.get_script_directory(source)
  local src = tostring(source or debug.getinfo(2, "S").source or "")
  src = src:gsub("^@", "")
  return src:match("^(.*[\\/])") or ""
end

function Loader.path_join(base, relative)
  local base_path = tostring(base or "")
  local rel_path = tostring(relative or "")
  if base_path == "" then return rel_path end
  if rel_path == "" then return base_path end

  local sep = base_path:find("\\", 1, true) and "\\" or "/"
  local left = base_path:gsub("[/\\]+$", "")
  local right = rel_path:gsub("^[/\\]+", "")
  if sep == "\\" then
    right = right:gsub("/", "\\")
  else
    right = right:gsub("\\", "/")
  end

  return left .. sep .. right
end

function Loader.resolve_project_root(script_dir)
  local dir = tostring(script_dir or "")
  if dir == "" then return "" end

  local use_backslash = dir:find("\\", 1, true) ~= nil
  local normalized = dir:gsub("\\", "/")
  normalized = normalized:gsub("/+$", "") .. "/"

  if normalized:sub(-6) == "/libs/" then
    normalized = normalized:sub(1, #normalized - 5)
  elseif normalized:sub(-9) == "/actions/" then
    normalized = normalized:sub(1, #normalized - 8)
  end

  if use_backslash then
    return normalized:gsub("/", "\\")
  end
  return normalized
end

function Loader.project_root(script_dir)
  return Loader.resolve_project_root(script_dir or Loader.get_script_directory())
end

function Loader.load_core(script_dir)
  local root = Loader.project_root(script_dir)
  return dofile(Loader.path_join(root, "libs/Oz Chord Track Core.lua"))
end

function Loader.run_internal(script_dir, relative_file)
  local root = Loader.project_root(script_dir)
  local full_path = Loader.path_join(Loader.path_join(root, "libs"), relative_file)

  local chunk, load_err = loadfile(full_path)
  if type(chunk) ~= "function" then
    return false, "Could not load internal script: " .. tostring(relative_file or "") .. " (" .. tostring(load_err or "unknown error") .. ")"
  end

  local ok, runtime_err = pcall(chunk)
  if not ok then
    return false, "Could not run internal script: " .. tostring(relative_file or "") .. " (" .. tostring(runtime_err or "unknown error") .. ")"
  end

  return true, nil
end

return Loader

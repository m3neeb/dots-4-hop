--!nonstrict
-- Long-lived scanner + file-operation worker.
--   * polls the desktop folder and publishes the item list through noctalia.state
--   * executes commands (open / rename / trash / ...) sent by the layers via state "cmd"
-- Doing file work here (not in the menu layer) matters: the menu layer is destroyed every
-- time it is hidden, which would drop the callbacks of any still-running process.

local TYPES = {}
local function reg(list, icon, glyph)
  for _, e in ipairs(list) do TYPES[e] = { icon = icon, glyph = glyph } end
end
reg({ "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "tif", "tiff" }, "image-x-generic", "photo")
reg({ "mp3", "flac", "ogg", "opus", "wav", "m4a", "aac" }, "audio-x-generic", "music")
reg({ "mp4", "mkv", "webm", "mov", "avi", "m4v" }, "video-x-generic", "video")
reg({ "pdf" }, "application-pdf", "file-type-pdf")
reg({ "zip", "tar", "gz", "xz", "zst", "bz2", "7z", "rar" }, "package-x-generic", "file-zip")
reg({ "txt", "md", "log", "rst" }, "text-x-generic", "file-text")
reg({ "sh", "bash", "zsh", "fish" }, "text-x-script", "terminal-2")
reg({ "doc", "docx", "odt", "rtf" }, "x-office-document", "file-text")
reg({ "xls", "xlsx", "ods", "csv" }, "x-office-spreadsheet", "table")
reg({ "ppt", "pptx", "odp" }, "x-office-presentation", "presentation")
reg({ "iso", "img" }, "media-optical", "disc")
reg({ "appimage" }, "application-x-executable", "app-window")

local IMAGE = { png = true, jpg = true, jpeg = true, gif = true, webp = true, bmp = true, svg = true, avif = true }

local cfg = {}
local iconCache = {}
local lastSig = nil
local lastDir = nil
local lastNonce = nil

-- ── config ─────────────────────────────────────────────────────────────

local function loadConfig()
  local dir = noctalia.expandPath(noctalia.getConfig("directory") or "~/Desktop")
  dir = (string.gsub(dir, "/+$", ""))
  if dir == "" then dir = "/" end
  cfg.dir = dir
  cfg.hidden = noctalia.getConfig("show_hidden") == true
  cfg.sort = noctalia.getConfig("sort") or "name"
  cfg.foldersFirst = noctalia.getConfig("folders_first") ~= false
  cfg.thumbs = noctalia.getConfig("thumbnails") ~= false
  cfg.thumbMax = (noctalia.getConfig("thumbnail_max_mb") or 8) * 1048576
  cfg.iconSize = noctalia.getConfig("icon_size") or 48
  iconCache = {}
  lastSig = nil
end

-- ── helpers ────────────────────────────────────────────────────────────

local function extOf(name)
  local e = string.match(name, "%.([^%.]+)$")
  return e and string.lower(e) or ""
end

local function dirOf(path)
  return string.match(path, "^(.*)/[^/]*$") or "."
end

local function shq(s)
  return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function iconPath(name)
  local cached = iconCache[name]
  if cached ~= nil then return cached or nil end
  local p = noctalia.appIconPath(name, cfg.iconSize)
  iconCache[name] = p or false
  return p
end

local function fail(titleKey, detail)
  noctalia.notifyError(noctalia.tr(titleKey), detail)
end

local function validName(name)
  if name == nil or name == "" or name == "." or name == ".." or string.find(name, "/", 1, true) then
    return false
  end
  return true
end

-- Minimal .desktop reader: Name, Icon, Exec from the [Desktop Entry] group.
local function parseDesktop(path)
  local raw = noctalia.readFile(path)
  if not raw then return nil end
  local inEntry, name, icon, exec, terminal, wd = false, nil, nil, nil, nil, nil
  for line in string.gmatch(raw, "[^\r\n]+") do
    local group = string.match(line, "^%[(.-)%]%s*$")
    if group then
      inEntry = (group == "Desktop Entry")
    elseif inEntry then
      local k, v = string.match(line, "^([%w%-_]+)%s*=%s*(.*)$")
      if k == "Name" then name = v
      elseif k == "Icon" then icon = v
      elseif k == "Exec" then exec = v
      elseif k == "Terminal" then terminal = (v == "true")
      elseif k == "Path" then wd = v end
    end
  end
  return name, icon, exec, terminal, wd
end

local function makeItem(name, path, info)
  local e = extOf(name)
  local it = {
    name = name, path = path, label = name,
    isDir = info.isDir == true, size = info.size or 0, mtime = info.mtime or 0,
    kind = "file", glyph = "file",
  }
  if it.isDir then
    it.kind, it.glyph = "dir", "folder"
    it.iconPath = iconPath("folder") or iconPath("inode-directory")
  elseif e == "desktop" then
    it.kind, it.glyph = "launcher", "app-window"
    local nm, icon, exec, terminal, wd = parseDesktop(path)
    if nm and nm ~= "" then it.label = nm end
    it.exec, it.terminal, it.cwd = exec, terminal == true, wd
    it.iconPath = (icon and iconPath(icon)) or iconPath("application-x-executable")
  else
    local spec = TYPES[e]
    local iconName = "text-x-generic"
    if spec then iconName, it.glyph = spec.icon, spec.glyph end
    it.iconPath = iconPath(iconName) or iconPath("text-x-generic") or iconPath("unknown")
    if IMAGE[e] and cfg.thumbs and it.size <= cfg.thumbMax then it.thumb = path end
  end
  return it
end

local function sortItems(items)
  table.sort(items, function(a, b)
    if cfg.foldersFirst and a.isDir ~= b.isDir then return a.isDir end
    if cfg.sort == "modified" then
      if a.mtime ~= b.mtime then return a.mtime > b.mtime end
    elseif cfg.sort == "type" then
      local ea, eb = extOf(a.name), extOf(b.name)
      if ea ~= eb then return ea < eb end
    end
    local la, lb = string.lower(a.label), string.lower(b.label)
    if la ~= lb then return la < lb end
    return a.name < b.name
  end)
end

-- ── scanning ───────────────────────────────────────────────────────────

local function scan(force)
  if lastDir ~= cfg.dir then
    lastDir = cfg.dir
    noctalia.state.set("dir", cfg.dir)
  end
  local names, err = noctalia.listDir(cfg.dir)
  if not names then
    if lastSig ~= "!missing" then
      noctalia.log("cannot list " .. cfg.dir .. ": " .. tostring(err))
      lastSig = "!missing"
      noctalia.state.set("items", {})
    end
    return
  end

  table.sort(names)
  local infos, sig = {}, {}
  for _, name in ipairs(names) do
    if name ~= "." and name ~= ".." and (cfg.hidden or string.sub(name, 1, 1) ~= ".") then
      local path = cfg.dir .. "/" .. name
      local info = noctalia.fileInfo(path)
      if info then
        infos[#infos + 1] = { name = name, path = path, info = info }
        sig[#sig + 1] = name .. "|" .. tostring(info.mtime) .. "|" .. tostring(info.size)
      end
    end
  end

  local joined = table.concat(sig, "\n")
  if not force and joined == lastSig then return end
  lastSig = joined

  local items = {}
  for _, f in ipairs(infos) do
    items[#items + 1] = makeItem(f.name, f.path, f.info)
  end
  sortItems(items)
  noctalia.log("desktop-icons: publishing " .. #items .. " items" .. (force and " (forced)" or " (folder changed)"))
  noctalia.state.set("items", items)
end

-- ── commands ───────────────────────────────────────────────────────────

local function trashPath(c)
  local argv
  if noctalia.commandExists("gio") then
    argv = { "gio", "trash", c.path }
  elseif noctalia.commandExists("trash-put") then
    argv = { "trash-put", c.path }
  else
    fail("err.no_trash", "gio / trash-cli")
    return
  end
  noctalia.runAsync(argv, function(res)
    if res.exitCode ~= 0 then fail("err.trash_failed", res.stderr) end
    scan(true)
  end)
end

local function renamePath(c)
  local name = noctalia.string.trim(c.name or "")
  if not validName(name) then return fail("err.invalid_name", name) end
  local target = dirOf(c.path) .. "/" .. name
  if target == c.path then return end
  if noctalia.fileExists(target) then return fail("err.exists", name) end
  noctalia.runAsync({ "mv", "-n", "--", c.path, target }, function(res)
    if res.exitCode ~= 0 then fail("err.rename_failed", res.stderr) end
    scan(true)
  end)
end

local function create(c, folder)
  local name = noctalia.string.trim(c.name or "")
  if not validName(name) then return fail("err.invalid_name", name) end
  local target = cfg.dir .. "/" .. name
  if noctalia.fileExists(target) then return fail("err.exists", name) end
  local ok, why
  if folder then ok, why = noctalia.mkdirAll(target) else ok, why = noctalia.writeFile(target, "") end
  if not ok then return fail("err.create_failed", tostring(why)) end
  scan(true)
end

local function handleNow(c)
  if type(c) ~= "table" or c.nonce == lastNonce then return end
  lastNonce = c.nonce
  if c.op == "trash" then trashPath(c)
  elseif c.op == "rename" then renamePath(c)
  elseif c.op == "mkdir" then create(c, true)
  elseif c.op == "touch" then create(c, false)
  elseif c.op == "terminal" then
    noctalia.runInTerminal("cd " .. shq(c.path) .. " && exec \"${SHELL:-sh}\"")
  elseif c.op == "run" then
    noctalia.runAsync({ "sh", "-c", c.command })
  elseif c.op == "refresh" then
    scan(true)
  end
end

-- ── lifecycle ──────────────────────────────────────────────────────────
-- Everything that touches the disk runs under pcall: files come and go behind our back, and an
-- error here must be logged, not allowed to take the whole service down.

local function safely(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then noctalia.log(label .. " failed: " .. tostring(err)) end
end

local function handle(c) safely("command", handleNow, c) end

loadConfig()
noctalia.setUpdateInterval(2000)
noctalia.state.watch("cmd", handle)
noctalia.state.watch("menu_close", function() noctalia.layer.hide("menu") end)
safely("scan", scan, true)

function update()
  safely("scan", scan, false)
end

function onConfigChanged()
  loadConfig()
  safely("scan", scan, true)
end

-- noctalia msg plugin you/desktop-icons:scanner all refresh
function onIpc(event)
  if event == "refresh" then safely("scan", scan, true) end
end

--!nonstrict
-- Shared by the desktop and menu layers: menu contents, sizes and small helpers.

local M = {}

M.WIDTH    = 232
M.ROW_H    = 32
M.SEP_H    = 10
M.PAD      = 6
M.DIALOG_W = 340
M.DIALOG_H = 152

local counter = 0

function M.clamp(v, lo, hi)
  if hi < lo then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Unique id for each command, so identical consecutive commands still trigger state.watch.
function M.nonce()
  counter = counter + 1
  return tostring(noctalia.nowMs()) .. "-" .. counter .. "-" .. math.random(1, 1000000)
end

function M.outputSize(name)
  for _, o in ipairs(noctalia.outputs()) do
    if o.name == name then return o.width, o.height end
  end
  return 1920, 1080
end

function M.shq(s)
  return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local have = {}
local function exists(cmd)
  if have[cmd] == nil then have[cmd] = noctalia.commandExists(cmd) == true end
  return have[cmd]
end

-- Opens an item straight from whichever entry the click happened in. Going through the scanner
-- service (a state hop) and through xdg-open (a shell script that probes the desktop environment
-- before it launches anything) both added visible delay, so neither is used any more.
function M.openItem(it)
  local t0 = noctalia.nowMs()
  local cwd = (it.cwd and it.cwd ~= "") and ("cd " .. M.shq(it.cwd) .. " && ") or ""
  if it.kind == "launcher" and it.exec and it.exec ~= "" then
    local cmd = string.gsub(it.exec, "%%%%", "\1")                 -- keep literal %% safe
    cmd = string.gsub(cmd, "%%[fFuUdDnNickvm]", "")                 -- drop field codes (%u, %F, ...)
    cmd = noctalia.string.trim((string.gsub(cmd, "\1", "%%")))
    if it.terminal then
      noctalia.runInTerminal(cwd .. cmd)
    else
      noctalia.runAsync({ "sh", "-c", cwd .. "exec " .. cmd })
    end
  elseif it.kind == "launcher" then
    noctalia.runAsync({ "gio", "launch", it.path })
  elseif exists("gio") then
    noctalia.runAsync({ "gio", "open", it.path })
  else
    noctalia.runAsync({ "xdg-open", it.path })
  end
  noctalia.log(string.format("desktop-icons: opened %s (spawned in %d ms)", it.path, noctalia.nowMs() - t0))
end

-- "New Folder", "New Folder (2)", ...
function M.uniqueName(dir, base, ext)
  local name = base .. ext
  local n = 2
  while noctalia.fileExists(dir .. "/" .. name) and n < 500 do
    name = string.format("%s (%d)%s", base, n, ext)
    n = n + 1
  end
  return name
end

-- "Label = command" lines from the extra_menu setting.
function M.customEntries()
  local out = {}
  local lines = noctalia.getConfig("extra_menu")
  if type(lines) ~= "table" then return out end
  for _, line in ipairs(lines) do
    local label, command = string.match(line, "^%s*(.-)%s*=%s*(.-)%s*$")
    if label and label ~= "" and command and command ~= "" then
      out[#out + 1] = { label = label, command = command }
    end
  end
  return out
end

-- Menu model. kind = "item" (right click on an icon) or "desktop" (right click on empty space).
function M.entries(kind, item)
  local list = {}
  local function add(id, key, glyph)
    list[#list + 1] = { id = id, label = noctalia.tr(key), glyph = glyph }
  end
  local function sep() list[#list + 1] = { sep = true } end

  if kind == "item" and item then
    add("open", "menu.open", "external-link")
    if item.isDir then add("terminal", "menu.terminal_here", "terminal-2") end
    add("copy_path", "menu.copy_path", "copy")
    sep()
    add("rename", "menu.rename", "pencil")
    add("trash", "menu.trash", "trash")
  else
    add("new_folder", "menu.new_folder", "folder-plus")
    add("new_file", "menu.new_file", "file-plus")
    sep()
    add("open_dir", "menu.open_desktop", "folder-open")
    add("terminal_dir", "menu.terminal_here", "terminal-2")
    add("refresh", "menu.refresh", "refresh")
    local custom = M.customEntries()
    if #custom > 0 then
      sep()
      for i, c in ipairs(custom) do
        list[#list + 1] = { id = "custom:" .. i, label = c.label, glyph = "bolt", command = c.command }
      end
    end
    sep()
    add("settings", "menu.settings", "adjustments")
  end
  return list
end

-- Pixel size the menu layer needs for a list of entries (a little generous on purpose).
function M.size(list)
  local h = M.PAD * 2 + 6
  for _, e in ipairs(list) do
    h = h + (e.sep and M.SEP_H or M.ROW_H)
  end
  return M.WIDTH, h
end

return M

--!nonstrict
-- Finds installed applications and publishes them as state "apps" (the list) and "icons" (name -> path).
--
-- There is no host API for "list installed apps", so the .desktop files are read here, but NOT by the
-- script VM: one `find | awk` process lists and parses every file in a single pass (tens of ms) and
-- writes a TSV, which is parsed in one go. The list is therefore available as soon as that process
-- exits. Icons are resolved afterwards in small time slices and streamed to the panel, so a slow
-- icon theme can never delay (or blow the CPU budget of) the app list itself.

local U = require("./lib/util.luau")

local TICK_ICONS = 20          -- ms between icon slices while icons are pending
local TICK_IDLE = 30000        -- ms between "did an applications folder change?" checks
local SLICE_MS = 6             -- wall-clock budget per icon slice
local PUBLISH_EVERY = 30       -- publish the icon map after this many newly resolved icons
local ICON_PX = 32

-- $1 $2: preferred locales, $3: output file, rest: application folders in precedence order.
local SCRIPT = [==[
L1="$1"; L2="$2"; OUT="$3"; shift 3
TMP="$OUT.tmp"
{
  for d in "$@"; do
    [ -d "$d" ] || continue
    find -L "$d" -maxdepth 3 -name '*.desktop' 2>/dev/null | sort | awk -v d="$d" '{ print d "\t" $0 }'
  done
} | awk -F'\t' -v L1="$L1" -v L2="$L2" '
function clean(s) { gsub(/\r/, "", s); gsub(/\t/, " ", s); sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
BEGIN { OFS = "\t" }
{
  dir = $1; path = $2
  id = substr(path, length(dir) + 2)
  sub(/\.desktop$/, "", id)
  gsub("/", "-", id)
  if (id in seen) next
  seen[id] = 1
  inEntry = 0; type = ""; name = ""; ln1 = ""; ln2 = ""; gen = ""; lg1 = ""; lg2 = ""
  kw = ""; ex = ""; ic = ""; term = ""; wd = ""; nod = ""; hid = ""
  while ((getline line < path) > 0) {
    if (substr(line, 1, 1) == "[") {
      if (inEntry) break
      inEntry = (line ~ /^\[Desktop Entry\]/)
      continue
    }
    if (!inEntry || substr(line, 1, 1) == "#") continue
    eq = index(line, "=")
    if (eq < 2) continue
    key = clean(substr(line, 1, eq - 1)); val = clean(substr(line, eq + 1))
    if (key == "Type") type = val
    else if (key == "Name") name = val
    else if (L1 != "" && key == ("Name[" L1 "]")) ln1 = val
    else if (L2 != "" && key == ("Name[" L2 "]")) ln2 = val
    else if (key == "GenericName") gen = val
    else if (L1 != "" && key == ("GenericName[" L1 "]")) lg1 = val
    else if (L2 != "" && key == ("GenericName[" L2 "]")) lg2 = val
    else if (key == "Keywords") kw = val
    else if (key == "Exec") ex = val
    else if (key == "Icon") ic = val
    else if (key == "Terminal") term = val
    else if (key == "Path") wd = val
    else if (key == "NoDisplay") nod = val
    else if (key == "Hidden") hid = val
  }
  close(path)
  if (ln1 != "") name = ln1; else if (ln2 != "") name = ln2
  if (lg1 != "") gen = lg1; else if (lg2 != "") gen = lg2
  if (type != "Application" || nod == "true" || hid == "true" || name == "" || ex == "") next
  print id, name, gen, kw, ex, ic, term, wd, path
}' > "$TMP" && mv "$TMP" "$OUT"
]==]

local publishedSig = nil
local dirStamp = nil
local scanning = false
local iconMap = {}             -- icon name -> resolved path ("" = looked up, not found)
local iconQueue, iconQi = {}, 1
local sincePublish = 0
local reportedFailure = false

-- ── helpers ────────────────────────────────────────────────────────────

local function userLangs()
  local l = noctalia.getenv("LC_MESSAGES") or noctalia.getenv("LANG") or ""
  l = string.match(l, "^([^%.@]+)") or ""
  local out = {}
  if l ~= "" and l ~= "C" and l ~= "POSIX" then
    out[#out + 1] = l
    local short = string.match(l, "^([^_]+)")
    if short and short ~= l then out[#out + 1] = short end
  end
  return out
end

-- XDG precedence: user dir first, then XDG_DATA_DIRS in order, so a user override wins.
local function appDirs()
  local dirs, seen = {}, {}
  local function add(d)
    d = (string.gsub(d, "/+$", ""))
    if d ~= "" and not seen[d] then
      seen[d] = true
      dirs[#dirs + 1] = d
    end
  end
  local home = noctalia.getenv("XDG_DATA_HOME")
  if not home or home == "" then home = noctalia.expandPath("~/.local/share") end
  add(home .. "/applications")
  local xdg = noctalia.getenv("XDG_DATA_DIRS")
  if not xdg or xdg == "" then xdg = "/usr/local/share:/usr/share" end
  for d in string.gmatch(xdg, "[^:]+") do add(d .. "/applications") end
  add("/var/lib/flatpak/exports/share/applications")
  add(noctalia.expandPath("~/.local/share/flatpak/exports/share/applications"))
  add("/var/lib/snapd/desktop/applications")
  local extra = noctalia.getConfig("extra_app_dirs")
  if type(extra) == "table" then
    for _, d in ipairs(extra) do add(noctalia.expandPath(d)) end
  end
  return dirs
end

local function stampOf(dirs)
  local parts = {}
  for _, d in ipairs(dirs) do
    local info = noctalia.fileInfo(d)
    parts[#parts + 1] = info and tostring(info.mtime) or "-"
  end
  return table.concat(parts, ",")
end

local function splitTabs(line)
  local out, n, pos = {}, 0, 1
  while true do
    local i = string.find(line, "\t", pos, true)
    n = n + 1
    if not i then
      out[n] = string.sub(line, pos)
      return out
    end
    out[n] = string.sub(line, pos, i - 1)
    pos = i + 1
  end
end

-- ── icons: streamed in after the list is already visible ───────────────

local function publishIcons()
  sincePublish = 0
  noctalia.state.set("icons", iconMap)
end

local function queueIcons(apps)
  iconQueue, iconQi = {}, 1
  local queued = {}
  for _, a in ipairs(apps) do
    local name = a.icon
    if name and name ~= "" and string.sub(name, 1, 1) ~= "/" and (iconMap[name] == nil or iconMap[name] == "") and not queued[name] then
      queued[name] = true
      iconQueue[#iconQueue + 1] = name
    end
  end
  if #iconQueue > 0 then noctalia.setUpdateInterval(TICK_ICONS) end
end

local function iconSlice()
  local t0 = noctalia.nowMs()
  while iconQi <= #iconQueue and noctalia.nowMs() - t0 < SLICE_MS do
    local name = iconQueue[iconQi]
    iconQi = iconQi + 1
    local path = noctalia.appIconPath(name, ICON_PX)
    if path and path ~= "" then
      iconMap[name] = path
    else
      -- Never cache a miss: an early lookup can fail (theme not ready yet, icon installed later) and
      -- a cached miss would then stick forever. Misses are simply retried on the next scan.
      iconMap[name] = nil
    end
    sincePublish = sincePublish + 1
  end
  if iconQi > #iconQueue then
    iconQueue, iconQi = {}, 1
    noctalia.setUpdateInterval(TICK_IDLE)
    publishIcons()
    U.saveJson("icons.json", iconMap)
  elseif sincePublish >= PUBLISH_EVERY then
    publishIcons()
  end
end

-- ── the app list ───────────────────────────────────────────────────────

local function signature(apps)
  local parts = {}
  for i, a in ipairs(apps) do parts[i] = a.id .. "|" .. a.name .. "|" .. a.icon end
  return table.concat(parts, "\n")
end

local function parseTsv(raw)
  local apps = {}
  for line in string.gmatch(raw, "[^\n]+") do
    local f = splitTabs(line)
    if #f >= 9 then
      apps[#apps + 1] = {
        id = f[1], name = f[2], lname = string.lower(f[2]),
        generic = f[3], keywords = f[4], exec = f[5], icon = f[6],
        terminal = (f[7] == "true"), cwd = (f[8] ~= "" and f[8] or nil), file = f[9],
      }
    end
  end
  table.sort(apps, function(a, b)
    if a.lname ~= b.lname then return a.lname < b.lname end
    return a.id < b.id
  end)
  return apps
end

local function outPath()
  local dir = noctalia.pluginDataDir()
  if not dir then return nil end
  noctalia.mkdirAll(dir)
  return dir .. "/apps.tsv"
end

local function onScanDone(res, out, stamp)
  scanning = false
  if res.exitCode ~= 0 then
    noctalia.log("start-menu: app scan failed (exit " .. tostring(res.exitCode) .. "): " .. tostring(res.stderr))
    if not reportedFailure then
      reportedFailure = true
      noctalia.notifyError(noctalia.tr("err.scan_failed"), tostring(res.stderr))
    end
    return
  end
  local raw = noctalia.readFile(out)
  if not raw then
    noctalia.log("start-menu: could not read " .. out)
    return
  end
  dirStamp = stamp
  local t0 = noctalia.nowMs()
  local apps = parseTsv(raw)
  local sig = signature(apps)
  if sig ~= publishedSig then
    publishedSig = sig
    noctalia.log(string.format("start-menu: publishing %d apps (parsed in %d ms)", #apps, noctalia.nowMs() - t0))
    noctalia.state.set("apps", apps)
  end
  queueIcons(apps)
end

local function startScan()
  if scanning then return end
  local out = outPath()
  if not out then
    noctalia.log("start-menu: no plugin data directory")
    return
  end
  local dirs = appDirs()
  local stamp = stampOf(dirs)
  local langs = userLangs()
  local argv = { "sh", "-c", SCRIPT, "sh", langs[1] or "", langs[2] or "", out }
  for _, d in ipairs(dirs) do argv[#argv + 1] = d end
  scanning = true
  noctalia.runAsync(argv, function(res) onScanDone(res, out, stamp) end)
end

local function safely(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    noctalia.log("start-menu: " .. label .. " failed: " .. tostring(err))
    scanning = false
  end
end


-- ── lifecycle ──────────────────────────────────────────────────────────

local cachedIcons = U.loadJson("icons.json", nil)
if type(cachedIcons) == "table" then
  iconMap = cachedIcons
  noctalia.state.set("icons", iconMap)   -- icons are there from the first frame after a restart
end

noctalia.setUpdateInterval(TICK_IDLE)
safely("scan", startScan)

function update()
  if iconQi <= #iconQueue then
    safely("icons", iconSlice)
    return
  end
  -- idle: rescan only when an applications folder changed (app installed or removed)
  if not scanning and stampOf(appDirs()) ~= dirStamp then safely("scan", startScan) end
end

function onConfigChanged()
  safely("scan", startScan)
end

-- noctalia msg plugin you/start-menu:apps all rescan
function onIpc(event)
  if event == "rescan" then safely("scan", startScan) end
end

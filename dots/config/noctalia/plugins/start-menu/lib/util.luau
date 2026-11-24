--!nonstrict
-- Helpers shared by the service, the panel and the bar widget.

local M = {}

function M.clamp(v, lo, hi)
  if hi < lo then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.trim(s)
  return noctalia.string.trim(s or "")
end

function M.shq(s)
  return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local have = {}
function M.exists(cmd)
  if have[cmd] == nil then have[cmd] = noctalia.commandExists(cmd) == true end
  return have[cmd]
end

-- ── persistence (survives restarts; never write inside the plugin dir) ─────────────

function M.loadJson(name, default)
  local dir = noctalia.pluginDataDir()
  if not dir then return default end
  local raw = noctalia.readFile(dir .. "/" .. name)
  if not raw then return default end
  local v = noctalia.json.decode(raw)
  if v == nil then return default end
  return v
end

function M.saveJson(name, value)
  local dir = noctalia.pluginDataDir()
  if not dir then return false end
  local s = noctalia.json.encode(value)
  if not s then return false end
  return noctalia.writeFile(dir .. "/" .. name, s) == true
end

-- ── .desktop parsing ───────────────────────────────────────────────────────────────
-- Reads only the [Desktop Entry] group (actions come later in the file, so we stop there).
-- langs = {"de_DE", "de"}: preferred locales, most specific first, for Name[xx] / GenericName[xx].

function M.parseDesktop(raw, langs)
  local inEntry = false
  local e = { loc = {} }
  for line in string.gmatch(raw, "[^\r\n]+") do
    local group = string.match(line, "^%[(.-)%]%s*$")
    if group then
      if inEntry then break end
      inEntry = (group == "Desktop Entry")
    elseif inEntry and string.sub(line, 1, 1) ~= "#" then
      local k, lang, v = string.match(line, "^([%w%-]+)%[([^%]]*)%]%s*=%s*(.*)$")
      if k then
        e.loc[k] = e.loc[k] or {}
        e.loc[k][lang] = v
      else
        k, v = string.match(line, "^([%w%-]+)%s*=%s*(.*)$")
        if k then e[k] = v end
      end
    end
  end
  local function pick(key)
    for _, l in ipairs(langs or {}) do
      local t = e.loc[key]
      if t and t[l] and t[l] ~= "" then return t[l] end
    end
    return e[key]
  end
  e.name = pick("Name")
  e.generic = pick("GenericName")
  e.keywords = pick("Keywords")
  return e
end

-- ── launching ─────────────────────────────────────────────────────────────────────
-- Straight from the click, no state hop, no xdg-open script: it was visibly slow.

function M.openApp(app)
  local t0 = noctalia.nowMs()
  local cwd = (app.cwd and app.cwd ~= "") and ("cd " .. M.shq(app.cwd) .. " && ") or ""
  if app.exec and app.exec ~= "" then
    local cmd = string.gsub(app.exec, "%%%%", "\1")                 -- keep a literal %% safe
    cmd = string.gsub(cmd, "%%[fFuUdDnNickvm]", "")                 -- drop field codes (%u, %F, ...)
    cmd = M.trim((string.gsub(cmd, "\1", "%%")))
    if app.terminal then
      noctalia.runInTerminal(cwd .. cmd)
    else
      noctalia.runAsync({ "sh", "-c", cwd .. "exec " .. cmd })
    end
  elseif app.file then
    noctalia.runAsync({ "gio", "launch", app.file })
  end
  noctalia.log(string.format("start-menu: launched %s (spawned in %d ms)", app.id or "?", noctalia.nowMs() - t0))
end

function M.openPath(path)
  if M.exists("gio") then
    noctalia.runAsync({ "gio", "open", path })
  else
    noctalia.runAsync({ "xdg-open", path })
  end
end

return M

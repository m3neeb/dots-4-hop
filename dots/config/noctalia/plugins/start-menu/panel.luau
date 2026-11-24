--!nonstrict
-- The start menu panel: side rail | app list | pinned tiles, with a search bar along the bottom.
--
-- CPU budget: Noctalia aborts any callback that runs too long, so nothing here renders the whole
-- app list. The list is *windowed*: only ~30 rows around the scroll position exist, with empty
-- fixed-height spacers above and below so the scrollbar still spans the full list. Rail and tiles
-- are built once and reused until they change.

local U = require("./lib/util.luau")
local clamp = U.clamp

-- ── layout constants ───────────────────────────────────────────────────
local PANEL_H   = 740                     -- must match height in plugin.toml
local RAIL_W    = 48
local TILE      = 100
local TILE_V    = 4                       -- vertical padding inside a tile
local LABEL_H   = 26                      -- exact height of the name button under the icon
local ICON_H    = TILE - TILE_V * 2 - LABEL_H   -- the icon area takes exactly what is left, so nothing can spill out
local GAP       = 4
local TILE_PAD  = 10
local RIGHT_W   = TILE * 3 + GAP * 2 + TILE_PAD * 2
local VIEW_H    = PANEL_H - 120           -- estimated height of the scrolling list viewport
local BUFFER    = 8                       -- rows rendered beyond the viewport on each side
local HYST      = 4                       -- re-window only after moving this many rows
local MAX_RESULTS = 12

local function num(key, fallback)
  local v = noctalia.getConfig(key)
  if type(v) == "number" then return v end
  return fallback
end

local ROW_H     = clamp(math.floor(num("row_height", 40)), 28, 64)
local WINDOW    = math.ceil(VIEW_H / ROW_H) + BUFFER * 2
local MOST_USED = clamp(math.floor(num("most_used_count", 4)), 0, 8)
local accentTiles = noctalia.getConfig("tile_style") ~= "surface"

local groups = noctalia.getConfig("group_names")
if type(groups) ~= "table" or #groups == 0 then groups = { "Pinned" } end

-- ── state ──────────────────────────────────────────────────────────────
local apps = noctalia.state.get("apps") or {}
local iconMap = noctalia.state.get("icons") or {}   -- icon name -> path, streamed in by the service
local byId = {}
local flat, letterIndex = {}, {}
local isOpen = false
local openCount = 0
local query, results = "", {}
local view = "list"                       -- "list" | "letters" | "search"
local winStart = 0
local pendingReveal = nil
local tilesCache, railCache = nil, nil
local render

local tiles = U.loadJson("tiles.json", {})
local usage = U.loadJson("usage.json", {})
do
  local clean = {}
  for _, t in ipairs(type(tiles) == "table" and tiles or {}) do
    if type(t) == "table" and type(t.id) == "string" then
      clean[#clean + 1] = {
        id = t.id,
        size = (t.size == "wide") and "wide" or "medium",
        group = clamp(math.floor(tonumber(t.group) or 1), 1, #groups),
      }
    end
  end
  tiles = clean
  if type(usage) ~= "table" then usage = {} end
end

local userName = noctalia.getenv("USER") or "user"

local folders = {}
do
  local lines = noctalia.getConfig("rail_folders")
  for _, line in ipairs(type(lines) == "table" and lines or {}) do
    local label, glyph, path = string.match(line, "^%s*([^|]*)|%s*([^|]*)|%s*(.-)%s*$")
    if label and path and path ~= "" then
      path = noctalia.expandPath(path)
      if noctalia.fileExists(path) then
        folders[#folders + 1] = { label = label, glyph = (glyph ~= "" and glyph or "folder"), path = path }
      end
    end
  end
end

-- ── small helpers ──────────────────────────────────────────────────────

local function shorten(s, max)
  local len = utf8.len(s)
  if not len or len <= max then return s end
  local keep = max - 1
  local cut = utf8.offset(s, keep + 1) - 1
  return string.sub(s, 1, cut) .. "…"
end

local function letterOf(name)
  local c = string.upper(string.sub(name, 1, 1))
  if #c == 1 and string.match(c, "%a") then return c end
  return "#"
end

local function isPinned(id)
  for _, t in ipairs(tiles) do
    if t.id == id then return true end
  end
  return false
end

local function closePanel()
  isOpen = false
  panel.close()
end

local function runShell(cmd)
  noctalia.runAsync({ "sh", "-c", cmd })
end

-- ── data: flattened list, usage, tiles ─────────────────────────────────

local function rebuild()
  byId = {}
  for _, a in ipairs(apps) do
    byId[a.id] = a
    a.lgen = string.lower(a.generic or "")
    a.lkw = string.lower(a.keywords or "")
  end

  flat, letterIndex = {}, {}
  if MOST_USED > 0 then
    local list = {}
    for id, u in pairs(usage) do
      if byId[id] and type(u) == "table" and (u.n or 0) > 0 then
        list[#list + 1] = { app = byId[id], n = u.n, t = u.t or 0 }
      end
    end
    table.sort(list, function(a, b)
      if a.n ~= b.n then return a.n > b.n end
      if a.t ~= b.t then return a.t > b.t end
      return a.app.lname < b.app.lname
    end)
    if #list > 0 then
      flat[#flat + 1] = { k = "t", label = noctalia.tr("list.most_used") }
      for i = 1, math.min(MOST_USED, #list) do
        flat[#flat + 1] = { k = "m", app = list[i].app }
      end
    end
  end

  local prev = nil
  for _, a in ipairs(apps) do
    local letter = letterOf(a.name)
    if letter ~= prev then
      prev = letter
      flat[#flat + 1] = { k = "h", label = letter }
      if not letterIndex[letter] then letterIndex[letter] = #flat end
    end
    flat[#flat + 1] = { k = "a", app = a }
  end
  tilesCache = nil
end

local function flatKey(i)
  local e = flat[i]
  if e.k == "h" then return "h:" .. e.label end
  if e.k == "t" then return "t:most" end
  return (e.k == "m" and "m:" or "a:") .. e.app.id
end

local function saveTiles() U.saveJson("tiles.json", tiles) end

local function launchApp(app)
  U.openApp(app)
  local u = usage[app.id]
  if type(u) ~= "table" then u = { n = 0 } end
  u.n = (u.n or 0) + 1
  u.t = noctalia.nowMs()
  usage[app.id] = u
  U.saveJson("usage.json", usage)
  closePanel()
end

local function tilesChanged()
  tilesCache = nil
  saveTiles()
  render()
end

local function findTile(id)
  for i, t in ipairs(tiles) do
    if t.id == id then return i, t end
  end
  return nil
end

local function moveTile(id, dir)
  local i, t = findTile(id)
  if not i then return end
  local j = i + dir
  while tiles[j] and tiles[j].group ~= t.group do j = j + dir end
  if not tiles[j] then return end
  tiles[i], tiles[j] = tiles[j], tiles[i]
  tilesChanged()
end

-- ── search ─────────────────────────────────────────────────────────────

-- Matching is plain Lua string work. The host's fuzzyScore used to be called up to three times per app per
-- keystroke (1000+ calls across the host boundary on a normal app list), which is what blew the callback's
-- CPU budget. Per search term: a substring hit scores by position (prefix and word starts best); failing
-- that, a subsequence match (every letter in order, "ffx" -> Firefox) scores by how tightly it is packed.
local function termScore(term, text)
  if text == "" then return nil end
  local pos = string.find(text, term, 1, true)
  if pos then
    local score = 1000 - math.min(pos, 200)
    if pos == 1 then
      score = score + 500
    else
      local before = string.sub(text, pos - 1, pos - 1)
      if before == " " or before == "-" or before == "_" or before == "." then score = score + 250 end
    end
    return score
  end
  if #term < 2 then return nil end
  local from, first, last = 1, nil, nil
  for i = 1, #term do
    local at = string.find(text, string.sub(term, i, i), from, true)
    if not at then return nil end
    first = first or at
    last = at
    from = at + 1
  end
  return 300 - math.min(last - first, 250)
end

local function search(q)
  local terms = {}
  for w in string.gmatch(string.lower(q), "%S+") do terms[#terms + 1] = w end
  if #terms == 0 then return {} end

  local scored = {}
  for _, a in ipairs(apps) do
    local total = 0
    for _, term in ipairs(terms) do
      local best = termScore(term, a.lname)
      local g = termScore(term, a.lgen or "")
      if g and (not best or g * 0.7 > best) then best = g * 0.7 end
      local k = termScore(term, a.lkw or "")
      if k and (not best or k * 0.5 > best) then best = k * 0.5 end
      if not best then
        total = nil   -- every term has to match somewhere
        break
      end
      total = total + best
    end
    if total then scored[#scored + 1] = { app = a, s = total } end
  end
  table.sort(scored, function(x, y)
    if x.s ~= y.s then return x.s > y.s end
    return x.app.lname < y.app.lname
  end)
  local out = {}
  for i = 1, math.min(MAX_RESULTS, #scored) do out[i] = scored[i].app end
  return out
end

local function setQuery(v)
  query = v or ""
  local q = U.trim(query)
  if q == "" then
    results = {}
    view = "list"
  else
    results = search(q)
    view = "search"
  end
  render()
end

-- ── context menus ──────────────────────────────────────────────────────
-- panel.openContextMenu only works when called directly from a ui.button's onRightClick.

local function openAppMenu(app)
  panel.openContextMenu({
    items = {
      { kind = "header", label = app.name },
      { id = "open", label = noctalia.tr("menu.open") },
      isPinned(app.id)
        and { id = "unpin", label = noctalia.tr("menu.unpin") }
        or { id = "pin", label = noctalia.tr("menu.pin") },
    },
    onActivate = "onMenuAction",
    context = app.id,
  })
end

local function openTileMenu(t, app)
  local items = {
    { kind = "header", label = app.name },
    { id = "open", label = noctalia.tr("menu.open") },
    { kind = "separator" },
    { id = (t.size == "wide") and "medium" or "wide",
      label = noctalia.tr((t.size == "wide") and "menu.make_medium" or "menu.make_wide") },
    { id = "earlier", label = noctalia.tr("menu.move_earlier") },
    { id = "later", label = noctalia.tr("menu.move_later") },
  }
  for g = 1, #groups do
    if g ~= t.group then
      items[#items + 1] = { id = "group:" .. g, label = noctalia.tr("menu.move_to", { group = groups[g] }) }
    end
  end
  items[#items + 1] = { kind = "separator" }
  items[#items + 1] = { id = "unpin", label = noctalia.tr("menu.unpin") }
  panel.openContextMenu({ items = items, onActivate = "onMenuAction", context = app.id })
end

function onMenuAction(action, id)
  local app = byId[id]
  if action == "open" then
    if app then launchApp(app) end
  elseif action == "pin" then
    if app and not isPinned(id) then
      tiles[#tiles + 1] = { id = id, size = "medium", group = 1 }
      tilesChanged()
    end
  elseif action == "unpin" then
    local i = findTile(id)
    if i then
      table.remove(tiles, i)
      tilesChanged()
    end
  elseif action == "wide" or action == "medium" then
    local _, t = findTile(id)
    if t then
      t.size = action
      tilesChanged()
    end
  elseif action == "earlier" then
    moveTile(id, -1)
  elseif action == "later" then
    moveTile(id, 1)
  elseif string.sub(action, 1, 6) == "group:" then
    local _, t = findTile(id)
    local g = tonumber(string.sub(action, 7))
    if t and g and g >= 1 and g <= #groups then
      t.group = g
      tilesChanged()
    end
  end
end

-- ── app rows ───────────────────────────────────────────────────────────

-- Icons arrive after the list does; until then (or when a theme has none) a glyph stands in.
local function iconPathOf(app)
  local name = app.icon
  if not name or name == "" then return nil end
  if string.sub(name, 1, 1) == "/" then return name end
  local p = iconMap[name]
  if p and p ~= "" then return p end
  return nil
end

local function iconNode(app, size)
  local path = iconPathOf(app)
  if path then
    return ui.image({ path = path, width = size, height = size })
  end
  return ui.glyph({ name = "app-window", size = size - 4 })
end

local function appRow(app, key, highlighted)
  local function open() launchApp(app) end
  return ui.row({ key = key, height = ROW_H, gap = 10, align = "center", paddingH = 8, onClick = open }, {
    iconNode(app, 26),
    ui.button({
      key = "n", text = app.name, variant = highlighted and "secondary" or "ghost",
      contentAlign = "start", height = ROW_H - 6, flexGrow = 1,
      onClick = open, onRightClick = function() openAppMenu(app) end,
    }),
  })
end

local function flatNode(i)
  local e = flat[i]
  if e.k == "t" then
    return ui.row({ key = "t:most", height = ROW_H, align = "center", paddingH = 12 }, {
      ui.label({ text = e.label, fontSize = 13, fontWeight = "bold", color = "on_surface/0.7" }),
    })
  elseif e.k == "h" then
    return ui.button({
      key = "h:" .. e.label, text = e.label, variant = "ghost", contentAlign = "start", height = ROW_H,
      onClick = function()
        view = "letters"
        render()
      end,
    })
  end
  return appRow(e.app, flatKey(i), false)
end

local function listNode()
  local total = #flat
  if total == 0 then
    return ui.label({ key = "loading", text = noctalia.tr("list.loading"), color = "on_surface/0.6" })
  end
  local first = clamp(winStart, 0, math.max(0, total - 1))
  local last = math.min(total, first + WINDOW)
  local kids = {}
  if first > 0 then kids[#kids + 1] = ui.column({ key = "sp-top", height = first * ROW_H }, {}) end
  for i = first + 1, last do kids[#kids + 1] = flatNode(i) end
  if last < total then kids[#kids + 1] = ui.column({ key = "sp-bot", height = (total - last) * ROW_H }, {}) end
  return ui.scroll({
    key = "applist-" .. openCount, flexGrow = 1, gap = 0, revealKey = pendingReveal,
    onScroll = function(offset, maxOffset)
      local off, mx = tonumber(offset), tonumber(maxOffset)
      if not off or not mx or mx <= 0 then return end
      local scrollable = math.max(0, total * ROW_H - VIEW_H)
      local firstVisible = math.floor((off / mx) * scrollable / ROW_H)
      local want = math.max(0, firstVisible - BUFFER)
      if math.abs(want - winStart) >= HYST then
        winStart = want
        render()
      end
    end,
  }, kids)
end

local function jumpToLetter(letter)
  local idx = letterIndex[letter]
  if not idx then return end
  view = "list"
  -- Scrolling down: reveal a row one screen below the header, so the header lands at the top.
  -- Scrolling up: reveal the header itself, which lands at the top edge.
  local viewRows = math.floor(VIEW_H / ROW_H)
  local down = idx > winStart + BUFFER
  local revealIdx = down and math.min(#flat, idx + viewRows - 1) or idx
  winStart = math.max(0, math.min(idx, revealIdx) - BUFFER)
  pendingReveal = flatKey(revealIdx)
  render()
  pendingReveal = nil   -- one render only, so later scrolling is never undone
end

local ALPHABET = { "#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }

local function lettersNode()
  local rows = {}
  for i = 1, #ALPHABET, 4 do
    local buttons = {}
    for j = i, math.min(i + 3, #ALPHABET) do
      local l = ALPHABET[j]
      local available = letterIndex[l] ~= nil
      buttons[#buttons + 1] = ui.button({
        key = "L" .. l, text = l, enabled = available,
        variant = available and "secondary" or "ghost", width = 64, height = 48,
        onClick = function() jumpToLetter(l) end,
      })
    end
    rows[#rows + 1] = ui.row({ key = "lr" .. i, gap = 6 }, buttons)
  end
  return ui.column({ key = "letters", flexGrow = 1, gap = 6, padding = 10 }, {
    ui.label({ text = noctalia.tr("letters.title"), fontSize = 13, fontWeight = "bold", color = "on_surface/0.7" }),
    ui.column({ gap = 6 }, rows),
  })
end

local function resultsNode()
  local rows = {}
  if #results == 0 then
    rows[1] = ui.row({ key = "none", height = ROW_H, align = "center", paddingH = 12 }, {
      ui.label({ text = noctalia.tr("search.no_results"), color = "on_surface/0.6" }),
    })
  else
    for i, app in ipairs(results) do
      rows[#rows + 1] = appRow(app, "r:" .. app.id, i == 1)
    end
  end
  return ui.column({ key = "results", flexGrow = 1, gap = 0, paddingV = 6 }, rows)
end

-- ── tiles ──────────────────────────────────────────────────────────────

local function tileNode(t, app)
  local wide = (t.size == "wide")
  local w = wide and (TILE * 2 + GAP) or TILE
  local function open() launchApp(app) end
  -- Children heights + padding must equal the tile height exactly (ICON_H + LABEL_H + 2 * TILE_V == TILE).
  -- The name button used controlSize = "sm" (about 32 px) before, which made the stack ~8 px too tall and
  -- pushed the label past the bottom edge of the tile.
  local props = {
    key = "t:" .. t.id, width = w, height = TILE, align = "center", justify = "start", gap = 0,
    paddingV = TILE_V, paddingH = 4,
  }
  if accentTiles then
    props.fill = "primary"
  else
    props.fill = "surface_container"
    props.border = "outline_variant"
    props.borderWidth = 1
  end
  return ui.column(props, {
    ui.column({ key = "pic", height = ICON_H, align = "center", justify = "center", onClick = open }, {
      iconNode(app, 44),
    }),
    ui.button({
      key = "n", text = shorten(app.name, wide and 28 or 12), height = LABEL_H, width = w - 8,
      variant = accentTiles and "primary" or "ghost",
      onClick = open, onRightClick = function() openTileMenu(t, app) end,
    }),
  })
end

local function buildTiles()
  local kids = {}
  local any = false
  for g = 1, #groups do
    local rows, cur, used = {}, nil, 0
    for _, t in ipairs(tiles) do
      local app = byId[t.id]
      if t.group == g and app then
        any = true
        local slots = (t.size == "wide") and 2 or 1
        if not cur or used + slots > 3 then
          cur = {}
          rows[#rows + 1] = cur
          used = 0
        end
        cur[#cur + 1] = tileNode(t, app)
        used = used + slots
      end
    end
    if #rows > 0 then
      if #kids > 0 then kids[#kids + 1] = ui.column({ key = "gap" .. g, height = 10 }, {}) end
      kids[#kids + 1] = ui.label({ key = "gh" .. g, text = groups[g], fontSize = 13, fontWeight = "bold", color = "on_surface/0.8" })
      for ri, r in ipairs(rows) do
        kids[#kids + 1] = ui.row({ key = "g" .. g .. "r" .. ri, gap = GAP }, r)
      end
    end
  end
  if not any then
    kids[1] = ui.label({ key = "empty", text = noctalia.tr("tiles.empty"), maxWidth = RIGHT_W - TILE_PAD * 2, color = "on_surface/0.6" })
  end
  return ui.scroll({
    key = "tiles", width = RIGHT_W, paddingH = TILE_PAD, paddingV = 10, gap = GAP, fill = "surface_container/0.55",
  }, kids)
end

local function bestMatchNode()
  local app = results[1]
  if not app then
    return ui.column({ key = "bm", width = RIGHT_W, padding = 16, fill = "surface_container/0.55" }, {})
  end
  return ui.column({
    key = "bm", width = RIGHT_W, paddingH = 16, paddingV = 28, gap = 12, align = "center", fill = "surface_container/0.55",
  }, {
    ui.label({ text = noctalia.tr("search.best_match"), fontSize = 12, color = "on_surface/0.7" }),
    iconNode(app, 64),
    ui.label({ text = app.name, fontSize = 18, fontWeight = "bold", maxWidth = RIGHT_W - 32, textAlign = "center" }),
    ui.label({ text = noctalia.tr("search.app"), fontSize = 12, color = "on_surface/0.7" }),
    ui.button({ key = "go", text = noctalia.tr("menu.open"), variant = "primary", onClick = function() launchApp(app) end }),
    ui.button({
      key = "pin", variant = "ghost",
      text = noctalia.tr(isPinned(app.id) and "menu.unpin" or "menu.pin"),
      onClick = function() onMenuAction(isPinned(app.id) and "unpin" or "pin", app.id) end,
    }),
  })
end

-- ── rail ───────────────────────────────────────────────────────────────

local function railButton(key, glyph, tip, onClick)
  return ui.button({
    key = key, glyph = glyph, glyphSize = 18, variant = "ghost", width = 44, height = 44,
    tooltip = tip, onClick = onClick,
  })
end

local function buildRail()
  local items = { ui.spacer({ key = "sp", flexGrow = 1 }) }
  items[#items + 1] = railButton("user", "user", noctalia.tr("rail.lock", { user = userName }), function()
    local cmd = U.trim(noctalia.getConfig("lock_command") or "")
    if cmd ~= "" then runShell(cmd) end
    closePanel()
  end)
  for i, f in ipairs(folders) do
    items[#items + 1] = railButton("f" .. i, f.glyph, f.label, function()
      U.openPath(f.path)
      closePanel()
    end)
  end
  items[#items + 1] = railButton("settings", "settings", noctalia.tr("rail.settings"), function()
    local cmd = U.trim(noctalia.getConfig("settings_command") or "")
    if cmd ~= "" then
      runShell(cmd)
    else
      noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center" })
    end
    closePanel()
  end)
  items[#items + 1] = railButton("power", "power", noctalia.tr("rail.power"), function()
    closePanel()
    if U.exists("noctalia") then
      noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "session" })
    else
      noctalia.notifyError(noctalia.tr("err.no_noctalia"))
    end
  end)
  return ui.column({
    key = "rail", width = RAIL_W, paddingV = 6, gap = 2, align = "center", fill = "surface_container",
  }, items)
end

-- ── render ─────────────────────────────────────────────────────────────

local function searchBar()
  return ui.row({
    key = "searchbar", height = 46, align = "center", gap = 8, paddingH = 14, fill = "surface_container",
  }, {
    ui.glyph({ name = "search", size = 18 }),
    ui.input({
      key = "search-" .. openCount, focus = true, frameVisible = false, flexGrow = 1,
      placeholder = noctalia.tr("search.placeholder"),
      onChange = function(v) setQuery(v) end,
      onSubmit = function(v)
        if v then query = v end
        local q = U.trim(query)
        if q == "" then return end
        local best = results[1] or search(q)[1]
        if best then launchApp(best) end
      end,
    }),
  })
end

local function draw()
  railCache = railCache or buildRail()

  local left, right
  if view == "search" then
    left, right = resultsNode(), bestMatchNode()
  else
    tilesCache = tilesCache or buildTiles()   -- not needed (and not built) while the search card is shown
    if view == "letters" then
      left, right = lettersNode(), tilesCache
    else
      left, right = listNode(), tilesCache
    end
  end

  panel.render(ui.column({ flexGrow = 1, gap = 0 }, {
    ui.row({ key = "main", flexGrow = 1 }, {
      railCache,
      ui.column({ key = "left", flexGrow = 1, paddingH = 4 }, { left }),
      right,
    }),
    searchBar(),
  }))
end

render = function()
  if not isOpen then return end
  local ok, err = pcall(draw)
  if not ok then noctalia.log("start-menu: render failed: " .. tostring(err)) end
end

-- ── lifecycle ──────────────────────────────────────────────────────────

function onOpen()
  isOpen = true
  openCount = openCount + 1
  query, results, view, winStart, pendingReveal = "", {}, "list", 0, nil
  apps = noctalia.state.get("apps") or apps
  rebuild()
  render()
end

function onClose()
  isOpen = false
end

noctalia.state.watch("apps", function(v)
  apps = v or {}
  rebuild()
  render()
end)

-- Icons stream in while the service works through the theme; redraw as batches land.
noctalia.state.watch("icons", function(v)
  iconMap = v or {}
  tilesCache = nil
  render()
end)

rebuild()

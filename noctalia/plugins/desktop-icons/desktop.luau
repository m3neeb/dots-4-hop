--!nonstrict
-- The desktop surface (one instance per output): icon grid + right-click handling.
--
-- Icons are laid out in square "slots" (cell x cell px), filled column by column like Windows/Plasma.
--
-- Right click on empty desktop is an OPT-IN setting (empty_menu). ui.button is the only control with
-- onRightClick and it reports no pointer position, so the only way to catch it is to tile the empty
-- desktop with near-invisible buttons. Buttons always show a pointer cursor, so that costs a hand
-- cursor over the whole desktop; hence it is off by default. Redraws are kept tiny on purpose:
-- Noctalia aborts any script callback that runs too long and disables a layer that does it repeatedly.

local model = require("./lib/model.luau")
local clamp = model.clamp

local me = layer.outputName()

local function num(key, fallback)
  local v = noctalia.getConfig(key)
  if type(v) == "number" then return v end
  return fallback
end

local onlyOutput = noctalia.getConfig("output")
local active = (onlyOutput == nil or onlyOutput == "" or onlyOutput == me)

local emptyMenu   = noctalia.getConfig("empty_menu") == true
local div         = clamp(math.floor(num("hit_divisions", 1)), 1, 3)
local hit         = math.max(32, math.floor(clamp(num("cell_size", 96), 64, 200) / div))
local cell        = hit * div
local iconSize    = clamp(math.floor(num("icon_size", 48)), 24, cell - 40)
local padT        = num("padding_top", 8)
local padL        = num("padding_left", 8)
local padB        = num("padding_bottom", 48)
local rowsFixed   = math.floor(num("rows", 0))
local hitOpacity  = clamp(num("hit_opacity", 0.02), 0, 1)
local glyphMode   = noctalia.getConfig("icon_style") == "glyph"
local singleClick = noctalia.getConfig("single_click") == true
local doubleMs    = num("double_click_ms", 450)
local backing     = clamp(num("label_backing", 0), 0, 1)

local items = noctalia.state.get("items") or {}
local lastKey, lastAt = nil, 0
local menuOpen = false
local outW, outH = model.outputSize(me)
local render

-- ── helpers ────────────────────────────────────────────────────────────

local function shorten(s, max)
  local len = utf8.len(s)
  if not len or len <= max then return s end
  local ext = string.match(s, "(%.[^%.%s]+)$") or ""
  local extLen = utf8.len(ext) or 99
  if extLen > 6 then ext, extLen = "", 0 end
  local keep = max - 1 - extLen
  if keep < 3 then keep, ext = max - 1, "" end
  local cut = utf8.offset(s, keep + 1) - 1
  return string.sub(s, 1, cut) .. "…" .. ext
end

local function closeMenu()
  if menuOpen then
    menuOpen = false
    noctalia.layer.hide("menu")
  end
end

local function openMenu(kind, item, x, y)
  local list = model.entries(kind, item)
  local w, h = model.size(list)
  local px = clamp(math.floor(x), 0, outW - w - 4)
  local py = clamp(math.floor(y), 0, outH - h - 4)

  -- Moving the menu to another monitor: drop the old surface first.
  if noctalia.state.get("menu_output") ~= (me or "") then
    noctalia.layer.hide("menu")
  end
  noctalia.state.set("menu_output", me or "")
  noctalia.state.set("menu", { kind = kind, item = item, x = px, y = py, nonce = model.nonce() })

  local props = {
    anchors = { "top", "left" },
    margins = { top = py, left = px, right = 0, bottom = 0 },
    width = w, height = h,
    keyboard = "none",
  }
  if me then props.output = me end
  noctalia.layer.configure("menu", props)
  noctalia.layer.show("menu")
  menuOpen = true
end

-- No selection state and no redraw on click: hover tinting is done by the buttons themselves.
local function onItemClick(it)
  closeMenu()
  local now = noctalia.nowMs()
  if singleClick or (lastKey == it.path and now - lastAt <= doubleMs) then
    lastKey = nil
    model.openItem(it)
  else
    lastKey, lastAt = it.path, now
  end
end

local function onEmptyClick()
  closeMenu()
  lastKey = nil
end

-- ── slots ──────────────────────────────────────────────────────────────

-- Empty slots never change, so each is built once and reused by every later render.
local emptyCache = {}
local emptyColumns = {}   -- whole columns with no icons in them

local function emptySlot(c, r)
  local ck = c * 1000 + r
  local cached = emptyCache[ck]
  if cached then return cached end

  local function hitButton(key, cx, cy)
    return ui.button({
      key = key,
      variant = "ghost",
      width = hit, height = hit,
      opacity = hitOpacity,
      onClick = onEmptyClick,
      onRightClick = function() openMenu("desktop", nil, cx, cy) end,
    })
  end

  local node
  if div == 1 then
    node = hitButton("e" .. c .. "." .. r, padL + (c - 1) * cell + cell / 2, padT + (r - 1) * cell + cell / 2)
  else
    local rowNodes = {}
    for sy = 1, div do
      local buttons = {}
      for sx = 1, div do
        local cx = padL + (c - 1) * cell + (sx - 0.5) * hit
        local cy = padT + (r - 1) * cell + (sy - 0.5) * hit
        buttons[#buttons + 1] = hitButton("h" .. sx, cx, cy)
      end
      rowNodes[#rowNodes + 1] = ui.row({ key = "r" .. sy, height = hit }, buttons)
    end
    node = ui.column({ key = "e" .. c .. "." .. r, width = cell, height = cell }, rowNodes)
  end
  emptyCache[ck] = node
  return node
end

local function itemSlot(it, c, r)
  local function click() onItemClick(it) end
  local cx = padL + (c - 1) * cell + cell * 0.6
  local cy = padT + (r - 1) * cell + cell * 0.6
  local function menu() openMenu("item", it, cx, cy) end

  local parts = {}
  -- A file can vanish between two scans; never hand the renderer a path that is already gone.
  local thumb = it.thumb
  if thumb and not noctalia.fileExists(thumb) then thumb = nil end
  local picture = thumb or it.iconPath
  if glyphMode or not picture then
    -- A button as the icon: right click works on the whole tile, but the icon is a monochrome glyph.
    parts[1] = ui.button({
      key = "pic",
      glyph = it.glyph, glyphSize = math.floor(iconSize * 0.7),
      variant = "ghost",
      width = iconSize + 24, height = iconSize + 8,
      onClick = click, onRightClick = menu,
    })
  else
    -- A real image: ui.image/ui.column only take left clicks, so right click is on the name below.
    parts[1] = ui.column({
      key = "pic", height = iconSize + 6, align = "center", justify = "center", onClick = click,
    }, {
      ui.image({
        path = picture, width = iconSize, height = iconSize,
        fit = thumb and "cover" or "contain",
        radius = thumb and 6 or 0,
        onClick = click,
      }),
    })
  end

  local name = ui.button({
    key = "lbl",
    text = shorten(it.label, 16),
    variant = "ghost",
    controlSize = "sm",
    width = cell - 8,
    onClick = click, onRightClick = menu,
  })
  if backing > 0 then
    parts[#parts + 1] = ui.row({
      key = "lbl-bg", width = cell - 8,
      fill = string.format("surface/%.2f", backing),
    }, { name })
  else
    parts[#parts + 1] = name
  end

  return ui.column({
    key = "i:" .. it.path, width = cell, height = cell,
    align = "center", justify = "center", gap = 2,
  }, parts)
end

-- ── render ─────────────────────────────────────────────────────────────

local function draw()
  if not active then
    layer.render(ui.column({ flexGrow = 1 }, {}))
    return
  end

  local W, H = model.outputSize(me)
  outW, outH = W, H
  local iconRows = rowsFixed > 0 and rowsFixed or math.max(1, math.floor((H - padT - padB) / cell))
  local useGrid = emptyMenu or #items == 0
  local usedCols = math.max(1, math.ceil(#items / iconRows))
  local cols = usedCols
  local hitRows = iconRows
  if useGrid then
    cols = math.max(usedCols, math.ceil((W - padL) / cell))
    hitRows = math.max(iconRows, math.ceil((H - padT) / cell))
  end

  -- column-major placement: fill a column top to bottom, then move right
  local grid = {}
  for i, it in ipairs(items) do
    local c = math.floor((i - 1) / iconRows) + 1
    local r = (i - 1) % iconRows + 1
    grid[c] = grid[c] or {}
    grid[c][r] = it
  end

  -- No ui.box spacers: a box is a drawn rectangle and showed up as a black border. Plain padding
  -- on the root container is invisible.
  local columns = {}
  for c = 1, cols do
    local column = (useGrid and not grid[c]) and emptyColumns[c] or nil
    if not column then
      local slots = {}
      for r = 1, hitRows do
        local it = grid[c] and grid[c][r]
        if it then
          slots[#slots + 1] = itemSlot(it, c, r)
        elseif useGrid then
          slots[#slots + 1] = emptySlot(c, r)
        end
      end
      column = ui.column({ key = "c" .. c, width = cell }, slots)
      if useGrid and not grid[c] then emptyColumns[c] = column end
    end
    columns[#columns + 1] = column
  end

  layer.render(ui.row({ key = "root", flexGrow = 1, paddingH = padL, paddingV = padT }, columns))
end

render = function()
  local ok, err = pcall(draw)
  if not ok then noctalia.log("desktop render failed: " .. tostring(err)) end
end

if active then
  noctalia.state.watch("items", function(v)
    items = v or {}
    render()
  end)
end
render()

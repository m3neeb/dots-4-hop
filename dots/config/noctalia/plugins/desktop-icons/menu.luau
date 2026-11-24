--!nonstrict
-- Context menu + name dialog. A small layer surface that desktop.luau positions with
-- noctalia.layer.configure() and shows/hides; it is destroyed on every hide.

local model = require("./lib/model.luau")
local clamp = model.clamp

local me = layer.outputName()
local req = noctalia.state.get("menu")
local typed = ""
local render

-- Auto-dismiss: with no click targets on empty desktop, nothing else can close an abandoned menu.
-- It closes after a few seconds with the pointer outside it (never while a dialog is open).
local hovered = false
local idle = -3

-- Only the innermost hovered element reports hover, so the pointer sitting on a menu *button* makes
-- the menu root report "leave". Every control therefore shares this handler: any enter wins.
local function onHover(state)
  hovered = not (state == false or state == "false" or state == "leave" or state == 0)
end

local function send(c)
  c.nonce = model.nonce()
  noctalia.state.set("cmd", c)
end

-- Never destroy this surface from inside its own click callback; ask the (long-lived) service to
-- hide it instead. A separate key from "cmd" so it can never overwrite a pending file command.
local function close()
  noctalia.state.set("menu_close", model.nonce())
end

-- ── dialog ─────────────────────────────────────────────────────────────

local function startDialog(mode, item)
  local dir = noctalia.state.get("dir") or ""
  local default = ""
  if mode == "rename" then
    default = item.name
  elseif mode == "new_folder" then
    default = model.uniqueName(dir, noctalia.tr("dialog.default_folder"), "")
  else
    default = model.uniqueName(dir, noctalia.tr("dialog.default_file"), ".txt")
  end

  local W, H = model.outputSize(me)
  local x = clamp(req and req.x or 0, 0, W - model.DIALOG_W - 4)
  local y = clamp(req and req.y or 0, 0, H - model.DIALOG_H - 4)
  -- Dialogs need the keyboard; the plain menu does not, so only grab it here.
  noctalia.layer.configure("menu", {
    width = model.DIALOG_W, height = model.DIALOG_H,
    margins = { top = y, left = x, right = 0, bottom = 0 },
    keyboard = "exclusive",
  })

  typed = default
  req = { kind = "dialog", mode = mode, item = item, default = default, x = x, y = y, nonce = model.nonce() }
  noctalia.state.set("menu", req)
  render()
end

local function confirm()
  local name = noctalia.string.trim(typed or "")
  if req.mode == "rename" then
    send({ op = "rename", path = req.item.path, name = name })
  elseif req.mode == "new_folder" then
    send({ op = "mkdir", name = name })
  else
    send({ op = "touch", name = name })
  end
  close()
end

-- ── menu ───────────────────────────────────────────────────────────────

local function activate(en)
  local item = req and req.item
  local dir = noctalia.state.get("dir") or ""
  local id = en.id

  if id == "rename" then return startDialog("rename", item) end
  if id == "new_folder" then return startDialog("new_folder") end
  if id == "new_file" then return startDialog("new_file") end

  if id == "open" then
    model.openItem(item)
  elseif id == "terminal" then
    send({ op = "terminal", path = item.path })
  elseif id == "copy_path" then
    noctalia.copyToClipboard(item.path, "text/plain")
  elseif id == "trash" then
    send({ op = "trash", path = item.path })
  elseif id == "open_dir" then
    model.openItem({ kind = "dir", path = dir })
  elseif id == "terminal_dir" then
    send({ op = "terminal", path = dir })
  elseif id == "refresh" then
    send({ op = "refresh" })
  elseif id == "settings" then
    noctalia.openSettings()
  elseif string.sub(id, 1, 7) == "custom:" then
    send({ op = "run", command = en.command })
  end
  close()
end

local function renderMenu()
  local rows = {}
  for i, en in ipairs(model.entries(req.kind, req.item)) do
    if en.sep then
      rows[#rows + 1] = ui.separator({ key = "s" .. i, spacing = 3 })
    else
      rows[#rows + 1] = ui.button({
        key = "e" .. i,
        text = en.label, glyph = en.glyph,
        variant = "ghost", controlSize = "sm", contentAlign = "start",
        onClick = function() activate(en) end,
        onHover = onHover,
      })
    end
  end
  layer.render(ui.column({
    flexGrow = 1, padding = model.PAD, gap = 0,
    fill = "surface_container", radius = 0, border = "outline_variant", borderWidth = 1,
    onHover = onHover,
  }, rows))
end

local function renderDialog()
  layer.render(ui.column({
    flexGrow = 1, padding = 14, gap = 10,
    fill = "surface_container", radius = 0, border = "outline_variant", borderWidth = 1,
  }, {
    ui.label({ text = noctalia.tr("dialog." .. req.mode), fontSize = 15, fontWeight = "bold" }),
    ui.input({
      key = "name-" .. tostring(req.nonce),
      value = req.default, focus = true,
      onChange = function(v) typed = v end,
      onSubmit = function(v)
        if v then typed = v end
        confirm()
      end,
    }),
    ui.row({ gap = 8, justify = "end" }, {
      ui.button({ key = "cancel", text = noctalia.tr("dialog.cancel"), variant = "outline", onClick = close }),
      ui.button({ key = "ok", text = noctalia.tr("dialog.ok"), variant = "primary", onClick = confirm }),
    }),
  }))
end

render = function()
  if req == nil then
    layer.render(ui.column({ flexGrow = 1 }, {}))
  elseif req.kind == "dialog" then
    renderDialog()
  else
    renderMenu()
  end
end

noctalia.state.watch("menu", function(v)
  req = v
  if req and req.kind == "dialog" then typed = req.default or typed end
  render()
end)
render()

if noctalia.setUpdateInterval then noctalia.setUpdateInterval(1000) end

function update()
  if req and req.kind == "dialog" then idle = 0 return end
  if hovered then idle = 0 else idle = idle + 1 end
  if idle >= 4 then
    idle = -3
    close()
  end
end

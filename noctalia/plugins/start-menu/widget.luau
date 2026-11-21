--!nonstrict
-- The start button: put it on a bar to open the menu with a click.

local U = require("./lib/util.luau")

barWidget.setGlyph(noctalia.getConfig("glyph") or "brand-windows")
barWidget.setTooltip(noctalia.tr("widget.tooltip"))

function onClick()
  local id = U.trim(noctalia.getConfig("panel_id") or "")
  if id == "" then id = "you/start-menu:menu" end
  noctalia.togglePanel(id)
end

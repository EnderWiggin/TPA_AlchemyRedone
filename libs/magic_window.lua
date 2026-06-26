---@meta

---@class openmw.interfaces
---@field MagicWindow? openmw.interfaces.MagicWindow

---@class openmw.interfaces.MagicWindow
---@field Templates openmw.interfaces.MagicWindow.Templates
---@field Spells openmw.interfaces.MagicWindow.Spells
---@field getStat fun(stat: string): openmw.interfaces.MagicWindow.TrackedStat?

---@class openmw.interfaces.MagicWindow.TrackedStat
---@field spells? table<string, boolean>
---@field magicItems? table<string, boolean>

---@class openmw.interfaces.MagicWindow.Spells
---@field getCustomEffect fun(spellId: string): openmw.core.MagicEffect

---@class openmw.interfaces.MagicWindow.Templates
---@field MAGIC openmw.interfaces.MagicWindow.Templates.Magic

---@class openmw.interfaces.MagicWindow.Templates.Magic
---@field spellTooltip fun(spellId: string):openmw.ui.Layout
---@field itemTooltip fun(item: openmw.Object):openmw.ui.Layout


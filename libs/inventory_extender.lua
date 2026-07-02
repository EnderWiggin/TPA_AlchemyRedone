---@meta

---@class openmw.interfaces
---@field InventoryExtender? openmw.interfaces.InventoryExtender

---@class openmw.interfaces.InventoryExtender
---@field registerTooltipModifier fun(id: string, modifier: InventoryExtender.TooltipModifierFn)


---@alias InventoryExtender.TooltipModifierFn fun(item: GameObject, layout: openmw.ui.Layout):openmw.ui.Layout|nil

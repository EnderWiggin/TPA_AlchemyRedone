---@meta

---@class openmw.interfaces
---@field SharedTooltip? openmw.interfaces.SharedTooltip

---@class openmw.interfaces.SharedTooltip
---@field registerModifier fun(opts:SharedTooltip.TipModifier)

---@class SharedTooltip.TipModifier
---@field id string
---@field priority number
---@field func fun(tip:SharedTooltip.TipContext)


---@class SharedTooltip.TipContext
---@field info table
---@field record {id:string}
---@field flex openmw.ui.Layout
---@field printEffects fun(target:openmw.ui.Layout, effects:table[], isAlchemy?:boolean|"potion")

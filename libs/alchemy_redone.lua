---@meta

---@class openmw.interfaces
---@field TPA_AlchemyRedone? openmw.interfaces.TPA_AlchemyRedone

---@class openmw.interfaces.TPA_AlchemyRedone
---@field apiVersion integer
---@field isEnabled fun():boolean
---@field registerPotionModifier fun(modId: string, mod:TPA_AlchemyRedone.PotionModifier) `mod` should either return new draft record, or modify passed one
---@field unregisterPotionModifier fun(modId: string) removes potion modifier
---@field getKnownEffectFlagsForItem fun(item: openmw.Object): boolean[]

---@class PotionModifierOpts
---@field isPoison boolean?
---@field isPreview boolean?

---@alias TPA_AlchemyRedone.PotionModifier fun(draft:openmw.types.PotionRecord, ingredients:string[], opts: PotionModifierOpts):openmw.types.PotionRecord?

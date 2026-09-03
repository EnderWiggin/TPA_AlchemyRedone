---@omw-context player

local core = require 'openmw.core'
local types = require 'openmw.types'
local ui = require 'openmw.ui'
local player = require 'openmw.self'

local cfgPlayer = require 'scripts.TPABOBAP.AlchemyRedone.config.player'
local cfgGlobal = require 'scripts.TPABOBAP.AlchemyRedone.config.global'

local I = require 'openmw.interfaces'
local A = require 'scripts.TPABOBAP.AlchemyRedone.alchemy'
local AH = require 'scripts.TPABOBAP.AlchemyRedone.helpers'
local TH = require 'scripts.UIToolkit.helpers'

---@class AlchemyRedone.Integration.InventoryExtender
local M = {}

function M.register()
    if not I.InventoryExtender then return end
    I.InventoryExtender.registerTooltipModifier('alchemy-redone', M.modifyIETooltip)
end

---@param item GameObject
---@param layout openmw.ui.Layout
---@return openmw.ui.Layout?
function M.modifyIETooltip(item, layout)
    if not cfgGlobal.rework.b_Enabled or not cfgPlayer.main.b_Enabled then return end
    if item.type == types.Potion or item.type == types.Ingredient then
        local effects = TH.findLayoutByPathSafe(layout, { 'padding', 'tooltip', 'effects' })
        if not effects then return end
        effects.content = M.getIEMagicEffectsContent(item, player)
    end
end

function M.getTooltipMagicEffectEntries(item, actor)
    local itemRecord = item.type.record(item)
    local effectsToShow = {}
    local enchantment

    if itemRecord.enchant then
        enchantment = core.magic.enchantments.records[itemRecord.enchant]
    end

    if enchantment then
        local override = I.MagicWindow and I.MagicWindow.Spells.getCustomSpell(itemRecord.enchant)
        for _, effect in ipairs(override and override.effects or enchantment.effects) do
            table.insert(effectsToShow, {
                effect = effect,
                visible = true,
                text = AH.createSpellEffectString(effect,
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.ConstantEffect),
            })
        end
    elseif types.Potion.objectIsInstance(item) or types.Ingredient.objectIsInstance(item) then
        local isPotion = types.Potion.objectIsInstance(item)
        local known
        if isPotion then
            known = A.getKnownEffectFlagsForPotion(item.recordId, actor)
        else
            known = A.getKnownEffectFlagsForIngredient(item.recordId, actor)
        end
        for i = 1, #itemRecord.effects do
            local effect = itemRecord.effects[i]
            if effect then --some TR Data ingredients have gaps in effects
                local isVisible = known[i]
                local effectText = nil
                if isVisible then
                    if isPotion then
                        effectText = AH.createSpellEffectString(effect, false, true)
                    else
                        effectText = AH.getMagicEffectString(effect)
                    end
                end

                table.insert(effectsToShow, {
                    effect = effect,
                    visible = isVisible,
                    text = effectText,
                })
            end
        end
    end

    return effectsToShow
end

local ok, IET = pcall(require, 'scripts/InventoryExtender/ui/templates/base.lua')

local function getIconSz()
    if ok then return IET.TEXT_SIZE end
    return I.UIToolkit.getTheme().Sizes.textNormal
end

local function textNormal(name, text)
    return { name = name, template = ok and IET.textNormal or I.MWUI.templates.textNormal, props = { text = text } }
end

function M.getIEMagicEffectsContent(item, actor)
    local T = I.UIToolkit.Templates
    local effectsToShow = M.getTooltipMagicEffectEntries(item, actor)

    -- Build effect layouts if we have any effects
    if #effectsToShow > 0 then
        local effectLayouts = {}
        for i, effectData in ipairs(effectsToShow) do
            local effect = effectData.effect
            local isVisible = effectData.visible
            local content = ui.content {}

            if isVisible then
                content:add(T.effectIcon(effect.id, getIconSz()))
                content:add(T.intervalH(4))
                local effectText = effectData.text or '?'
                content:add(textNormal('effect_' .. i, effectText))
            else
                content:add(textNormal('effect_' .. i, '?'))
            end

            local effectLayout = {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = content,
            }

            if i ~= 1 then
                table.insert(effectLayouts, T.intervalV(8))
            end
            table.insert(effectLayouts, effectLayout)
        end

        return ui.content { table.unpack(effectLayouts) }
    end
    return ui.content {}
end

return M

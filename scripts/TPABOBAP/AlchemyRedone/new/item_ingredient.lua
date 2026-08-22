---@omw-context player

local ui = require('openmw.ui')
local util = require('openmw.util')
local player = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local v2 = util.vector2
local cfgPlayer = require("scripts.TPABOBAP.AlchemyRedone.config.player")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

local Class = require('scripts.UIToolkit.class')
local ListItemColumn = require('scripts.UIToolkit.components.list_items.column_item')

---@class AlchemyRedone.ListData.Ingredient : UIToolkit.ListData.Base
---@field count integer
---@field icon string
---@field name string
---@field searchText string
---@field isActive fun():boolean

---@class AlchemyRedone.ListItemIngredient: UIToolkit.ListItem.Column
---@field new fun(self:AlchemyRedone.ListItemIngredient):AlchemyRedone.ListItemIngredient
local ListItemIngredient = Class(ListItemColumn)

---@param data AlchemyData
---@param ingredient string
---@param effectWidth number
---@param rowHeight number
---@param active boolean
---@return openmw.ui.Element
local function renderEffects(data, ingredient, effectWidth, rowHeight, active)
    local record = types.Ingredient.record(ingredient)
    local effects = record and record.effects or {}
    local sz = cfgPlayer.text.content
    local content = ui.content {}
    local known = A.getKnownEffectFlagsForIngredient(record, player)
    local nonMatching = data.nonMatching
    local notActive = not active

    for i = 1, 4 do
        if #effects >= i and effects[i] then
            local effect = effects[i]
            local bright = known[i]
            if bright and nonMatching and #nonMatching > 0 then
                local idx = A.containsEffect(nonMatching, effect)
                bright = idx ~= nil and data.nonMatchingKnowledge[idx] and notActive
            end
            content:add({
                name = 'effect_' .. i,
                type = ui.TYPE.Image,
                props = {
                    resource = known[i] and I.UIToolkit.Templates.effectIconTexture(effect.id)
                        or I.UIToolkit.texture 'icons/UIToolkit/unknown-effect.dds',
                    anchor = v2(0, 0.5),
                    relativePosition = v2(0, 0.5),
                    position = v2((sz + 3) * (i - 1), 0),
                    size = v2(sz, sz),
                    alpha = bright and 1 or 0.5
                }
            })
        end
    end
    return ui.create {
        name = 'effects',
        props = {
            size = v2(effectWidth, rowHeight),
        },
        content = content,
    }
end


---@param data AlchemyData
---@param textSize number
function ListItemIngredient:init(data, textSize)
    local rowHeight = 1.5 * (textSize + 2)
    local effectWidth = 4 * (textSize + 3)
    self.data = data
    self.effectWidth = effectWidth
    self.textSize = textSize
    local function _renderEffects(row, _, height) return renderEffects(data, row.id, effectWidth, height, row.isActive()) end
    ListItemColumn.init(self --[[@as UIToolkit.ListItem.Column]], {
        { id = 'icon',    render = ListItemColumn.renderIcon, width = rowHeight + 5 },
        { id = 'name',    render = ListItemColumn.renderText },
        { id = 'effects', render = _renderEffects,            width = effectWidth },
    }, rowHeight)
end

return ListItemIngredient

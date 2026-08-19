---@omw-context player

local ui = require('openmw.ui')
local util = require('openmw.util')
local player = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local v2 = util.vector2
local T = require('scripts.UIToolkit.templates.base')
local Base = require("scripts.TPABOBAP.UIToolkit.templates.base")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

local Class = require('scripts.UIToolkit.class')
local Component = require('scripts.UIToolkit.components.component')
local ListItemBase = require('scripts.UIToolkit.components.list_items.base_item')


local UNKNOWN_EFFECT = Base.createTexture('icons/TPABOBAP/AlchemyRedone/unknown-effect.png')
---@class AlchemyRedone.ListData.Ingredient : UIToolkit.ListData.Base
---@field count integer
---@field name string
---@field searchText string
---@field isActive fun():boolean

---@class AlchemyRedone.ListItemIngredient: UIToolkit.ListItem.Base<AlchemyRedone.ListData.Ingredient>
local ListItemIngredient = Class(ListItemBase)

---@param data AlchemyData
---@param rowHeight number
---@param effectWidth number
function ListItemIngredient:init(data, rowHeight, effectWidth)
    self.data = data
    self.rowHeight = rowHeight
    self.effectWidth = effectWidth
end

---@param ingredient string
---@param sz number
---@return openmw.ui.Element
local function renderIngredientIcon(ingredient, sz)
    local record = types.Ingredient.record(ingredient)
    return ui.create {
        name = 'icon',
        type = ui.TYPE.Image,
        props = {
            resource = record and Base.createTexture(record.icon),
            size = v2(sz, sz),
        }
    }
end

---@param ingredient string
---@param width number
---@param size openmw.util.Vector2
---@param active boolean
---@return openmw.ui.Element
function ListItemIngredient:renderEffects(ingredient, width, size, active)
    local data = self.data
    local record = types.Ingredient.record(ingredient)
    local effects = record and record.effects or {}
    local sz = Base.TEXT_SIZE_CONTENT
    local content = ui.content {}
    local known = A.getKnownEffectFlagsForIngredient(record, player)
    local nonMatching = data.nonMatching
    local notActive = not active
    local brightKey = {}
    local knownKey = {}

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
                    resource = known[i] and Base.effectIconTexture(effect.id) or UNKNOWN_EFFECT,
                    anchor = v2(0, 0.5),
                    relativePosition = v2(0, 0.5),
                    position = v2((sz + 3) * (i - 1), 0),
                    size = v2(sz, sz),
                    alpha = bright and 1 or 0.5
                }
            })
            table.insert(brightKey, tostring(bright))
            table.insert(knownKey, tostring(known[i]))
        end
    end
    return {
        name = 'effects',
        props = {
            position = v2(size.x - self.effectWidth, 0),
            size = v2(width, size.y),
        },
        content = content,
        userData = {
            --TODO: don't think this is actually used?
            brightKey = table.concat(brightKey, ':'),
            knownKey = table.concat(knownKey, ':'),
        }
    }
end

---@param data AlchemyRedone.ListData.Ingredient
---@param size openmw.util.Vector2
---@return openmw.ui.Element
function ListItemIngredient:makeNewElement(data, size)
    local active = data.isActive()
    local icon = renderIngredientIcon(data.id, self.rowHeight)
    local text = {
        name = 'text',
        template = T.text(),
        props = {
            position = v2(self.rowHeight + 5, 0),
            size = v2(size.x - self.rowHeight - 5 - self.effectWidth, size.y),
            textAlignV = ui.ALIGNMENT.Center,
            autoSize = false,
            text = data.name,
        },
        userData = { colorable = true },
    }

    local effects = self:renderEffects(data.id, self.effectWidth, size, active)

    return ui.create {
        name = 'ingredient:' .. data.id,
        props = { size = size, },
        content = ui.content { icon, text, effects },
        userData = { active = active }
    }
end

---@param data AlchemyRedone.ListData.Ingredient
---@param size openmw.util.Vector2
---@param old openmw.ui.Element
function ListItemIngredient:updateElement(data, size, old)
    ---@type openmw.ui.Content
    local content = old.layout.content
    ---@type openmw.ui.Layout
    local layout
    local props

    --update text size and position
    layout = content[2]
    props = layout.props
    props.position = v2(self.rowHeight + 5, 0)
    props.size = v2(size.x - self.rowHeight - 5 - self.effectWidth, size.y)

    --update effect position
    layout = content[3]
    props = layout.props
    props.position = v2(size.x - self.effectWidth, 0)

    old.layout.props.size = size
    I.UIToolkit.queueUpdate(old)
end

---@param data AlchemyRedone.ListData.Ingredient
---@param size openmw.util.Vector2
---@param old UIToolkit.Component?
---@return UIToolkit.Component
function ListItemIngredient:makeComponent(data, size, old)
    local component = old or Component:new()

    if component:isDestroyed() then
        component:init(self:makeNewElement(data, size))
    else
        self:updateElement(data, size, component.element)
    end

    return component
end

---@param data AlchemyRedone.ListData.Ingredient
---@return UTKTooltips.Tooltip?
function ListItemIngredient:getTooltip(data)
    ---@type UTKTooltips.Tooltip
    return { type = I.UTKTooltips.TYPE.Ingredient, key = data.id, observer = player }
end

return ListItemIngredient

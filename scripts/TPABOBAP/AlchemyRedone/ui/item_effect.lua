---@omw-context player

local ui = require('openmw.ui')
local util = require('openmw.util')
local I = require('openmw.interfaces')
local v2 = util.vector2

local Class = require('scripts.UIToolkit.class')
---@type UIToolkit.ListItem.Column
local ListItemColumn = require('scripts.UIToolkit.components.list_items.column_item')

---@class AlchemyRedone.ListData.Effect: UIToolkit.ListData.Column
---@field effectId string
---@field affectedAttribute string?
---@field affectedSkill string?
---@field displayName string
---@field icon string?
---@field searchText string
---@field isFavorite fun():boolean

---@type UIToolkit.ListItem.Column.Renderer
---@param data AlchemyRedone.ListData.Effect
local function renderBookmark(data, cfg, height)
    local sz = math.min(height, cfg.width or height)
    ---@type openmw.ui.Layout
    local layout = {
        name = cfg.id,
        type = ui.TYPE.Widget,
        props = {},
        content = ui.content { {
            name = 'bookmark',
            type = ui.TYPE.Image,
            props = {
                resource = I.UIToolkit.texture('icons/TPABOBAP/AlchemyRedone/favorite.dds'),
                size = v2(sz, sz),
                anchor = v2(0, 0.5),
                relativePosition = v2(0, 0.5),
                color = I.UIToolkit.getTheme().Colors.DISABLED,
                visible = data.isFavorite(),
            },
        } },
    }

    ListItemColumn.applySize(layout, cfg, height)
    return ui.create(layout)
end

---@class AlchemyRedone.ListItemEffect: UIToolkit.ListItem.Column
---@field new fun(self:AlchemyRedone.ListItemEffect):AlchemyRedone.ListItemEffect
local ListItemEffect = Class(ListItemColumn)

---@param textSize number
function ListItemEffect:init(textSize)
    local rowHeight = 1.5 * (textSize + 2)
    self.textSize = textSize

    ListItemColumn.init(self --[[@as UIToolkit.ListItem.Column]], {
        { id = 'icon',        render = ListItemColumn.renderIcon, width = rowHeight + 5, arg = { sz = textSize * 1.5 } },
        { id = 'displayName', render = ListItemColumn.renderText },
        { id = 'favorite',    render = renderBookmark,            width = rowHeight },
    }, rowHeight)
end

return ListItemEffect

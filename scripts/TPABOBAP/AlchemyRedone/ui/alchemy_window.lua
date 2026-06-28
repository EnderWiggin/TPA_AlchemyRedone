---@omw-context player

local core = require("openmw.core")
local ui = require("openmw.ui")
local util = require("openmw.util")
local types = require("openmw.types")
local async = require('openmw.async')
local player = require('openmw.self')
local ambient = require('openmw.ambient')
local auxUi = require('openmw_aux.ui')

local I = require("openmw.interfaces")
local T = {
    Base = require("scripts.UIToolkit.templates.base"),
    Special = require("scripts.UIToolkit.templates.special"),
}
local S = require("scripts.UIToolkit.templates.special")
local C = require("scripts.UIToolkit.constants")
local H = require("scripts.UIToolkit.helpers")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

local Window = require("scripts.UIToolkit.window")

local MWUI = I.MWUI.templates
local v2 = util.vector2
local REVERT_PATH = 'icons/TPABOBAP/AlchemyRedone/revert.png'

local ApparatusTypes = types.Apparatus.TYPE

---@class AlchemyWindow: Window
---@field protected ctx AlchemyContext
---@field private data AlchemyData
local AlchemyWindow = Window:new()

---@return AlchemyWindow
function AlchemyWindow:new()
    local r = Window.new(self)
    ---@cast r AlchemyWindow
    return r
end

local parts = {}

local Slots = { 'First', 'Second', 'Third', 'Fourth' }
local MIN_SIZE = v2(730, 380) --TODO: update with font sizes?

local BLOCK_WIDTH = 350
local EFFECTS_WIDTH = 300
local ICON_SZ
local GAP_END
local GAP_MID
local GAP_ICON
local GAP_EFFECT
local function updateSizes()
    ICON_SZ = util.round(T.Base.TEXT_SIZE * 1.5)
    GAP_ICON = 3
    GAP_END = util.round((ICON_SZ - T.Base.TEXT_SIZE) / 2)
    GAP_MID = 2 * GAP_END + GAP_ICON
    GAP_EFFECT = 8
end

updateSizes()

---@param ctx AlchemyContext
function AlchemyWindow:init(ctx)
    self:setContext(ctx)
    self.data = ctx.data
    local naming
    naming, self.naming = parts.naming(function() return self:getDefaultPotionName() end)

    self.btnCreate = T.Special.button(C.Strings.CREATE, {
        name = 'btnCreate',
        onClick = function() self:createPotion() end,
        canClick = function() return not self.btnCreate.layout.userData.disabled end
    }, self.ctx)

    local counting
    counting, self.counting = parts.countBlock()

    local content = ui.content {
        {
            name = 'content',
            type = ui.TYPE.Widget,
            props = {},
            content = ui.content {
                {
                    name = 'main',
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = false,
                        position = v2(10, 10)
                    },
                    content = ui.content {
                        naming,
                        T.Base.intervalV(15),
                        {
                            name = 'panel',
                            type = ui.TYPE.Flex,
                            props = {
                                horizontal = true,
                            },
                            content = ui.content {
                                {
                                    name = 'left',
                                    type = ui.TYPE.Flex,
                                    props = {},
                                    content = ui.content {
                                        parts.tools(),
                                        T.Base.intervalV(15),
                                        parts.selected(ctx,
                                            function(n)
                                                local r = self:getSelectedIngredientRecord(n)
                                                return r and r.id
                                            end,
                                            function(n)
                                                self:onIngredientClicked(n)
                                            end,
                                            function(n)
                                                return self:makeIngredientTip(n)
                                            end),
                                    }
                                },
                                T.Base.intervalH(15),
                                {
                                    name = 'right',
                                    type = ui.TYPE.Flex,
                                    props = {
                                        autoSize = false,
                                        size = v2(200, 300)
                                    },
                                    content = ui.content {
                                        parts.resultingEffects()
                                    }
                                },
                            }
                        },
                    },
                },
                {
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = true,
                        anchor = v2(1, 1),
                        relativePosition = v2(1, 1),
                        position = v2(-10, -10),
                    },
                    content = ui.content {
                        counting,
                        T.Base.intervalH(50),
                        self.btnCreate,
                    },
                },
            },
        }
    }
    self.element = T.Base.window(core.getGMST('sSkillAlchemy'), content, self.ctx, {
        noResize = true,
        draggable = true,
        onDrag = function()
            self:updateSize()
        end
    })
    self.element.layout.userData.minWidth = MIN_SIZE.x
    self.element.layout.userData.minHeight = MIN_SIZE.y
    self:setDimensions({ x = 0.35, y = 0.25, w = 0.3, h = 0.3 })
    self:setSize(MIN_SIZE)
    self:updateSize()
end

function AlchemyWindow:updateSize()
    if not self.element then return end
    local inner = self.element.layout.userData.getInnerSize()

    local content = H.findLayoutByPath(self.element, { 'foreground', 'body', 'content' })
    content.props.size = inner
    local right = H.findLayoutByPath(self.element, { 'foreground', 'body', 'content', 'main', 'panel', 'right' })
    right.props.size = v2(inner.x / 2, inner.y)
end

function AlchemyWindow:update(deep)
    if not self.element then return end
    updateSizes()
    self:updateMatchingEffects()
    local panel = H.findLayoutByPath(self.element, { 'foreground', 'body', 'content', 'main', 'panel' })

    local tools = H.findLayoutByPath(panel, { 'left', 'tools-block', 'tools-box', 'padding', 'tools' })
    local function updateTool(name, type)
        local record = self:getToolRecord(type)
        local layout = H.findLayoutByPath(tools, { 'name', name })
        layout.props.text = record and record.name or C.Strings.NONE

        layout = H.findLayoutByPath(tools, { 'quality', name })
        layout.props.text = record and 'x' .. record.quality or ''

        layout = H.findLayoutByPath(tools, { 'icon', name })
        layout.props.resource = record and T.Base.createTexture(record.icon)
    end

    updateTool(C.Strings.MORTAR, ApparatusTypes.MortarPestle)
    updateTool(C.Strings.ALEMBIC, ApparatusTypes.Alembic)
    updateTool(C.Strings.CALCINATOR, ApparatusTypes.Calcinator)
    updateTool(C.Strings.RETORT, ApparatusTypes.Retort)

    local selected = H.findLayoutByPath(panel, { 'left', 'selected-block', 'selected-box', 'padding', 'selected' })
    local function updateSelected(n)
        local record, amount = self:getSelectedIngredientRecord(n)
        local name = H.findLayoutByPath(selected, { 'name', Slots[n] })
        local icon = H.findLayoutByPath(selected, { 'icon', Slots[n] })

        if record and amount > 0 then
            local effects = record.effects
            name.props.text = record.name .. ' (' .. H.addSeparators(amount) .. ')'
            icon.props.resource = T.Base.createTexture(record.icon)
            local known = A.getKnownEffectFlagsForIngredient(record, player)
            for i = 1, 4 do
                icon = H.findLayoutByPath(selected, { 'effects', Slots[n], 'effect_' .. i })
                if #effects >= i then
                    local effect = effects[i]
                    if known[i] then
                        icon.props.resource = T.Base.effectIconTexture(effect.id)
                        icon.props.alpha = A.containsEffect(self.data.matching, effect) and 1 or 0.5
                    else
                        icon.props.resource = T.Special.TEX.UNKNOWN_EFFECT
                        icon.props.alpha = 0.5
                    end
                else
                    icon.props.resource = nil
                end
            end
        else
            name.props.text = C.Strings.NONE
            icon.props.resource = nil

            for i = 1, 4 do
                icon = H.findLayoutByPath(selected, { 'effects', Slots[n], 'effect_' .. i })
                icon.props.resource = nil
            end
        end
    end
    for i = 1, #Slots do
        updateSelected(i)
    end

    local effects = H.findLayoutByPath(panel, { 'right', 'result-block', 'result-box', 'padding', 'effect-list' })
    for i = 1, #effects.content do
        auxUi.deepDestroy(effects.content[i])
    end
    local effectCount = 8 --min 4 for beauty
    effects.content = ui.content {}

    if self.data.matching then
        effectCount = math.max(effectCount, #self.data.matching)
        local effectLayouts = {}
        for i = 1, #self.data.matching do
            local effect = self.data.matching[i]
            local isVisible = self.data.matchingKnowledge[i] ~= false
            local content = ui.content {}

            if isVisible then
                content:add(T.Special.effectIcon(effect.id))
                content:add(T.Base.intervalH(4))
                local effectText = H.getMagicEffectString(effect) or '?'
                content:add({ name = 'effect_' .. i, template = T.Base.textNormal, props = { text = effectText } })
            else
                content:add({ name = 'effect_' .. i, template = T.Base.textNormal, props = { text = '?' } })
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
                table.insert(effectLayouts, T.Base.intervalV(GAP_EFFECT))
            end
            table.insert(effectLayouts, effectLayout)
        end


        effects.content:add({
            name = 'effects',
            type = ui.TYPE.Flex,
            props = {
                arrange = ui.ALIGNMENT.Start,
            },
            content = ui.content {
                table.unpack(effectLayouts)
            }
        })
    end
    effects.props.size = v2(EFFECTS_WIDTH, T.Base.TEXT_SIZE * effectCount + GAP_EFFECT * (effectCount - 1))

    Window.update(self, deep)
end

function AlchemyWindow:updateData()
    if not self.element then return end
    parts.setInteractiveState(self.btnCreate, false, false)
    self:update(true)
end

---@param type number
---@return openmw.types.ApparatusRecord?
function AlchemyWindow:getToolRecord(type)
    ---@type LocalApparatusIds?
    local apparatus = self.data and self.data.apparatus
    if not apparatus then return nil end
    if type == ApparatusTypes.MortarPestle then
        return apparatus.Mortar and types.Apparatus.records[apparatus.Mortar]
    elseif type == ApparatusTypes.Calcinator then
        return apparatus.Calcinator and types.Apparatus.records[apparatus.Calcinator]
    elseif type == ApparatusTypes.Alembic then
        return apparatus.Alembic and types.Apparatus.records[apparatus.Alembic]
    elseif type == ApparatusTypes.Retort then
        return apparatus.Retort and types.Apparatus.records[apparatus.Retort]
    end
    return nil
end

---@param n number
---@return openmw.types.IngredientRecord?, number
function AlchemyWindow:getSelectedIngredientRecord(n)
    if self.data and self.data.selected then
        local recordId = self.data.selected[n]
        if recordId then
            return types.Ingredient.records[recordId], self.data.ingredients[recordId] or 0
        end
    end
    return nil, 0
end

function AlchemyWindow:makeIngredientTip(n)
    if not self.data.selected then return nil end
    local recordId = self.data.selected[n]
    if recordId then
        return T.Special.ingredientTooltip(recordId, player)
    end
    return nil
end

function AlchemyWindow:onIngredientClicked(n)
    if self.data and self.data.selected then
        self.data.selected[n] = nil
        self:update()
        self.ctx.updateIngredients(true)
    end
end

---@param info {id: string, count:integer}
function AlchemyWindow:onSelectIngredient(info)
    if not self.data.selected then self.data.selected = {} end

    --Try to remove already selected ingredient
    for i = 1, 4 do
        local recordId = self.data.selected[i]
        if recordId and recordId == info.id then
            self.data.selected[i] = nil
            self:update(true)
            return true
        end
    end

    --Try to add newly selected ingredient
    for i = 1, 4 do
        if not self.data.selected[i] then
            self.data.selected[i] = info.id
            self:update(true)
            return true
        end
    end

    return false
end

---@return string[]
function AlchemyWindow:getSelectedIngredientList()
    local ids = {}
    local selected = self.data.selected
    if selected then
        for i = 1, 4 do
            local recordId = selected[i]
            if recordId then
                table.insert(ids, recordId)
            end
        end
    end
    return ids
end

function AlchemyWindow:getDefaultPotionName()
    ---@type MagicEffectWithParams[]
    local matching = self.data.matching
    if matching and #matching > 0 then
        return H.getMagicEffectString(matching[1])
    end
    return ''
end

function AlchemyWindow:updateMatchingEffects()
    local ingredients = self:getSelectedIngredientList()
    self.data.matching, self.data.matchingKnowledge = A.getMatchingEffects(ingredients, player)
    self.naming.setText(self:getDefaultPotionName())
end

function AlchemyWindow:createPotion()
    local name = self.naming.getText()
    local ingredients = self:getSelectedIngredientList()
    local draft, errorCode = A.getPotionStats(name, ingredients, self.data.apparatus or {}, player)
    local effects = draft.effects
    local count = self.counting.getCount() --TODO: clamp to min amount ingredient
    local brewed = 0

    if errorCode == A.PotionErrors.OK then
        for _ = 1, count do
            if A.checkPotionBrewSuccess(player) then
                brewed = brewed + 1
                --TODO: grant skill use success XP
            else
                --TODO: optionally grant skill use failure XP
            end
        end

        if brewed <= 0 then
            errorCode = A.PotionErrors.FAIL
        else
            local msg = core.getGMST(A.PotionErrors.OK)
            if brewed > 1 then
                msg = msg .. ' ' .. name .. ' (' .. H.addSeparators(brewed) .. ')'
            end
            ui.showMessage(msg)
            ambient.playSound('potion success', { scale = false })
        end
    end

    if errorCode == A.PotionErrors.FAIL then
        ui.showMessage(core.getGMST(A.PotionErrors.FAIL))
        ambient.playSound('potion fail', { scale = false })
        self:deductIngredients(ingredients, count)
        return
    elseif errorCode ~= A.PotionErrors.OK then
        ui.showMessage(core.getGMST(errorCode))
        return
    end

    for i = 1, #effects do
        --this field can't be sent with event and it is not required to create new record
        effects[i].effect = nil
    end

    self:deductIngredients(ingredients, count)
    local potion = A.findPotion(draft)
    if potion then
        core.sendGlobalEvent('TPA_AlchemyRedone_AddItem', { actor = player, recordId = potion.id, count = brewed })
    else
        core.sendGlobalEvent('TPA_AlchemyRedone_CreateAndAddNewPotion', { draft = draft, actor = player, count = brewed })
    end
end

---@param ingredients string[]
---@param count integer
function AlchemyWindow:deductIngredients(ingredients, count)
    parts.setInteractiveState(self.btnCreate, false, true)

    core.sendGlobalEvent('TPA_AlchemyRedone_DeductIngredients', {
        actor = player,
        sources = self.data.sources,
        ingredients = ingredients,
        count = count,
    })
end

function AlchemyWindow:destroy()
    self.data = nil
    Window.destroy(self)
end

---@param defaultText fun():string
parts.naming = function(defaultText)
    local path = { 'nameBar', 'padding', 'textEdit' }
    local name = defaultText()
    local element
    local wdg = {
        setText = function(text)
            local txt = H.findLayoutByPath(element, path)
            txt.props.text = text
            name = text
            element:update()
        end,
        getText = function() return name end,
    }

    local btn = T.Base.imageButton(REVERT_PATH, v2(T.Base.TEXT_SIZE, T.Base.TEXT_SIZE), function()
        wdg.setText(defaultText())
    end, 'btn-revert')

    element = ui.create {
        name = 'naming',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            --gap = 10, --TODO: this is not in 0.51, hope for 0.52
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            {
                template = T.Base.textNormal,
                props = {
                    text = C.Strings.NAME,
                },
            },
            T.Base.intervalH(10),
            {
                name = 'nameBar',
                template = I.MWUI.templates.box,
                content = ui.content {
                    {
                        name = 'padding',
                        template = I.MWUI.templates.padding,
                        content = ui.content {
                            {
                                name = 'textEdit',
                                template = T.Base.textEditLine,
                                props = {
                                    size = v2(300, T.Base.TEXT_SIZE),
                                    text = name,
                                    textColor = C.Colors.DEFAULT_LIGHT,
                                },
                                events = {
                                    textChanged = async:callback(function(text) name = text end),
                                }
                            }
                        }
                    }
                },
            },
            T.Base.intervalH(3),
            btn,
        }
    }

    return element, wdg
end

---@param wdg openmw.ui.Element
---@param active boolean
---@param disabled boolean
parts.setInteractiveState = function(wdg, active, disabled)
    wdg.layout.userData.active = active
    wdg.layout.userData.disabled = disabled
    H.setInteractiveColor(wdg)
    wdg:update()
end

parts.tools = function()
    local box = {
        name = 'tools-box',
        template = T.Base.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.Base.padding(5),
                content = ui.content {
                    {
                        name = 'tools',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            arrange = ui.ALIGNMENT.Start,
                            align = ui.ALIGNMENT.Center,
                            autoSize = false,
                            size = v2(BLOCK_WIDTH, ICON_SZ * 4 + GAP_ICON * 3),
                        },
                        content = ui.content {
                            {
                                name = 'title',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.End,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedTitle(C.Strings.MORTAR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.ALEMBIC),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.CALCINATOR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.RETORT),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'icon',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    parts.namedIcon(C.Strings.MORTAR, ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.ALEMBIC, ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.CALCINATOR, ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.RETORT, ICON_SZ),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'name',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedHeader(C.Strings.MORTAR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.ALEMBIC),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.CALCINATOR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.RETORT),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'quality',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedText(C.Strings.MORTAR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.ALEMBIC),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.CALCINATOR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.RETORT),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                        },
                    }
                },
            }
        }
    }
    return {
        name = 'tools-block',
        type = ui.TYPE.Flex,
        props = {},
        content = ui.content {
            {
                template = T.Base.textNormal,
                props = {
                    text = C.Strings.APPARATUS,
                },
            },
            box,
        }
    }
end

parts.selected = function(ctx, getId, onClick, tooltipFn)
    local box = {
        name = 'selected-box',
        template = T.Base.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.Base.padding(5),
                content = ui.content {
                    {
                        name = 'selected',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            arrange = ui.ALIGNMENT.Start,
                            align = ui.ALIGNMENT.Center,
                            autoSize = false,
                            size = v2(BLOCK_WIDTH, ICON_SZ * 4 + GAP_ICON * 3),
                        },
                        content = ui.content {
                            {
                                name = 'icon',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    parts.namedIcon(Slots[1], ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[2], ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[3], ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[4], ICON_SZ),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'name',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedActiveHeader(Slots[1], ctx,
                                        function() return getId(1) end,
                                        function() onClick(1) end,
                                        function() return tooltipFn(1) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedActiveHeader(Slots[2], ctx,
                                        function() return getId(2) end,
                                        function() onClick(2) end,
                                        function() return tooltipFn(2) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedActiveHeader(Slots[3], ctx,
                                        function() return getId(3) end,
                                        function() onClick(3) end,
                                        function() return tooltipFn(3) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedActiveHeader(Slots[4], ctx,
                                        function() return getId(4) end,
                                        function() onClick(4) end,
                                        function() return tooltipFn(4) end),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'effects',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedEffects(Slots[1]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[2]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[3]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[4]),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                        },
                    }
                },
            }
        }
    }
    return {
        name = 'selected-block',
        type = ui.TYPE.Flex,
        props = {},
        content = ui.content {
            {
                template = T.Base.textNormal,
                props = {
                    text = C.Strings.INGREDIENTS,
                },
            },
            box,
        }
    }
end

parts.namedTitle = function(name)
    return {
        name = name,
        template = T.Base.textNormal,
        props = {
            text = name .. ':',
        },
    }
end

parts.namedHeader = function(name)
    return {
        name     = name,
        template = T.Base.textHeader,
        props    = {
            text = '',
        },
    }
end

parts.namedActiveHeader = function(name, ctx, getId, onClick, tooltipFn)
    local layout = {
        name     = name,
        template = T.Base.textNormal,
        props    = {
            text = '',
        },
        userData = {
            colorable = true,
        },
    }

    return S.interactive({
        onClick = onClick,
        tooltipFn = tooltipFn,
        name = getId and getId() or name
    }, layout, ctx)
end

parts.namedText = function(name)
    return {
        name = name,
        template = T.Base.textNormal,
        props = {
            text = '',
        },
    }
end

parts.namedIcon = function(name, sz)
    sz = sz or T.Base.TEXT_SIZE
    return {
        name = name,
        type = ui.TYPE.Image,
        props = {
            size = v2(sz, sz),
        },
    }
end

parts.effectIcon = function(idx)
    return parts.namedIcon('effect_' .. idx)
end

parts.namedEffects = function(name)
    return {
        name = name,
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
        },
        content = ui.content {
            parts.effectIcon(1),
            T.Base.intervalH(5),
            parts.effectIcon(2),
            T.Base.intervalH(5),
            parts.effectIcon(3),
            T.Base.intervalH(5),
            parts.effectIcon(4),
        },
    }
end

parts.resultingEffects = function()
    local box = {
        name = 'result-box',
        template = T.Base.boxSolid,
        props = {},
        content = ui.content {
            {
                name = 'padding',
                template = T.Base.padding(5),
                content = ui.content {
                    {
                        name = 'effect-list',
                        type = ui.TYPE.Flex,
                        props = {
                            autoSize = false,
                            arrange = ui.ALIGNMENT.Start,
                            align = ui.ALIGNMENT.Start,
                            size = v2(BLOCK_WIDTH, ICON_SZ * 4 + GAP_ICON * 3),
                        },
                        content = ui.content {},
                    }
                }
            },

        }
    }
    return {
        name = 'result-block',
        type = ui.TYPE.Flex,
        props = {},
        content = ui.content {
            {
                name = 'title',
                template = T.Base.textNormal,
                props = {
                    text = C.Strings.CREATED_EFFECTS,
                },
            },
            box,
        }
    }
end

parts.countBlock = function()
    local value = 1
    local element
    local path = { 'countBar', 'padding', 'textEdit' }
    local wdg = {
        setValue = function(v)
            local txt = H.findLayoutByPath(element, path)
            value = math.max(math.floor(v), 1)
            txt.props.text = tostring(value)
            element:update()
        end,
        getCount = function() return value end,
    }

    local function validate(text)
        local number = tonumber(text)
        if not number then
            wdg.setValue(value)
        else
            wdg.setValue(number)
        end
    end

    local btnMinus = T.Base.button('-', function() validate(value - 1) end, 'btn-minus')
    local btnPlus = T.Base.button('+', function() validate(value + 1) end, 'btn-plus')

    element = ui.create {
        name = 'potion-count',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            btnMinus,
            T.Base.intervalH(3),
            {
                name = 'countBar',
                template = I.MWUI.templates.box,
                content = ui.content {
                    {
                        name = 'padding',
                        template = I.MWUI.templates.padding,
                        content = ui.content {
                            {
                                name = 'textEdit',
                                template = T.Base.textEditLine,
                                props = {
                                    size = v2(60, T.Base.TEXT_SIZE),
                                    text = tostring(value),
                                    textColor = C.Colors.DEFAULT_LIGHT,
                                    textAlignH = ui.ALIGNMENT.Center,
                                },
                                events = {
                                    textChanged = async:callback(validate),
                                }
                            }
                        }
                    }
                },
            },
            T.Base.intervalH(3),
            btnPlus,
        }
    }

    return element, wdg
end

return AlchemyWindow

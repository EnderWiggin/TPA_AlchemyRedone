---@omw-context player

local core = require("openmw.core")
local input = require("openmw.input")
local ui = require("openmw.ui")
local util = require("openmw.util")
local types = require("openmw.types")
local async = require('openmw.async')
local player = require('openmw.self')
local auxUi = require('openmw_aux.ui')
local storage = require('openmw.storage')

local settings = storage.playerSection('TPA_AlchemyRedone:AlchemyWindow')
local cfgPlayer = require('scripts.TPABOBAP.AlchemyRedone.config.player')
local cfgGlobal = require('scripts.TPABOBAP.AlchemyRedone.config.global')

local l10n = core.l10n('TPA_AlchemyRedone')
local I = require("openmw.interfaces")
local T = {
    Base    = require("scripts.TPABOBAP.UIToolkit.templates.base"),
    Special = require("scripts.TPABOBAP.UIToolkit.templates.special"),
    Alchemy = require("scripts.TPABOBAP.AlchemyRedone.ui.alchemy"),
}
local S = require("scripts.TPABOBAP.UIToolkit.templates.special")
local C = require("scripts.TPABOBAP.UIToolkit.constants")
local H = require("scripts.TPABOBAP.UIToolkit.helpers")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

local Window = require("scripts.TPABOBAP.UIToolkit.window")

local v2 = util.vector2
local REVERT_PATH = 'icons/TPABOBAP/AlchemyRedone/revert.png'

local ApparatusTypes = types.Apparatus.TYPE

---@class AlchemyWindow: Window
---@field ctx AlchemyContext
---@field data AlchemyData
local AlchemyWindow = Window:new()

---@return AlchemyWindow
function AlchemyWindow:new()
    local r = Window.new(self)
    ---@cast r AlchemyWindow
    return r
end

local parts = {}

local Slots = { 'First', 'Second', 'Third', 'Fourth' }
local MIN_SIZE = v2(800, 695) --TODO: update with font sizes?

local BLOCK_WIDTH = 350
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
    --Show effects or ingredients?
    self.showEffects = false

    --Are we making potion or poison?, default: false
    self.isPoison = settings:get('isPoison') == true
    --Show only ingredients that have effects present in selected ingredients but not matched yet, default: false
    self.filterMatchingIngredients = settings:get('filterMatchingIngredients') == true
    --Show only effects that match potion type (harmful/positive), default: true
    self.filterMatchingEffects = settings:get('filterToShowMatchingEffects') ~= false

    self.showFullEffects = cfgPlayer.main.b_ShowFullEffectInfo
    ---@type {id:string, text: string}[]
    self.selectedEffects = {}

    local naming
    naming, self.naming = parts.naming(function() return self:getDefaultPotionName() end)
    self.lastDefaultPotionName = self:getDefaultPotionName()

    self.btnCreate = T.Special.button(C.Strings.CREATE, {
        name = 'btnCreate',
        onClick = function() self:createPotion() end,
        canClick = function() return not self.btnCreate.layout.userData.disabled end
    }, self.ctx)

    local btnCancel = T.Special.button(C.Strings.CANCEL, {
        name = 'btnCancel',
        onClick = function() I.UI.removeMode(I.UI.MODE.Alchemy) end
    }, self.ctx)

    local tools
    tools, self.tools = parts.tools(function(type) return self:getToolRecord(type) end)

    local selected
    selected, self.selected = parts.selected(self,
        function(n)
            local r = self:getSelectedIngredientRecord(n)
            return r and r.id
        end,
        function(n)
            self:onIngredientClicked(n)
        end,
        function(n)
            return self:makeIngredientTip(n)
        end)

    self.resultingEffects = parts.resultingEffects(self)

    local counting
    counting, self.counting = parts.countBlock()

    self.itemTable = T.Alchemy.makeIngredientTable(self)
    self.itemTable.layout.userData.setFilter('default', function(row) return self:filterIngredient(row) end)
    self.itemTable.layout.userData.setFilter('effect', function(row) return self:filterIngredientByEffects(row) end)

    local filter
    filter, self.filter = parts.filterInput(self)

    self.effectTable = T.Alchemy.makeEffectTable(self)
    self.effectTable.layout.userData.setFilter('matching', function(row) return self:filterEffectByPotionType(row) end)

    self.tableSelector = parts.tableSelector(self)

    self.toggleFilterMatching = parts.filterMatchingToggle(self)

    self.potionTypeSelector = parts.typeSelector(self)

    local content = self:makeContent(naming, tools, selected, counting, btnCancel, filter)

    self.element = T.Base.window(core.getGMST('sSkillAlchemy'), content, self.ctx, {
        noResize = false,
        draggable = true,
        onDrag = function() self:updateSize() end,
    })

    self:loadState()
    self:updateSize()
end

function AlchemyWindow:loadState()
    self.element.layout.userData.minWidth = MIN_SIZE.x
    self.element.layout.userData.minHeight = MIN_SIZE.y
    local dims = settings:get('dimensions')
    if not dims then
        self:setDimensions({ x = 0.35, y = 0.25, w = 0.3, h = 0.3 })
        self:setSize(MIN_SIZE)
    else
        self:setDimensions(dims)
    end
end

function AlchemyWindow:saveState()
    local dims = self:getDimensions()
    settings:set('dimensions', dims)
    settings:set('isPoison', self.isPoison)
    settings:set('filterMatchingIngredients', self.filterMatchingIngredients)
    settings:set('filterMatchingEffects', self.filterMatchingEffects)
end

function AlchemyWindow:updateSize()
    if not self.element or not self.element.layout then return end
    local inner = self.element.layout.userData.getInnerSize()
    local c = self.element.layout.props.position
    local sz = self.element.layout.props.size
    local tipPos = c + v2(sz.x + 10, sz.y / 2)
    self.itemTable.layout.userData.controllerTooltipPos = tipPos
    self.effectTable.layout.userData.controllerTooltipPos = tipPos

    if self.lastSz and self.lastSz == inner then return end
    self.lastSz = inner

    local content = H.findLayoutByPath(self.element, { 'foreground', 'body', 'content' })
    content.props.size = inner

    local right = H.findLayoutByPath(self.element, { 'foreground', 'body', 'content', 'main', 'panel', 'right' })
    right.props.size = v2(inner.x - BLOCK_WIDTH - 30, inner.y)

    local tableSz = right.props.size - v2(35, 140)
    self.itemTable.layout.userData.resize(tableSz)
    self.effectTable.layout.userData.resize(tableSz)
end

function AlchemyWindow:getActiveTable()
    if self.showEffects then
        return self.effectTable
    else
        return self.itemTable
    end
end

function AlchemyWindow:update(deep)
    if not self.element then return end
    updateSizes()
    self:updateMatchingEffects()

    if deep then
        self.tools.update()
        self.selected.update()
        self.resultingEffects.update()
        self.itemTable.layout.userData.redrawColumns()
        self.effectTable.layout.userData.redrawColumns()
    end

    Window.update(self, deep)
end

function AlchemyWindow:updateData()
    if not self.element then return end
    parts.setInteractiveState(self.btnCreate, false, false)
    self.itemTable.layout.userData.updateData(self.ctx.getAllIngredients())
    self.effectTable.layout.userData.updateData(self.ctx.getAllEffects())
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
    self.ctx.clearSelectedIngredient(n)
end

---@param effect EffectItemData
function AlchemyWindow:onEffectClicked(effect)
    local add = input.isShiftPressed() or input.getAxisValue(input.CONTROLLER_AXIS.TriggerLeft) > 0.6
    local favorite = input.isCtrlPressed() or input.getAxisValue(input.CONTROLLER_AXIS.TriggerRight) > 0.6

    if favorite then
        self:toggleFavoriteEffect(effect.id)
        return
    end
    local idx

    for i = 1, #self.selectedEffects do
        if self.selectedEffects[i].id == effect.id then
            idx = i
            break
        end
    end

    if idx then
        table.remove(self.selectedEffects, idx)
    else
        if add then
            table.insert(self.selectedEffects, { id = effect.id, text = effect.searchText })
        else
            self.selectedEffects = { { id = effect.id, text = effect.searchText } }
            self.showEffects = false
            self.tableSelector.update()
        end
    end

    local terms = {}
    for i = 1, #self.selectedEffects do
        local p = self.selectedEffects[i]
        if p.text and #p.text > 0 then
            table.insert(terms, p.text)
        end
    end
    self.effectTable.layout.userData.refresh()
    self.filter.setText(table.concat(terms, " | "))
    self:onFilterChanged()
end

function AlchemyWindow:onPotionTypeUpdated()
    self.resultingEffects.update()
    self:updateDefaultName()
    if self.showEffects and self.filterMatchingEffects then
        self.effectTable.layout.userData.refresh()
    end
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

function AlchemyWindow:onIngredientSelectionChanged()
    self:updateMatchingEffects()
    self.selected.update()
    self.resultingEffects.update()
    self.itemTable.layout.userData.refresh()
end

function AlchemyWindow:getDefaultPotionName()
    ---@type MagicEffectWithParams[]
    local matching = self.data.matching
    local knowledge = self.data.matchingKnowledge
    local harmful, positive
    if matching and #matching > 0 then
        if cfgGlobal.rework.b_Enabled then
            local m, code, k = self:getTempPotionStats()
            if code == A.PotionErrors.OK or code == A.PotionErrors.FAIL then
                matching = m.effects
                knowledge = k
            end
        end
        for i = 1, #matching do
            if knowledge and knowledge[i] then
                local record = A.getEffectRecord(matching[i].id)
                local name = H.getMagicEffectString(matching[i])
                if record and record.harmful then
                    if not harmful then harmful = name end
                elseif not positive then
                    positive = name
                end
            end
        end
        local name = l10n('Potion_Name_Unknown')
        if self.isPoison then
            name = harmful or positive or name
        else
            name = positive or harmful or name
        end
        if cfgPlayer.main.b_PrefixPotionNames then
            local prefix = self.isPoison and cfgPlayer.main.s_PotionNamePrefixBad
                or cfgPlayer.main.s_PotionNamePrefixGood
            prefix = prefix and H.trim(prefix)
            if prefix and #prefix > 0 then
                name = prefix .. ' ' .. name
            end
        end
        return name
    end
    return ''
end

function AlchemyWindow:updateDefaultName()
    local defaultPotionName = self:getDefaultPotionName()
    if self.lastDefaultPotionName ~= defaultPotionName then
        self.naming.setText(defaultPotionName)
        self.lastDefaultPotionName = defaultPotionName
    end
end

function AlchemyWindow:getTempPotionStats()
    local ingredients = self:getSelectedIngredientList()
    local draft, errorCode, knowledge = A.getPotionStats('temp', ingredients, self.data.apparatus, player,
        { isPoison = self.isPoison })

    if errorCode == A.PotionErrors.OK then
        draft = self.ctx.applyMods(draft, ingredients)
    end
    return draft, errorCode, knowledge
end

function AlchemyWindow:updateMatchingEffects()
    local ingredients = self:getSelectedIngredientList()
    self.data.matching, self.data.matchingKnowledge = A.getMatchingEffects(ingredients, player)
    self.data.nonMatching, self.data.nonMatchingKnowledge = A.getNonMatchingEffects(ingredients, player)
    self:updateDefaultName()
    self.itemTable.layout.userData.refresh()
end

---@param effectKey string
function AlchemyWindow:toggleFavoriteEffect(effectKey)
    if self.data.favoriteEffects[effectKey] then
        self.data.favoriteEffects[effectKey] = nil
    else
        self.data.favoriteEffects[effectKey] = true
    end

    local uData = self.effectTable.layout.userData
    local selected = uData.findContendIdxById(effectKey)
    uData.invalidateCache(effectKey)
    uData.refresh(true)
    if selected then uData.setHoveredRow(selected) end
end

function AlchemyWindow:createPotion()
    parts.setInteractiveState(self.btnCreate, false, true)
    ---@type NameOrGetter
    local name = self.naming.getText()
    if name == self:getDefaultPotionName() then
        name = function() return self:getDefaultPotionName() end
    end
    local aborted = self.ctx.brewPotions(
        name,
        self.counting.getCount(),
        self:getSelectedIngredientList(),
        self.isPoison
    )

    if aborted then
        parts.setInteractiveState(self.btnCreate, false, false)
    end
end

function AlchemyWindow:onFilterChanged(_)
    self.itemTable.layout.userData.refresh()
end

function AlchemyWindow:clearFilter()
    self.filter.setText('')
    self:onFilterChanged()
    self.selectedEffects = {}
    self.effectTable.layout.userData.refresh()
end

function AlchemyWindow:filterIngredient(row)
    local filter = H.trim(self.filter.getText():lower())
    if #filter <= 0 then return true end
    local terms = H.splitString(filter, '|')
    if #terms <= 0 then return true end
    local haystack = row.searchText or T.Alchemy.getIngredientSearchText(row.id, player)
    for i = 1, #terms do
        local term = H.trim(terms[i])
        if #term > 0 and haystack:find(term, 1, true) ~= nil then return true end
    end
    return false
end

---@param row IngredientItemData
function AlchemyWindow:filterIngredientByEffects(row)
    if not self.filterMatchingIngredients then return true end

    -- always allow selected ingredient
    local selected = self:getSelectedIngredientList()
    for i = 1, #selected do
        if selected[i] == row.id then return true end
    end

    local data = self.data
    local record = types.Ingredient.record(row.id)
    local effects = record and record.effects or {}
    local known = A.getKnownEffectFlagsForIngredient(record, player)
    local nonMatching = data.nonMatching
    local noKnown = cfgPlayer.main.b_IngredientEffectMatchingAll
    for i = 1, 4 do
        if #effects >= i then
            local effect = effects[i]
            local bright = noKnown or known[i]
            if bright and nonMatching and #nonMatching > 0 then
                local idx = A.containsEffect(nonMatching, effect)
                bright = idx ~= nil and (noKnown or data.nonMatchingKnowledge[idx])
            end
            if bright then return true end
        else
            break
        end
    end
    return false
end

---@param row EffectItemData
---@return boolean
function AlchemyWindow:filterEffectByPotionType(row)
    if not self.filterMatchingEffects then return true end
    local record = H.getMagicEffectRecord(row.effectId)
    if not record then return true end

    return not self.isPoison == not record.harmful
end

function AlchemyWindow:destroy()
    self.data = nil
    Window.destroy(self)
end

---@param naming openmw.ui.Element|openmw.ui.Layout
---@param tools openmw.ui.Element|openmw.ui.Layout
---@param selected openmw.ui.Element|openmw.ui.Layout
---@param counting openmw.ui.Element|openmw.ui.Layout
---@param btnCancel openmw.ui.Element|openmw.ui.Layout
---@param filter openmw.ui.Element|openmw.ui.Layout
---@return openmw.ui.Content
function AlchemyWindow:makeContent(naming, tools, selected, counting, btnCancel, filter)
    return ui.content {
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
                                    props = {
                                        horizontal = false,
                                    },
                                    content = ui.content {
                                        naming,
                                        T.Base.intervalV(15),
                                        tools,
                                        T.Base.intervalV(15),
                                        selected,
                                        T.Base.intervalV(15),
                                        self.resultingEffects.element,
                                    },
                                },
                                T.Base.intervalH(15),
                                {
                                    name = 'right',
                                    type = ui.TYPE.Flex,
                                    props = {
                                        horizontal = false,
                                    },
                                    external = {
                                        grow = 1,
                                    },
                                    content = ui.content {
                                        {
                                            type = ui.TYPE.Widget,
                                            props = {
                                                relativeSize = v2(1, 0),
                                                size = v2(0, T.Base.TEXT_SIZE),
                                            },
                                            content = ui.content {
                                                self.tableSelector.element,
                                                self.toggleFilterMatching.element,
                                            },
                                        },
                                        T.Base.intervalV(3),
                                        {
                                            name = 'ingredients-box',
                                            template = T.Base.boxSolid,
                                            props = {},
                                            content = ui.content {
                                                {
                                                    name = 'padding',
                                                    template = T.Base.padding(5),
                                                    content = ui.content {
                                                        self.itemTable,
                                                        self.effectTable,
                                                    }
                                                },
                                            }
                                        },
                                        T.Base.intervalV(5),
                                        filter,
                                    },
                                },
                            }
                        },
                    },
                },
                {
                    type = ui.TYPE.Widget,
                    props = {
                        anchor = v2(0, 1),
                        relativePosition = v2(0, 1),
                        relativeSize = v2(1, 0),
                        position = v2(10, -10),
                        size = v2(-20, 50),
                    },
                    content = ui.content {
                        {
                            type = ui.TYPE.Flex,
                            props = {
                                horizontal = true,
                                anchor = v2(0, 1),
                                relativePosition = v2(0, 1),
                            },
                            content = ui.content {
                                counting,
                                T.Base.intervalH(10),
                                self.btnCreate,
                            },
                        },
                        self.potionTypeSelector.element,
                        {
                            type = ui.TYPE.Container,
                            props = {
                                anchor = v2(1, 1),
                                relativePosition = v2(1, 1),
                                --position = v2(-10, 0),
                            },
                            content = ui.content {
                                btnCancel,
                            },
                        },
                    },
                },
            },
        }
    }
end

function AlchemyWindow:onControllerButtonPress(id)
    if not self.element then return end
    local bind = cfgPlayer.controls
    local LT = input.getAxisValue(input.CONTROLLER_AXIS.TriggerLeft) > 0.55
    local RT = input.getAxisValue(input.CONTROLLER_AXIS.TriggerRight) > 0.55
    local activeTable = self:getActiveTable()

    if id == bind.n_SelectPrev then
        local delta = LT and 5 or not RT and 1 or nil
        activeTable.layout.userData.highlightPrevItem(delta)
    elseif id == bind.n_SelectNext then
        local delta = LT and 5 or not RT and 1 or nil
        activeTable.layout.userData.highlightNextItem(delta)
    elseif id == bind.n_CountMore then
        local count = self.counting.getCount()
        if LT then
            count = count + 5
        elseif RT then
            count = 100
        else
            count = count + 1
        end
        self.counting.setValue(count)
    elseif id == bind.n_CountLess then
        local count = self.counting.getCount()
        if LT then
            count = count - 5
        elseif RT then
            count = 1
        else
            count = count - 1
        end
        self.counting.setValue(count)
    elseif id == bind.n_Brew then
        self:createPotion()
    elseif id == bind.n_ClearText then
        if LT then
            self.ctx.clearAllSelectedIngredients()
        elseif RT then
        else
            self:clearFilter()
        end
    elseif id == bind.n_Activate then
        local highlighted = activeTable.layout.userData.getHighlightedRow()
        if highlighted then
            local userData = highlighted.layout.userData
            if userData.onRowUse then
                userData.onRowUse()
                return
            end
        end
    elseif id == bind.n_ToggleType then
        self.isPoison = not self.isPoison
        self.potionTypeSelector.update()
    elseif id == bind.n_ToggleTable then
        if LT then
            self.toggleFilterMatching.onToggleClick()
        elseif RT then
        else
            self.showEffects = not self.showEffects
            self.tableSelector.update()
        end
    end
end

function AlchemyWindow:onControllerButtonRepeat(id)
    if not self.element then return end
    local bind = cfgPlayer.controls
    if id == bind.n_SelectNext or id == bind.n_SelectPrev
        or id == bind.n_CountMore or id == bind.n_CountLess
    then
        self:onControllerButtonPress(id)
    end
end

---@param defaultText fun():string
parts.naming = function(defaultText)
    local path = { 'naming', 'nameBar', 'padding', 'textEdit' }
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
        name = 'naming-box',
        type = ui.TYPE.Flex,
        props = {

        },
        content = ui.content {
            {
                template = T.Base.textNormal,
                props = {
                    text = C.Strings.NAME,
                },
            },
            T.Base.intervalV(3),
            {
                name = 'naming',
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    --gap = 10, --TODO: this is not in 0.51, hope for 0.52
                    arrange = ui.ALIGNMENT.Center,
                },
                content = ui.content {

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
                                            size = v2(330, T.Base.TEXT_SIZE),
                                            text = name,
                                            textColor = C.Colors.DEFAULT_LIGHT,
                                        },
                                        events = {
                                            textChanged = async:callback(function(text, layout)
                                                name = text
                                                layout.props.text = text
                                            end),
                                        }
                                    }
                                }
                            }
                        },
                    },
                    T.Base.intervalH(5),
                    btn,
                },
            },
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

---@param getToolRecord fun(type:number):openmw.types.ApparatusRecord?
parts.tools = function(getToolRecord)
    local element
    local path = { 'tools-box', 'padding', 'tools' }

    local wdg = {
        update = function()
            local tools = H.findLayoutByPath(element, path)
            local function updateTool(name, type)
                local record = getToolRecord(type)
                local layout = H.findLayoutByPath(tools, { 'name', name })
                layout.props.text = record and record.name or C.Strings.NONE

                layout = H.findLayoutByPath(tools, { 'quality', name })
                layout.props.text = record and 'x' .. H.roundToPlaces(record.quality, 2) or ''

                layout = H.findLayoutByPath(tools, { 'icon', name })
                layout.props.resource = record and T.Base.createTexture(record.icon)
            end

            updateTool(C.Strings.MORTAR, ApparatusTypes.MortarPestle)
            updateTool(C.Strings.ALEMBIC, ApparatusTypes.Alembic)
            updateTool(C.Strings.CALCINATOR, ApparatusTypes.Calcinator)
            updateTool(C.Strings.RETORT, ApparatusTypes.Retort)

            element:update()
        end,
    }
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

    element = ui.create {
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
            T.Base.intervalV(3),
            box,
        }
    }
    return element, wdg
end

---@param self AlchemyWindow
---@param getId fun(n:integer):string?
---@param onClick fun(n:integer)
---@param tooltipFn fun(n:integer):table?
parts.selected = function(self, getId, onClick, tooltipFn)
    local element
    local path = { 'selected-box', 'padding', 'selected' }
    local wdg = {
        update = function()
            local selected = H.findLayoutByPath(element, path)
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

            for i = 1, #Slots do updateSelected(i) end

            auxUi.deepUpdate(element)
        end
    }

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
                                    parts.namedActiveHeader(Slots[1], self.ctx,
                                        function() return getId(1) end,
                                        function() onClick(1) end,
                                        function() return tooltipFn(1) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedActiveHeader(Slots[2], self.ctx,
                                        function() return getId(2) end,
                                        function() onClick(2) end,
                                        function() return tooltipFn(2) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedActiveHeader(Slots[3], self.ctx,
                                        function() return getId(3) end,
                                        function() onClick(3) end,
                                        function() return tooltipFn(3) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedActiveHeader(Slots[4], self.ctx,
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
    element = ui.create {
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
            T.Base.intervalV(3),
            box,
        }
    }
    return element, wdg
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

---@param self AlchemyWindow
parts.resultingEffects = function(self)
    local element
    local path = { 'result-box', 'padding', 'effect-list' }
    local info = ui.create {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
        },
    }

    ---@param potion openmw.types.PotionRecord
    local function updateInfo(potion)
        local value = potion.value
        local weight = H.roundToPlaces(potion.weight, 2)

        local content = ui.content {
            T.Base.intervalH(5),
        }

        if value > 0 then
            content:add {
                name = 'value-icon',
                type = ui.TYPE.Image,
                props = {
                    size = v2(16, 16),
                    resource = T.Base.createTexture('icons/gold.dds'),
                }
            }
            content:add {
                name = 'value-text',
                template = T.Base.textNormal,
                props = {
                    text = ' ' .. H.addSeparators(value),
                    anchor = v2(0.5, 0),
                    relativePosition = v2(0.5, 0),
                }
            }
            content:add(T.Base.intervalH(15))
        end

        if weight > 0 then
            content:add {
                name = 'weight-icon',
                type = ui.TYPE.Image,
                props = {
                    size = v2(16, 16),
                    resource = T.Base.createTexture('icons/weight.dds'),
                }
            }
            content:add {
                name = 'weight-text',
                template = T.Base.textNormal,
                props = {
                    text = ' ' .. weight,
                    anchor = v2(0.5, 0),
                    relativePosition = v2(0.5, 0),
                }
            }
        end

        info.layout.content = content
        info:update()
    end

    local wdg = {
        update = function()
            local effects = H.findLayoutByPath(element, path)
            for i = 1, #effects.content do
                auxUi.deepDestroy(effects.content[i])
            end
            local effectCount = 8 --min 4 for beauty
            effects.content = ui.content {}

            local matching = self.data.matching
            local known = self.data.matchingKnowledge
            local full = false
            local potion, code, k = self:getTempPotionStats()

            updateInfo(potion)

            if code == A.PotionErrors.OK then
                matching = potion.effects
                known = k
                full = self.showFullEffects
            elseif code == A.PotionErrors.FAIL then
                if matching and #matching > 0 then
                    effects.content:add(
                        {
                            template = T.Base.textParagraph,
                            props = {
                                text = l10n('All_Effects_Neutralized'),
                                textAlignH = ui.ALIGNMENT.Center,
                                size = v2(BLOCK_WIDTH, 0),
                            }
                        }
                    )
                end
                matching = nil
            end
            if matching then
                effectCount = math.max(effectCount, #matching)
                local effectLayouts = {}
                for i = 1, #matching do
                    local effect = matching[i]
                    local isVisible = not known or known[i]
                    local content = ui.content {}
                    if isVisible then
                        content:add(T.Special.effectIcon(effect.id))
                        content:add(T.Base.intervalH(4))
                        local effectText = full and H.createSpellEffectString(effect) or H.getMagicEffectString(effect)
                        content:add({ name = 'effect_text', template = T.Base.textNormal, props = { text = effectText or '?' } })
                    else
                        content:add({ name = 'effect_text', template = T.Base.textNormal, props = { text = '?' } })
                    end

                    local effectLayout = {
                        name = 'effect_' .. i,
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
                    if isVisible then
                        table.insert(effectLayouts, T.Special.interactive({
                            name = 'effect_' .. i,
                            tooltipFn = function() return T.Special.magicEffectTooltip(effect.id) end,
                        }, effectLayout, self.ctx))
                    else
                        table.insert(effectLayouts, effectLayout)
                    end
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
            effects.props.size = v2(BLOCK_WIDTH, T.Base.TEXT_SIZE * effectCount + GAP_EFFECT * (effectCount - 1))

            auxUi.deepUpdate(element)
        end,
    }


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
    element = ui.create {
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
            T.Base.intervalV(3),
            box,
            T.Base.intervalV(5),
            info
        }
    }

    wdg.element = element
    return wdg
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

---@param wnd AlchemyWindow
parts.filterInput = function(wnd)
    local path = { 'filterBar', 'padding', 'textEdit' }
    local filterValue = ''
    local element
    local wdg = {
        setText = function(text)
            local txt = H.findLayoutByPath(element, path)
            txt.props.text = text
            filterValue = text
            element:update()
        end,
        getText = function() return filterValue end,
    }

    local btn = T.Base.imageButton(REVERT_PATH, v2(T.Base.TEXT_SIZE, T.Base.TEXT_SIZE), function()
        wnd:clearFilter()
    end, 'btn-revert')

    element = ui.create {
        name = 'filter',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            {
                name = 'filterBar',
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
                                    size = v2(BLOCK_WIDTH - 2, T.Base.TEXT_SIZE),
                                    text = filterValue,
                                    textColor = C.Colors.DEFAULT_LIGHT,
                                },
                                events = {
                                    textChanged = async:callback(function(text, layout)
                                        filterValue = text
                                        layout.props.text = text
                                        wnd:onFilterChanged(text)
                                    end),
                                }
                            }
                        }
                    }
                },
            },
            T.Base.intervalH(5),
            btn,
        },
    }

    return element, wdg
end

---@param wnd AlchemyWindow
parts.typeSelector = function(wnd)
    local element, potion, poison

    local function update()
        potion.layout.userData.active = not wnd.isPoison
        H.setInteractiveColor(potion)
        potion:update()

        poison.layout.userData.active = wnd.isPoison
        H.setInteractiveColor(poison)
        poison:update()

        wnd:onPotionTypeUpdated()
    end

    local wdg = {
        onPotionClick = function()
            wnd.isPoison = false
            update()
        end,
        onPoisonClick = function()
            wnd.isPoison = true
            update()
        end,
        update = update,
    }

    potion = T.Special.interactive({
        name = 'type-selector-potion',
        onClick = wdg.onPotionClick,
        tooltipFn = function()
            return T.Special.paragraphTooltip(l10n('AlchemyWindow_Type_Potion_Tooltip', C.TextColorParams),
                'type-selector-potion', { size = v2(200, 0) })
        end,
    }, {
        template = T.Base.textNormal,
        props = {
            text = l10n('Label_Potion')
        },
        userData = {
            colorable = true,
        }
    }, wnd.ctx)

    poison = T.Special.interactive({
        name = 'type-selector-poison',
        onClick = wdg.onPoisonClick,
        tooltipFn = function()
            return T.Special.paragraphTooltip(l10n('AlchemyWindow_Type_Poison_Tooltip', C.TextColorParams),
                'type-selector-poison', { size = v2(200, 0) })
        end,
    }, {
        template = T.Base.textNormal,
        props = {
            text = l10n('Label_Poison')
        },
        userData = {
            colorable = true,
        }
    }, wnd.ctx)

    element = ui.create {
        name = 'potion-type',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            anchor = v2(0.5, 1),
            relativePosition = v2(0.5, 1),
            align = ui.ALIGNMENT.Center,
            arrange = ui.ALIGNMENT.Center,
            position = v2(0, -3)
        },
        content = ui.content {
            potion,
            T.Base.intervalH(5),
            {
                template = T.Base.textHeader,
                props = {
                    text = '|'
                },
            },
            T.Base.intervalH(5),
            poison,
        }
    }
    wdg.element = element
    update()

    return wdg
end

---@param wnd AlchemyWindow
parts.tableSelector = function(wnd)
    local element, ingredients, effects

    local function update()
        ingredients.layout.userData.active = not wnd.showEffects
        H.setInteractiveColor(ingredients)
        ingredients:update()

        effects.layout.userData.active = wnd.showEffects
        H.setInteractiveColor(effects)
        effects:update()

        wnd.itemTable.layout.props.visible = not wnd.showEffects
        wnd.effectTable.layout.props.visible = wnd.showEffects

        wnd.itemTable:update()
        wnd.effectTable:update()
        if wnd.showEffects then
            wnd.effectTable.layout.userData.refresh()
        end

        if wnd.toggleFilterMatching then
            wnd.toggleFilterMatching.update()
        end
    end

    local wdg = {
        onIngredientClick = function()
            wnd.showEffects = false
            update()
        end,
        onEffectClick = function()
            wnd.showEffects = true
            update()
        end,
        update = update,
    }

    ingredients = T.Special.interactive({
        name = 'type-selector-ingredients',
        onClick = wdg.onIngredientClick,
        tooltipFn = function()
            return T.Special.paragraphTooltip(l10n('AlchemyWindow_Type_Ingredient_Tooltip', C.TextColorParams),
                'type-selector-ingredients', { size = v2(200, 0) })
        end,
    }, {
        template = T.Base.textNormal,
        props = {
            text = C.Strings.INGREDIENTS
        },
        userData = {
            colorable = true,
        }
    }, wnd.ctx)

    effects = T.Special.interactive({
        name = 'type-selector-effects',
        onClick = wdg.onEffectClick,
        tooltipFn = function()
            return T.Special.paragraphTooltip(l10n('AlchemyWindow_Type_Effect_Tooltip', C.TextColorParams),
                'type-selector-effects', { size = v2(200, 0) })
        end,
    }, {
        template = T.Base.textNormal,
        props = {
            text = C.Strings.EFFECTS
        },
        userData = {
            colorable = true,
        }
    }, wnd.ctx)

    element = ui.create {
        name = 'table-type',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            anchor = v2(0, 1),
            relativePosition = v2(0, 1),
            align = ui.ALIGNMENT.Center,
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            ingredients,
            T.Base.intervalH(5),
            {
                template = T.Base.textHeader,
                props = {
                    text = '|'
                },
            },
            T.Base.intervalH(5),
            effects,
        }
    }
    wdg.element = element
    update()

    return wdg
end

---@param wnd AlchemyWindow
parts.filterMatchingToggle = function(wnd)
    local element, toggle

    local function update()
        if wnd.showEffects then
            toggle.layout.userData.active = wnd.filterMatchingEffects
        else
            toggle.layout.userData.active = wnd.filterMatchingIngredients
        end
        H.setInteractiveColor(toggle)
        toggle:update()
        wnd:onFilterChanged()
    end

    local wdg = {
        onToggleClick = function()
            if wnd.showEffects then
                wnd.filterMatchingEffects = not wnd.filterMatchingEffects
            else
                wnd.filterMatchingIngredients = not wnd.filterMatchingIngredients
            end
            update()
        end,
        update = update,
    }

    toggle = T.Special.interactive({
        name = 'toggle-filter-types-matching-toggle',
        onClick = wdg.onToggleClick,
        tooltipFn = function()
            if wnd.showEffects then
                return T.Special.paragraphTooltip(
                    l10n('AlchemyWindow_Toggle_Matching_Effect_Tooltip', C.TextColorParams),
                    'toggle-filter-types-matching-toggle', { size = v2(200, 0) })
            else
                return T.Special.paragraphTooltip(
                    l10n('AlchemyWindow_Toggle_Matching_Ingredient_Tooltip', C.TextColorParams),
                    'toggle-filter-types-matching-toggle', { size = v2(200, 0) })
            end
        end,
    }, {
        template = T.Base.textNormal,
        props = {
            text = l10n('Label_Matching'),
        },
        userData = {
            colorable = true,
        }
    }, wnd.ctx)

    element = ui.create {
        name = 'toggle-filter-type-matching',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            anchor = v2(1, 1),
            relativePosition = v2(1, 1),
            align = ui.ALIGNMENT.End,
            arrange = ui.ALIGNMENT.Center,
            position = v2(-25, 0)
        },
        content = ui.content {
            toggle,
        }
    }
    wdg.element = element
    update()

    return wdg
end

return AlchemyWindow

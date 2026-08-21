---@omw-context player

local core = require('openmw.core')
local ui = require('openmw.ui')
local auxUi = require('openmw_aux.ui')
local util = require('openmw.util')
local storage = require('openmw.storage')
local player = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')

local l10n = core.l10n('TPA_AlchemyRedone')
local v2 = util.vector2
local ApparatusTypes = types.Apparatus.TYPE

local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')
---@class UIToolkit.Templates
local T = require('scripts.UIToolkit.templates.base')
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

--TODO: salvage what's used from these into new files
local Base = require("scripts.TPABOBAP.UIToolkit.templates.base")
local H = require("scripts.TPABOBAP.UIToolkit.helpers")
local C = require("scripts.TPABOBAP.UIToolkit.constants")

local Class = require('scripts.UIToolkit.class')
---@type AlchemyRedone.ListItemIngredient
local ListItemIngredient = require('scripts.TPABOBAP.AlchemyRedone.new.item_ingredient')

local M = {}

local settings = storage.playerSection(CFG.SECTION.PLAYER.WINDOW)
local cfgPlayer = require('scripts.TPABOBAP.AlchemyRedone.config.player')
local cfgGlobal = require('scripts.TPABOBAP.AlchemyRedone.config.global')

local Slots = { 'First', 'Second', 'Third', 'Fourth' }
local MIN_SIZE = v2(800, 695)
local isCompact = cfgPlayer.ui.b_CompactMode

local STRINGS = {
    NAME = core.getGMST('sNameTitle'),
    NONE = core.getGMST('sNone'),
    APPARATUS = core.getGMST('sApparatus'),
    MORTAR = core.getGMST('sMortar'),
    CALCINATOR = core.getGMST('sCalcinator'),
    ALEMBIC = core.getGMST('sAlembic'),
    RETORT = core.getGMST('sRetort'),
}

local ICON_DEFAULTS = {
    [STRINGS.MORTAR] = 'icons/TPABOBAP/AlchemyRedone/mortar.png',
    [STRINGS.ALEMBIC] = 'icons/TPABOBAP/AlchemyRedone/alembic.png',
    [STRINGS.CALCINATOR] = 'icons/TPABOBAP/AlchemyRedone/calcinator.png',
    [STRINGS.RETORT] = 'icons/TPABOBAP/AlchemyRedone/retort.png',
}
local REVERT_PATH = 'icons/TPABOBAP/AlchemyRedone/revert.png'
local UNKNOWN_PATH = 'icons/TPABOBAP/AlchemyRedone/unknown-effect.png'

local COLORS = {
    WHITE = util.color.rgb(1, 1, 1),
    GRAY = util.color.rgb(0.5, 0.5, 0.5),
}

local INNER_PAD = 10
local BLOCK_WIDTH = 300
local INNER_TEXT = 16
local TITLE_TEXT = 16
local ICON_SZ
local GAP_END
local GAP_MID
local GAP_ICON
local GAP_EFFECT
local VERT_GAP
local COLUMN_GAP

--every tweakable dimension, one row per layout profile; font-dependent values scale in updateSizes
local PROFILE = {
    default = {
        blockWidth = 330,
        minWidthPad = 135,
        minHeight = 695,
        minHeightFontMult = 23,
        vertGap = 10,
        columnGap = 15,
        iconRatio = 1.5,
        gapIcon = 3,
        gapEffect = 8,
        effectRows = 8,
        tableMargin = v2(0, 110),
        startWidthPad = 0,
    },
    compact = {
        blockWidth = 330,
        minWidthPad = 60,
        minHeight = 551,
        minHeightFontMult = 19,
        vertGap = 10,
        columnGap = 5,
        iconRatio = 1.5,
        gapIcon = 1,
        gapEffect = 2,
        effectRows = 8,
        tableMargin = v2(20, 122),
        startWidthPad = 58,
        startPos = { x = 0.315, y = 0 },
    },
}
local P = PROFILE.default

local function minInnerHeight()
    local sizes = I.UIToolkit.getTheme().Sizes
    local boxV = 2 * sizes.border + 10
    local slotBoxH = ICON_SZ * 4 + GAP_ICON * 3 + boxV
    local effectCount = P.effectRows
    local naming = TITLE_TEXT + INNER_TEXT + 3 + 2 * (sizes.border + sizes.padding)
    local tools = TITLE_TEXT + 2 + 3 + slotBoxH
    local selected = TITLE_TEXT + 3 + slotBoxH
    local result = TITLE_TEXT + 2 + 3 + INNER_TEXT * effectCount + GAP_EFFECT * (effectCount - 1) + boxV
    return naming + tools + selected + result + 3 * VERT_GAP + 65
end

local function updateSizes()
    local fontDiff = Base.TEXT_SIZE - 16
    P = cfgPlayer.ui.b_CompactMode and PROFILE.compact or PROFILE.default
    --size tiers from the shared templates: contents/tables/tooltips at INNER_TEXT, headings at TITLE_TEXT
    INNER_TEXT = Base.TEXT_SIZE_CONTENT
    TITLE_TEXT = Base.TEXT_SIZE_TITLE
    BLOCK_WIDTH = util.round(P.blockWidth * INNER_TEXT / 16)
    local minWidth = 2 * BLOCK_WIDTH + P.minWidthPad
    --never demand a minimum larger than the screen layer itself (high GUI scale shrinks the logical layer)
    local okL, lsz = pcall(function() return ui.layers[ui.layers.indexOf('Windows')].size end)
    if okL and lsz then
        minWidth = math.min(minWidth, lsz.x - 24)
    end
    VERT_GAP = P.vertGap
    COLUMN_GAP = P.columnGap

    ICON_SZ = util.round(INNER_TEXT * P.iconRatio)
    GAP_ICON = P.gapIcon
    GAP_END = util.round((ICON_SZ - INNER_TEXT) / 2)
    GAP_MID = 2 * GAP_END + GAP_ICON
    GAP_EFFECT = P.gapEffect
    MIN_SIZE = v2(minWidth, minInnerHeight())
end

---@class AlchemyRedone.Window: UIToolkit.WindowHandler
---@field new fun():AlchemyRedone.Window
---@field list UIToolkit.ItemList
---@field wnd UIToolkit.Window
local Window = Class()

---@param wnd UIToolkit.Window
---@param data AlchemyData
function Window:onOpened(wnd, data)
    self.wnd = wnd
    self.data = data

    updateSizes()
    wnd:setMinSize(MIN_SIZE)

    local rowHeight = 1.5 * (Base.TEXT_SIZE_CONTENT + 2)
    local effectWidth = 4 * (Base.TEXT_SIZE_CONTENT + 3)

    ---@type AlchemyRedone.ListItemIngredient
    local provider = ListItemIngredient:new()
    provider:init(self.data, rowHeight, effectWidth)
    self.ingredientProvider = provider

    --Show effects or ingredients?
    self.showEffects = false
    --TODO: move these to custom window save data?
    --Are we making potion or poison?, default: false
    self.isPoison = settings:get('isPoison') == true
    --Show only ingredients that have effects present in selected ingredients but not matched yet, default: false
    self.filterMatchingIngredients = settings:get('filterMatchingIngredients') == true
    --Show only effects that match potion type (harmful/positive), default: true
    self.filterMatchingEffects = settings:get('filterMatchingEffects') ~= false

    self.showFullEffects = cfgPlayer.main.b_ShowFullEffectInfo
    ---@type {id:string, text: string}[]
    self.selectedEffects = {}

    self.allIngredients = M.getAllIngredients(self.data)
    --self.allEffects = M.getAllIngredients(self.data)

    self.naming = I.UIToolkit.Components.textEdit({
        default = '',
        showClearButton = true,
        textColorNormal = I.UIToolkit.getTheme().Colors.HEADER,
        --placeholder = function() return self:getDefaultPotionName() end,
        textSize = INNER_TEXT,
        width = BLOCK_WIDTH,
    })

    ---@type UIToolkit.TextEdit<string>
    self.filter = I.UIToolkit.Components.textEdit {
        default = '',
        textSize = INNER_TEXT,
        placeholder = l10n('FilterPlaceholder'),
        onValueChanged = function() self:updateIngredientList() end,
        showClearButton = true,
    }
    self.filter
        :setWidth(0)
        :updateProps { relativeSize = v2(1, 0) }

    self.resultingEffects = self:makeResultingEffects()
    self.resultingEffects.update()

    self.tableSelector = self:makeTableSelector()

    self.toggleFilterMatching = self:makeFilterMatchingToggle()

    self.potionTypeSelector = self:makeTypeSelector()

    self.tools = self:makeTools()
    self.tools.update()

    self.selected = self:makeSelected()
    self.selected.update()

    self.btnCreate = I.UIToolkit.Components.textButton {
        text = C.Strings.CREATE,
        name = 'btnCreate',
        onClick = function() self:createPotion() end, --TODO: implement
        canClick = function() return not self.btnCreate:disabled() end,
    }

    self.btnCancel = I.UIToolkit.Components.textButton {
        text = C.Strings.CANCEL,
        name = 'btnCancel',
        onClick = function() I.UI.removeMode(I.UI.MODE.Alchemy) end,
    }
    self.btnCancel:updateProps {
        anchor = v2(1, 1),
        relativePosition = v2(1, 1),
    }

    self.itemTable = self:makeIngredientList()
    self:updateIngredientList()

    self.content, self.rightPanel = self:makeContent()
    wnd:setContent(self.content)

    self:onResized(wnd:getInnerSize())
end

function Window:onClosed()
    self.wnd = nil
    --TODO: destroy ingredient list
    --TODO: destroy effect list
    if self._onClose then self._onClose() end
end

function Window:onResized(inner)
    local c = self.wnd:getPosition()
    local sz = self.wnd:getSize()
    local tipPos = c + v2(sz.x + 10, sz.y / 2)

    self.controllerTooltipPos = tipPos
    --self.effectTable.layout.userData.controllerTooltipPos = tipPos

    if self.lastSz and self.lastSz == inner then return end
    self.lastSz = inner

    local right = self.rightPanel
    local rsz = v2(inner.x - BLOCK_WIDTH - 2 * INNER_PAD - COLUMN_GAP, inner.y - 2 * INNER_PAD)
    right.layout.props.size = rsz

    local tableSz = rsz - P.tableMargin
    if self.showEffects then
        --self.effectTable.layout.userData.resize(tableSz)  --TODO: implement
    else
        self.itemTable:setSize(tableSz)
    end

    I.UIToolkit.queueUpdate(right)
end

---@return openmw.ui.Content, openmw.ui.Element
function Window:makeContent()
    local right = ui.create {
        name = 'right',
        type = ui.TYPE.Widget,
        props = {
            position = v2(BLOCK_WIDTH + COLUMN_GAP, 0),
        },
        content = ui.content {
            {
                name = 'top-lane',
                type = ui.TYPE.Widget,
                props = {
                    size = v2(0, TITLE_TEXT),
                    relativeSize = v2(1, 0)
                },
                content = ui.content {
                    self.tableSelector.element,
                    self.toggleFilterMatching.element,
                },
            },
            self.itemTable.element,
            {
                name = 'bottom-block',
                props = {
                    size = v2(0, 70),
                    relativeSize = v2(1, 0),
                    anchor = v2(1, 1),
                    relativePosition = v2(1, 1),
                },
                content = ui.content {
                    self.filter.element,
                    {
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            anchor = v2(0, 1),
                            relativePosition = v2(0, 1),
                            arrange = ui.ALIGNMENT.Center,
                        },
                        content = ui.content {
                            self.btnCreate.element,
                            T.intervalH(10),
                            --counting, --TODO: implement
                        },
                    },
                    self.btnCancel.element,
                },
            },
        },
    }
    return ui.content {
        ui.create {
            name = 'main',
            type = ui.TYPE.Container,
            props = {
                position = v2(INNER_PAD, INNER_PAD)
            },
            content = ui.content {
                ui.create {
                    name = 'left',
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = false,
                    },
                    content = ui.content {
                        self:makeNaming(),
                        T.intervalV(VERT_GAP),
                        self.tools.element,
                        T.intervalV(VERT_GAP),
                        self.selected.element,
                        T.intervalV(VERT_GAP),
                        self.resultingEffects.element,
                    },
                },
                T.intervalH(COLUMN_GAP),
                right,
            }
        },
    }, right
end

---@return openmw.ui.Element
function Window:makeNaming()
    return ui.create {
        name = 'naming-box',
        type = ui.TYPE.Flex,
        props = {},
        content = ui.content {
            {
                template = T.text(),
                props = {
                    text = STRINGS.NAME,
                    textSize = TITLE_TEXT,
                },
            },
            T.intervalV(3),
            self.naming.element,
        }
    }
end

function Window:makeTypeSelector()
    local element, potion, poison

    local function update()
        potion.layout.userData.active = not self.isPoison
        H.setInteractiveColor(potion)
        potion:update()

        poison.layout.userData.active = self.isPoison
        H.setInteractiveColor(poison)
        poison:update()

        self:onPotionTypeUpdated()
    end

    local wdg = {
        onPotionClick = function()
            self.isPoison = false
            update()
        end,
        onPoisonClick = function()
            self.isPoison = true
            update()
        end,
        update = update,
    }

    potion = I.UIToolkit.Interactive.makeInteractive({
        name = 'type-selector-potion',
        onClick = wdg.onPotionClick,
        tooltip = M.paragraphTooltip('AlchemyWindow_Type_Potion_Tooltip'),
    }, {
        template = T.text(),
        props = {
            text = l10n('Label_Potion'),
            textSize = TITLE_TEXT,
        },
        userData = {
            colorable = true,
        }
    })

    poison = I.UIToolkit.Interactive.makeInteractive({
        name = 'type-selector-poison',
        onClick = wdg.onPoisonClick,
        tooltip = M.paragraphTooltip('AlchemyWindow_Type_Poison_Tooltip'),
    }, {
        template = T.text(),
        props = {
            text = l10n('Label_Poison'),
            textSize = TITLE_TEXT,
        },
        userData = {
            colorable = true,
        }
    })

    element = ui.create {
        name = 'potion-type',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            align = ui.ALIGNMENT.Center,
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            potion,
            T.intervalH(5),
            {
                template = T.text(),
                props = {
                    text = '|',
                    textSize = TITLE_TEXT,
                },
            },
            T.intervalH(5),
            poison,
        }
    }
    wdg.element = element
    update()

    return wdg
end

function Window:makeFilterMatchingToggle()
    local element, toggle

    local function update(noListUpdates)
        if self.showEffects then
            toggle.layout.userData.active = self.filterMatchingEffects
        else
            toggle.layout.userData.active = self.filterMatchingIngredients
        end
        H.setInteractiveColor(toggle)
        toggle:update()
        if not noListUpdates then
            self:updateIngredientList()
            self:updateEffectList()
        end
    end

    local wdg = {
        onToggleClick = function()
            if self.showEffects then
                self.filterMatchingEffects = not self.filterMatchingEffects
            else
                self.filterMatchingIngredients = not self.filterMatchingIngredients
            end
            update()
        end,
        update = update,
    }

    toggle = I.UIToolkit.Interactive.makeInteractive({
        name = 'toggle-filter-types-matching-toggle',
        onClick = wdg.onToggleClick,
        tooltip = function()
            return M.paragraphTooltip(self.showEffects
                and 'AlchemyWindow_Toggle_Matching_Effect_Tooltip'
                or 'AlchemyWindow_Toggle_Matching_Ingredient_Tooltip')
        end,
    }, {
        template = T.text(),
        props = {
            text = l10n('Label_Matching'),
            textSize = TITLE_TEXT,
            textAlignH = ui.ALIGNMENT.End,
        },
        userData = {
            colorable = true,
        }
    })

    element = ui.create {
        name = 'toggle-filter-type-matching',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            anchor = v2(1, 1),
            relativePosition = v2(1, 1),
            align = ui.ALIGNMENT.End,
            arrange = ui.ALIGNMENT.Center,
            position = v2(0, 0)
        },
        content = ui.content {
            toggle,
        }
    }
    wdg.element = element
    update()

    return wdg
end

function Window:makeTableSelector()
    local element, ingredients, effects

    local function update()
        ingredients.layout.userData.active = not self.showEffects
        H.setInteractiveColor(ingredients)
        ingredients:update()

        effects.layout.userData.active = self.showEffects
        H.setInteractiveColor(effects)
        effects:update()

        if self.itemTable then
            self.itemTable:visible(not self.showEffects)
        end
        if self.effectTable then
            --self.effectTable:visible(self.showEffects)
        end

        self:updateIngredientList()
        self:updateMatchingEffects()
        --TODO: update sizes?

        if self.toggleFilterMatching then
            self.toggleFilterMatching.update(true)
        end
    end

    local wdg = {
        onIngredientClick = function()
            self.showEffects = false
            update()
        end,
        onEffectClick = function()
            self.showEffects = true
            update()
        end,
        update = update,
    }

    ingredients = I.UIToolkit.Interactive.makeInteractive({
        name = 'type-selector-ingredients',
        onClick = wdg.onIngredientClick,
        tooltip = M.paragraphTooltip('AlchemyWindow_Type_Ingredient_Tooltip'),
    }, {
        template = T.text(),
        props = {
            text = C.Strings.INGREDIENTS,
            textSize = TITLE_TEXT,
        },
        userData = {
            colorable = true,
        }
    })

    effects = I.UIToolkit.Interactive.makeInteractive({
        name = 'type-selector-effects',
        onClick = wdg.onEffectClick,
        tooltip = M.paragraphTooltip('AlchemyWindow_Type_Effect_Tooltip'),
    }, {
        template = T.text(),
        props = {
            text = C.Strings.EFFECTS,
            textSize = TITLE_TEXT,
        },
        userData = {
            colorable = true,
        }
    })

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
            T.intervalH(5),
            {
                template = T.text(),
                props = {
                    text = '|',
                    textSize = TITLE_TEXT,
                },
            },
            T.intervalH(5),
            effects,
        }
    }
    wdg.element = element
    update()

    return wdg
end

function Window:makeTools()
    local element
    local path = { 'tools-box', 'padding', 'tools' }
    local noticePath = { 'tools-box', 'padding', 'notice' }

    local TIP_W = util.round(INNER_TEXT * 15)

    ---@return UTKTooltips.Tooltip
    local function toolTip(record, label, key, suffix)
        ---@type UTKTooltips.RecipeItem[]
        local items = {
            { type = 'header',    title = record and record.name or label },
            { type = 'paragraph', text = l10n('Apparatus_Tooltip_' .. key .. suffix, C.TextColorParams), width = TIP_W },
        }

        if record then
            ---@type UTKTooltips.RecipeItem[]
            local info = {}
            local value = util.round(record.value)
            if value > 0 then
                info[#info + 1] = { value = H.addSeparators(value), image = 'icons/gold.dds', type = 'value' }
            end
            local weight = util.round(record.weight)
            if weight > 0 then
                if #info > 0 then info[#info + 1] = { type = 'gap' } end
                info[#info + 1] = { value = H.addSeparators(weight), image = 'icons/weight.dds', type = 'value' }
            end
            if #info > 0 then
                items[#items + 1] = { type = 'gap' }
                items[#items + 1] = {
                    type = 'root',
                    horizontal = true,
                    items = info,
                    align = ui.ALIGNMENT.End,
                }
            end
        end

        return { recipe = { items = items, arrange = ui.ALIGNMENT.Center } }
    end


    local function header(name, type, key, hasModes)
        local e = M.namedHeader(name, function()
            local suffix = hasModes and self.isPoison and '_Poison' or ''
            local record = self:getToolRecord(type)
            return toolTip(record, name, key, suffix)
        end)
        e.layout.external = { grow = 1 }
        return e
    end

    local wdg = {
        update = function()
            local tools = H.findLayoutByPath(element, path)
            local function updateTool(name, type)
                local record = self:getToolRecord(type)
                local layout = H.findLayoutByPath(tools, { name, 'name' })
                layout.props.text = record and record.name or STRINGS.NONE

                layout = H.findLayoutByPath(tools, { name, 'quality' })
                layout.props.text = record and 'x' .. H.roundToPlaces(record.quality, 2) or ''

                layout = H.findLayoutByPath(tools, { name, 'icon' })
                local tex = ICON_DEFAULTS[name]
                local color = COLORS.GRAY
                if record and record.icon then
                    tex = record.icon
                    color = COLORS.WHITE
                end
                layout.props.resource = I.UIToolkit.texture(tex)
                layout.props.color = color
            end

            updateTool(STRINGS.MORTAR, ApparatusTypes.MortarPestle)
            updateTool(STRINGS.ALEMBIC, ApparatusTypes.Alembic)
            updateTool(STRINGS.CALCINATOR, ApparatusTypes.Calcinator)
            updateTool(STRINGS.RETORT, ApparatusTypes.Retort)

            element:update()
        end,
        -- brew result shown in place of the selected ingredients until hideNotice
        showNotice = function(potionName, brewed, failed)
            H.findLayoutByPath(element, path).props.visible = false
            local notice = H.findLayoutByPath(element, noticePath)
            notice.props.visible = true
            H.findLayoutByPath(notice, { 'notice-name' }).props.text = potionName
            H.findLayoutByPath(notice, { 'notice-brewed' }).props.text =
                l10n('Brew_Notice_Brewed', { count = H.addSeparators(brewed) })
            H.findLayoutByPath(notice, { 'notice-failed' }).props.text =
                failed > 0 and l10n('Brew_Notice_Failed', { count = H.addSeparators(failed) }) or ''
            element:update()
        end,
        hideNotice = function()
            H.findLayoutByPath(element, path).props.visible = true
            H.findLayoutByPath(element, noticePath).props.visible = false
            element:update()
        end,
    }
    local function makeRow(name, type, key)
        return {
            name = name,
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                autoSize = false,
                arrange = ui.ALIGNMENT.Center,
                size = v2(BLOCK_WIDTH - 10, ICON_SZ),
            },
            content = ui.content {
                M.namedIcon('icon', ICON_SZ),
                T.intervalH(10),
                header('name', type, key),
                M.namedText('quality'),
            },
        }
    end
    local box = {
        name = 'tools-box',
        template = T.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.padding(5),
                content = ui.content {
                    {
                        name = 'tools',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = false,
                            arrange = ui.ALIGNMENT.Start,
                            align = ui.ALIGNMENT.Start,
                            autoSize = false,
                            size = v2(BLOCK_WIDTH - 10, ICON_SZ * 4 + GAP_ICON * 3),
                        },
                        content = ui.content {
                            makeRow(STRINGS.MORTAR, ApparatusTypes.MortarPestle, 'Mortar'),
                            T.intervalV(GAP_ICON),
                            makeRow(STRINGS.ALEMBIC, ApparatusTypes.Alembic, 'Alembic'),
                            T.intervalV(GAP_ICON),
                            makeRow(STRINGS.CALCINATOR, ApparatusTypes.Calcinator, 'Calcinator'),
                            T.intervalV(GAP_ICON),
                            makeRow(STRINGS.RETORT, ApparatusTypes.Retort, 'Retort'),
                        },
                    },
                    {
                        name = 'notice',
                        type = ui.TYPE.Flex,
                        props = {
                            arrange = ui.ALIGNMENT.Center,
                            align = ui.ALIGNMENT.Center,
                            autoSize = false,
                            visible = false,
                            size = v2(BLOCK_WIDTH - 10, ICON_SZ * 4 + GAP_ICON * 3),
                        },
                        content = ui.content {
                            {
                                name = 'notice-name',
                                template = T.header(),
                                props = { text = '' },
                            },
                            T.intervalV(4),
                            {
                                name = 'notice-brewed',
                                template = T.text(),
                                props = { text = '' },
                            },
                            {
                                name = 'notice-failed',
                                template = T.text(),
                                props = { text = '' },
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
                type = ui.TYPE.Widget,
                props = { size = v2(BLOCK_WIDTH, TITLE_TEXT + 2) },
                content = ui.content {
                    {
                        template = T.text(),
                        props = {
                            text = STRINGS.APPARATUS,
                            textSize = TITLE_TEXT,
                        },
                    },
                    {
                        type = ui.TYPE.Container,
                        props = {
                            anchor = v2(1, 0),
                            relativePosition = v2(1, 0),
                        },
                        content = ui.content { self.potionTypeSelector.element },
                    },
                },
            },
            T.intervalV(3),
            box,
        }
    }

    wdg.element = element
    return wdg
end

function Window:makeSelected()
    local function getId(n)
        local r = self:getSelectedIngredientRecord(n)
        return r and r.id
    end
    local function onClick(n) self:clearSelectedIngredient(n) end
    ---@return UTKTooltips.Tooltip?
    local function tooltipFn(n)
        local r = self:getSelectedIngredientRecord(n)
        if not r then return nil end
        return { key = r.id, type = I.UTKTooltips.TYPE.Ingredient }
    end

    local element
    local path = { 'selected-box', 'padding', 'selected' }
    local wdg = {
        update = function()
            local selected = H.findLayoutByPath(element, path)
            local function updateSelected(n)
                local record, amount = self:getSelectedIngredientRecord(n)
                local name = H.findLayoutByPath(selected, { Slots[n], 'name' })
                local icon = H.findLayoutByPath(selected, { Slots[n], 'icon' })

                if record and amount > 0 then
                    local effects = record.effects
                    name.props.text = record.name .. ' (' .. H.addSeparators(amount) .. ')'
                    icon.props.resource = I.UIToolkit.texture(record.icon)
                    local known = A.getKnownEffectFlagsForIngredient(record, player)
                    for i = 1, 4 do
                        icon = H.findLayoutByPath(selected, { Slots[n], 'effects', 'effect_' .. i })
                        if #effects >= i and effects[i] then
                            local effect = effects[i]
                            if known[i] then
                                icon.props.resource = T.effectIconTexture(effect.id)
                                icon.props.alpha = A.containsEffect(self.data.matching, effect) and 1 or 0.5
                            else
                                icon.props.resource = I.UIToolkit.texture(UNKNOWN_PATH)
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
                        icon = H.findLayoutByPath(selected, { Slots[n], 'effects', 'effect_' .. i })
                        icon.props.resource = nil
                    end
                end
            end

            for i = 1, #Slots do updateSelected(i) end

            auxUi.deepUpdate(element)
        end,
    }
    local function makeRow(index)
        local name = M.namedActiveHeader('name', function() return getId(index) end,
            function() onClick(index) end,
            function() return tooltipFn(index) end)
        name.layout.external = { grow = 1 }
        return {
            name = Slots[index],
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                autoSize = false,
                arrange = ui.ALIGNMENT.Center,
                size = v2(BLOCK_WIDTH - 10, ICON_SZ),
            },
            content = ui.content {
                M.namedIcon('icon', ICON_SZ),
                T.intervalH(10),
                name,
                M.namedEffects('effects'),
            },
        }
    end
    local box = {
        name = 'selected-box',
        template = T.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.padding(5),
                content = ui.content {
                    {
                        name = 'selected',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = false,
                            arrange = ui.ALIGNMENT.Start,
                            align = ui.ALIGNMENT.Start,
                            autoSize = false,
                            size = v2(BLOCK_WIDTH - 10, ICON_SZ * 4 + GAP_ICON * 3),
                        },
                        content = ui.content {
                            makeRow(1),
                            T.intervalV(GAP_ICON),
                            makeRow(2),
                            T.intervalV(GAP_ICON),
                            makeRow(3),
                            T.intervalV(GAP_ICON),
                            makeRow(4),
                        },
                    },
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
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = ui.content {
                    {
                        template = T.text(),
                        props = {
                            text = C.Strings.INGREDIENTS,
                            textSize = TITLE_TEXT,
                        },
                    },
                    T.intervalH(6),
                    I.UIToolkit.Interactive.makeInteractive({
                        name = 'btn-clear-selected',
                        onClick = function() self:clearAllSelectedIngredients() end,
                        tooltip = l10n('TipClearSelected'),
                    }, {
                        type = ui.TYPE.Image,
                        props = {
                            resource = I.UIToolkit.texture(REVERT_PATH),
                            size = v2(TITLE_TEXT, TITLE_TEXT),
                        },
                        userData = { colorable = true, },
                    }),
                },
            },
            T.intervalV(3),
            box,
        }
    }
    wdg.element = element
    return wdg
end

function Window:makeResultingEffects()
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
            T.intervalH(5),
        }

        if value > 0 then
            content:add {
                name = 'value-icon',
                type = ui.TYPE.Image,
                props = {
                    size = v2(1, 1) * INNER_TEXT,
                    resource = I.UIToolkit.texture('icons/gold.dds'),
                }
            }
            content:add {
                name = 'value-text',
                template = T.text(),
                props = {
                    text = ' ' .. H.addSeparators(value),
                    anchor = v2(0.5, 0),
                    relativePosition = v2(0.5, 0),
                }
            }
            content:add(T.intervalH(15))
        end

        if weight > 0 then
            content:add {
                name = 'weight-icon',
                type = ui.TYPE.Image,
                props = {
                    size = v2(1, 1) * INNER_TEXT,
                    resource = I.UIToolkit.texture('icons/weight.dds'),
                }
            }
            content:add {
                name = 'weight-text',
                template = T.text(),
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
            local effectCount = P.effectRows
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
                            template = T.paragraph(),
                            props = {
                                -- neutralized here; nudge to the opposite mode where these effects apply
                                text = l10n('All_Effects_Neutralized') ..
                                    l10n(self.isPoison and 'Neutralized_Try_Potions' or 'Neutralized_Try_Poisons'),
                                textAlignH = ui.ALIGNMENT.Center,
                                size = v2(BLOCK_WIDTH - 10, 0),
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
                        content:add(T.effectIcon(effect.id, INNER_TEXT))
                        content:add(T.intervalH(4))
                        local effectText = full and H.createSpellEffectString(effect) or H.getMagicEffectString(effect)
                        content:add({ name = 'effect_text', template = T.text(), props = { text = effectText or '?', textSize = INNER_TEXT } })
                    else
                        content:add({ name = 'effect_text', template = T.text(), props = { text = '?', textSize = INNER_TEXT } })
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
                        table.insert(effectLayouts, T.intervalV(GAP_EFFECT))
                    end
                    if isVisible then
                        table.insert(effectLayouts, I.UIToolkit.Interactive.makeInteractive({
                            name = 'effect_' .. i,
                            tooltip = { key = effect.id, type = I.UTKTooltips.TYPE.MagicEffect },
                        }, effectLayout))
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
            effects.props.size = v2(BLOCK_WIDTH - 10, INNER_TEXT * effectCount + GAP_EFFECT * (effectCount - 1))

            auxUi.deepUpdate(element)
        end,
    }


    local box = {
        name = 'result-box',
        template = T.boxSolid,
        props = {},
        content = ui.content {
            {
                name = 'padding',
                template = T.padding(5),
                content = ui.content {
                    {
                        name = 'effect-list',
                        type = ui.TYPE.Flex,
                        props = {
                            autoSize = false,
                            arrange = ui.ALIGNMENT.Start,
                            align = ui.ALIGNMENT.Start,
                            size = v2(BLOCK_WIDTH - 10, INNER_TEXT * P.effectRows + GAP_EFFECT * (P.effectRows - 1)),
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
                type = ui.TYPE.Widget,
                props = { size = v2(BLOCK_WIDTH, TITLE_TEXT + 2) },
                content = ui.content {
                    {
                        name = 'title',
                        template = T.text(),
                        props = {
                            text = C.Strings.CREATED_EFFECTS,
                            textSize = TITLE_TEXT,
                        },
                    },
                    {
                        type = ui.TYPE.Container,
                        props = {
                            anchor = v2(1, 0),
                            relativePosition = v2(1, 0),
                        },
                        content = ui.content { info },
                    },
                },
            },
            T.intervalV(3),
            box,
        }
    }

    wdg.element = element
    return wdg
end

---@return UIToolkit.ItemList
function Window:makeIngredientList()
    local list = I.UIToolkit.Components.itemList {
        itemHeight = self.ingredientProvider.rowHeight,
        size = v2(BLOCK_WIDTH, BLOCK_WIDTH),
        provider = self.ingredientProvider,
        onItemClicked = function(item, _)
            self:selectIngredient(item)
        end
    }
    list:updateProps { position = v2(0, TITLE_TEXT + 3) }
    return list
end

---@return string[]
function Window:getSelectedIngredientList()
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

---@param n number
---@return openmw.types.IngredientRecord?, number
function Window:getSelectedIngredientRecord(n)
    if self.data and self.data.selected then
        local recordId = self.data.selected[n]
        if recordId then
            return types.Ingredient.records[recordId], self.data.ingredients[recordId] or 0
        end
    end
    return nil, 0
end

function Window:getTempPotionStats()
    local ingredients = self:getSelectedIngredientList()
    local draft, errorCode, knowledge = A.getPotionStats('temp', ingredients, self.data.apparatus, player,
        { isPoison = self.isPoison })
    --[[
    if errorCode == A.PotionErrors.OK then
        --TODO: apply modifiers
        draft = self.ctx.applyMods(draft, ingredients, { isPoison = self.isPoison, isPreview = true })
    end
    ]]
    return draft, errorCode, knowledge
end

function Window:getDefaultPotionName()
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

---@param type number
---@return openmw.types.ApparatusRecord?
function Window:getToolRecord(type)
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

---@param info IngredientItemData
function Window:selectIngredient(info)
    local data = self.data
    if not data.selected then data.selected = {} end
    local changed = false
    --Try to remove already selected ingredient
    for i = 1, 4 do
        local recordId = data.selected[i]
        if recordId and recordId == info.id then
            data.selected[i] = nil
            changed = true
            break
        end
    end

    --Try to add newly selected ingredient
    if not changed then
        for i = 1, 4 do
            if not data.selected[i] then
                data.selected[i] = info.id
                changed = true
                break
            end
        end
    end

    if changed then
        self:onIngredientSelectionChanged()
    end
end

function Window:clearSelectedIngredient(n)
    local data = self.data
    if data and data.selected and data.selected[n] then
        data.selected[n] = nil
        self:onIngredientSelectionChanged()
    end
end

function Window:clearFilter()
    self.filter:setValue('')
    self:updateEffectList()

    self.selectedEffects = {}
    self:updateEffectList()
end

---@param row IngredientItemData
function Window:filterIngredientByEffects(row)
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

function Window:updateIngredientList()
    if self.showEffects or not self.itemTable then return end
    local items = {}
    local filter = H.trim(self.filter:getValue():lower())
    for i = 1, #self.allIngredients do
        local item = self.allIngredients[i]
        if M.ingredientMatches(item, filter) and self:filterIngredientByEffects(item) then
            items[#items + 1] = item
        end
    end
    table.sort(items, M.comparator)
    self.itemTable:setItems(items)
end

function Window:updateEffectList()
    if not self.showEffects then return end
    --TODO: implement list filtering/updating
end

function Window:updateDefaultName()
    self.naming:setPlaceholder(self:getDefaultPotionName())
end

function Window:onPotionTypeUpdated()
    self.resultingEffects.update()
    self:updateDefaultName()
    if self.filterMatchingEffects then
        self:updateEffectList()
    end
end

function Window:updateData()
    -- parts.setInteractiveState(self.btnCreate, false, false)  --TODO: implement
    self.allIngredients = M.getAllIngredients(self.data)
    if self.showEffects then
        self:updateEffectList()
    else
        self:updateIngredientList()
    end
    self.tools.update()
end

function Window:setOnCLoseCallback(_callback)
    self._onClose = _callback
end

function Window:updateMatchingEffects()
    local ingredients = self:getSelectedIngredientList()
    self.data.matching, self.data.matchingKnowledge = A.getMatchingEffects(ingredients, player)
    self.data.nonMatching, self.data.nonMatchingKnowledge = A.getNonMatchingEffects(ingredients, player)
    self:updateDefaultName()
    self:updateIngredientList()
end

function Window:onIngredientSelectionChanged()
    self:updateMatchingEffects()
    self.selected.update()
    local items = self.itemTable:getItems()
    local selected = self.data.selected
    for i = 1, #items do
        local id = items[i].id
        local view = self.ingredientProvider:getCachedComponent(id)
        if view then
            view:active(M.ingredientSelected(id, selected))
        end
    end
    self.resultingEffects.update()
end

function Window:clearAllSelectedIngredients()
    if self.data and self.data.selected then
        self.data.selected = {}
        self:onIngredientSelectionChanged()
    end
end

-------- MISC HELPERS

---@param data AlchemyData
---@return IngredientItemData[]
function M.getAllIngredients(data)
    if not data.sources then return {} end

    ---@type AlchemyRedone.ListData.Ingredient[]
    local result = {}
    for id, count in pairs(data.ingredients) do
        local record = types.Ingredient.record(id)
        local name = record and record.name .. ' (' .. H.addSeparators(count) .. ')' or STRINGS.NONE
        table.insert(result, {
            id = id,
            count = count,
            name = name,
            searchText = M.getIngredientSearchText(record, player),
            isActive = function()
                if data and data.selected then
                    for i = 1, 4 do
                        local recordId = data.selected[i]
                        if recordId == id then return true end
                    end
                end
                return false
            end,
        })
    end
    return result
end

function M.getIngredientSearchText(recordOrId, actor)
    local record = A.toIngredientRecord(recordOrId)
    if not record then return '' end

    local searchParts = { record.name }

    for _, effectData in ipairs(H.getTooltipIngredientEffectEntries(record, actor)) do
        if effectData.visible and effectData.text and effectData.text ~= '' then
            table.insert(searchParts, '"' .. effectData.text .. '"')
        end
    end

    return table.concat(searchParts, '\n'):lower()
end

function M.comparator(a, b)
    local rA = types.Ingredient.record(a.id)
    local rB = types.Ingredient.record(b.id)

    if rA ~= nil and rB ~= nil then
        if rA.name ~= rB.name then return rA.name < rB.name end
    elseif rA == nil then
        return false
    elseif rB == nil then
        return true
    end

    return a.id < b.id
end

function M.ingredientMatches(row, filter)
    if #filter <= 0 then return true end
    local terms = H.splitString(filter, '|')
    if #terms <= 0 then return true end
    local haystack = row.searchText
    for i = 1, #terms do
        local term = H.trim(terms[i])
        if #term > 0 and haystack:find(term, 1, true) ~= nil then return true end
    end
    return false
end

function M.namedText(name)
    return {
        name = name,
        template = T.text(),
        props = {
            text = '',
            textSize = INNER_TEXT,
        },
    }
end

function M.namedHeader(name, tooltipFn)
    local layout = {
        name     = name,
        template = T.header(),
        props    = {
            text = '',
            textSize = INNER_TEXT,
        },
    }
    if not tooltipFn then return layout end
    return I.UIToolkit.Interactive.makeInteractive({ tooltip = tooltipFn }, layout)
end

function M.namedActiveHeader(name, getId, onClick, tooltipFn)
    return I.UIToolkit.Interactive.makeInteractive({
            onClick = onClick,
            tooltip = tooltipFn,
            name = getId and getId() or name
        },
        {
            name = name,
            template = T.text(),
            props = {
                text = '',
                textSize = INNER_TEXT,
            },
            userData = {
                colorable = true,
            },
        })
end

function M.namedIcon(name, sz)
    sz = sz or INNER_TEXT
    return {
        name = name,
        type = ui.TYPE.Image,
        props = {
            size = v2(sz, sz),
        },
    }
end

function M.effectIcon(idx)
    return M.namedIcon('effect_' .. idx)
end

function M.ingredientSelected(id, selected)
    if not selected then return false end
    for i = 1, 4 do
        if selected[i] == id then return true end
    end
    return false
end

---@param text string
---@param width number?
---@return UTKTooltips.AnyTooltip
function M.paragraphTooltip(text, width)
    return {
        body = l10n(text, C.TextColorParams),
        width = width or 200
    }
end

function M.namedEffects(name)
    --TODO: since we know all sizes, replace Flex with Container?
    return {
        name = name,
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
        },
        content = ui.content {
            M.effectIcon(1),
            T.intervalH(5),
            M.effectIcon(2),
            T.intervalH(5),
            M.effectIcon(3),
            T.intervalH(5),
            M.effectIcon(4),
        },
    }
end

return Window

---@omw-context player

local core = require('openmw.core')
local async = require('openmw.async')
local storage = require('openmw.storage')
local types = require("openmw.types")
local input = require('openmw.input')
local util = require('openmw.util')
local player = require('openmw.self')
local auxUi = require('openmw_aux.ui')

local I = require('openmw.interfaces')
local H = require('scripts.TPABOBAP.UIToolkit.helpers')
local C = require('scripts.TPABOBAP.UIToolkit.constants')
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")
local AlchemyWindow = require('scripts.TPABOBAP.AlchemyRedone.ui.alchemy_window')
local Ingredients = require("scripts.TPABOBAP.AlchemyRedone.ui.ingredients")
local config = require("scripts.TPABOBAP.AlchemyRedone.config")


local function updatePermissions()
    ---@type AlchemyPermissionUpdateEvent
    local data = {
        actor = player,
        permissions = {
            enabled = true, --TODO: get from config
            allowCorpses = config.main.b_AllowCorpseIngredients,
            allowOwned = config.main.b_AllowOwnedContainerIngredients,
        }
    }
    core.sendGlobalEvent('TPA_AlchemyRedone_UpdatePermissions', data)
end

storage.playerSection('TPA_AlchemyRedone/MainSettings'):subscribe(async:callback(updatePermissions))

local needsInitialization = true

---@return AlchemyData
local function defaultData()
    return {
        apparatus = {},
        sources = {},
        selected = {},
        ingredients = {},
    }
end

local m = {
    ---@type AlchemyWindow?
    wndAlchemy = nil,
}

---@class AlchemyData
---@field apparatus LocalApparatusIds
---@field sources openmw.GObject[]
---@field ingredients table<string, integer>
---@field selected string[]
---@field matching? openmw.core.MagicEffectWithParams[]
---@field matchingKnowledge? table<integer, boolean>
---@field nonMatching? openmw.core.MagicEffectWithParams[]
---@field nonMatchingKnowledge? table<integer, boolean>

---@class AlchemyContext: WindowContext
---@field potionModifiers { id: string, mod: TPA_AlchemyRedone.PotionModifier }[]
---@field data AlchemyData
---@field selectIngredient fun(info: IngredientInfo)
---@field clearIngredient fun(n:integer)
---@field getAllIngredients fun():table[]

---@type AlchemyContext
local ctx = {
    potionModifiers = {},
    updateQueue = {},
    focusedScrollable = nil,
    data = defaultData(),
    selectIngredient = function(info) m.selectIngredient(info) end,
    clearIngredient = function(n) m.clearIngredient(n) end,
    getAllIngredients = function() return m.getAllIngredients() end,
}

m.onOpenAlchemy = function(data)
    ctx.data.apparatus = data.apparatus
    ctx.data.sources = data.sources
    m.updateIngredients()
    if m.wndAlchemy then m.wndAlchemy:updateData() end
    if I.UI.getMode() ~= I.UI.MODE.Alchemy then
        I.UI.addMode(I.UI.MODE.Alchemy, { windows = { I.UI.WINDOW.Alchemy } })
    end
end

m.openWindow = function()
    m.closeWindow()
    m.wndAlchemy = AlchemyWindow:new()

    if #ctx.data.sources <= 0 then
        core.sendGlobalEvent('TPA_AlchemyRedone_CollectInfo', { actor = player })
    end

    m.wndAlchemy:init(ctx)
end

m.closeWindow = function()
    if m.wndAlchemy then
        m.wndAlchemy:destroy()
        m.wndAlchemy = nil
    end

    if ctx.activeTooltip then
        auxUi.deepDestroy(ctx.activeTooltip)
        ctx.activeTooltip = nil
    end
    ctx.data = defaultData()
end

m.selectIngredient = function(info)
    if not ctx.data.selected then ctx.data.selected = {} end
    local changed = false
    --Try to remove already selected ingredient
    for i = 1, 4 do
        local recordId = ctx.data.selected[i]
        if recordId and recordId == info.id then
            ctx.data.selected[i] = nil
            changed = true
            break
        end
    end

    --Try to add newly selected ingredient
    if not changed then
        for i = 1, 4 do
            if not ctx.data.selected[i] then
                ctx.data.selected[i] = info.id
                changed = true
                break
            end
        end
    end

    if changed then
        if m.wndAlchemy then
            m.wndAlchemy:onIngredientSelectionChanged()
        end
    end
end

m.clearIngredient = function(n)
    if ctx.data and ctx.data.selected then
        if ctx.data.selected[n] then
            ctx.data.selected[n] = nil
            if m.wndAlchemy then
                m.wndAlchemy:onIngredientSelectionChanged()
            end
        end
    end
end

m.updateIngredients = function()
    local map = {}
    ctx.data.ingredients = map
    for i = 1, #ctx.data.sources do
        local source = ctx.data.sources[i]
        local list = source.type.inventory(source):getAll(types.Ingredient)
        for j = 1, #list do
            local ingredient = list[j]
            map[ingredient.recordId] = (map[ingredient.recordId] or 0) + ingredient.count
        end
    end

    local selected = ctx.data.selected
    if selected then
        for i = 1, 4 do
            local recordId = selected[i]
            if recordId then
                local count = ctx.data.ingredients[recordId]
                if not count or count <= 0 then
                    selected[i] = nil
                end
            end
        end
    end
end

m.getAllIngredients = function()
    if not ctx.data.sources then
        return {}
    end

    local result = {}
    for id, count in pairs(ctx.data.ingredients) do
        local record = types.Ingredient.record(id)
        local name = record and record.name .. ' (' .. H.addSeparators(count) .. ')' or C.Strings.NONE
        table.insert(result, {
            id = id,
            count = count,
            name = name,
            searchText = Ingredients.getSearchText(record, player),
            activeFn = function()
                if ctx.data and ctx.data.selected then
                    for i = 1, 4 do
                        local recordId = ctx.data.selected[i]
                        if recordId == id then return true end
                    end
                end
                return false
            end,
        })
    end
    return result
end

m.updateWnd = function(wnd, deep)
    if wnd then wnd:update(deep) end
end

---@param modId string
---@param mod TPA_AlchemyRedone.PotionModifier
m.registerPotionModifier = function(modId, mod)
    if type(modId) ~= 'string' or type(mod) ~= 'function' then
        core.sendGlobalEvent('TPA_AlchemyRedone_PrintError', {
            'Error while registering potion modifier:',
            'TPA_AlchemyRedone.registerPotionModifier accepts 2 arguments: modId (string) and mod (function)!',
            'Got modId as "' .. type(modId) .. '" and mod as "' .. type(mod) .. '"'
        })
        return
    end
    for i = 1, #ctx.potionModifiers do
        local existingModifier = ctx.potionModifiers[i]
        if existingModifier.id:lower() == modId:lower() then
            existingModifier.mod = mod
            return
        end
    end
    table.insert(ctx.potionModifiers, { id = modId, mod = mod })
end

---@param modId string
m.unregisterPotionModifier = function(modId)
    local k = nil
    for i = 1, #ctx.potionModifiers do
        local existingModifier = ctx.potionModifiers[i]
        if existingModifier.id:lower() == modId:lower() then
            k = i
            break
        end
    end
    if k then
        table.remove(ctx.potionModifiers, k)
    end
end

---@param item GameObject
---@param layout openmw.ui.Layout
---@return openmw.ui.Layout?
m.modifyTooltip = function(item, layout)
    if not config.rework.b_Enabled then return end
    if item.type == types.Potion or item.type == types.Ingredient then
        local effects = H.findLayoutByPathSafe(layout, { 'padding', 'tooltip', 'effects' })
        if not effects then return end
        effects.content = Ingredients.getIEMagicEffectsContent(item, player)
    end
end

m.getKnownEffectFlagsForItem = function(item)
    if item.type == types.Potion then
        return A.getKnownEffectFlagsForPotion(A.toPotionRecord(item.recordId), player)
    elseif item.type == types.Ingredient then
        return A.getKnownEffectFlagsForIngredient(A.toIngredientRecord(item.recordId), player)
    end
    return {}
end

---@param evt openmw.input.KeyboardEvent
local function onKeyRelease(evt)
    if evt.code == input.KEY.Escape then
        m.closeWindow()
        return
    end
end

local function openWindow()
    m.openWindow()
end

local function closeWindow()
    m.closeWindow()
end

---@param data CreatedPotionData
m.useSkill = function(data)
    A.updateBrewedPotionKnowledge(data.potion, data.ingredients, player)

    I.SkillProgression.skillUsed('alchemy', {
        useType = I.SkillProgression.SKILL_USE_TYPES.Alchemy_CreatePotion,
        scale = data.brewed,
        alchemyRedone = data,
    })
end

local function onMouseWheel(v, h)
    if ctx.focusedScrollable and ctx.focusedScrollable.layout then
        local layout = ctx.focusedScrollable.layout
        local pos = layout.content[1].props.position
        layout.content[1].props.position = util.vector2(
            pos.x,
            util.clamp(pos.y + v * layout.userData.scrollStep, -layout.userData.scrollLimit, 0)
        )
        layout.userData.onScroll()
    end
end

local function onFrame()
    if I.UI.getMode() ~= I.UI.MODE.Alchemy then return end

    for element in pairs(ctx.updateQueue) do
        element:update()
    end
    ctx.updateQueue = {}
end

local function onUpdate()
    if needsInitialization then
        needsInitialization = false

        if I.InventoryExtender then
            I.InventoryExtender.registerTooltipModifier('alchemy-redone', m.modifyTooltip)
        end

        updatePermissions()
    end
end

local function onConsume(item)
    A.onItemConsumed(item)
end

---@class AlchemySaveData
---@field version integer
---@field knowledge AlchemyKnowledge?

---@param loadData AlchemySaveData
local function onLoad(loadData)
    local knowledge = loadData and loadData.knowledge
    if knowledge then
        A.knowledge.potionKnowledge = knowledge.potionKnowledge or {}
        A.knowledge.ingredientKnowledge = knowledge.ingredientKnowledge or {}
        A.knowledge.recipeProgress = knowledge.recipeProgress or {}
    end
end

---@return AlchemySaveData
local function onSave()
    return {
        version = 1,
        knowledge = A.knowledge,
    }
end

---@type openmw.interfaces.TPA_AlchemyRedone
local Interface = {
    apiVersion = 1,
    registerPotionModifier = m.registerPotionModifier,
    unregisterPotionModifier = m.unregisterPotionModifier,
    --knowledge = knowledge, --Not sure if this is needed to be exported
    getKnownEffectFlagsForItem = m.getKnownEffectFlagsForItem,
}

I.UI.registerWindow(I.UI.WINDOW.Alchemy, openWindow, closeWindow)

return {
    interfaceName = 'TPA_AlchemyRedone',
    interface = Interface,
    engineHandlers = {
        onKeyRelease = onKeyRelease,
        onMouseWheel = onMouseWheel,
        onFrame = onFrame,
        onUpdate = onUpdate,
        onConsume = onConsume,
        onLoad = onLoad,
        onSave = onSave,
    },
    eventHandlers = {
        TPA_AlchemyRedone_Open = m.onOpenAlchemy,
        TPA_AlchemyRedone_UseSkill = m.useSkill,
    },
}

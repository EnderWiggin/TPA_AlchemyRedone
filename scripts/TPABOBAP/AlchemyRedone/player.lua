---@omw-context player

local core = require('openmw.core')
local ambient = require('openmw.ambient')
local async = require('openmw.async')
local storage = require('openmw.storage')
local types = require("openmw.types")
local input = require('openmw.input')
local ui = require('openmw.ui')
local util = require('openmw.util')
local player = require('openmw.self')
local auxUi = require('openmw_aux.ui')

local I = require('openmw.interfaces')
local H = require('scripts.TPABOBAP.UIToolkit.helpers')
local C = require('scripts.TPABOBAP.UIToolkit.constants')
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")
local AlchemyWindow = require('scripts.TPABOBAP.AlchemyRedone.ui.alchemy_window')
local T = {
    Alchemy = require("scripts.TPABOBAP.AlchemyRedone.ui.alchemy")
}
local cfgPlayer = require('scripts.TPABOBAP.AlchemyRedone.config.player')
local cfgGlobal = require('scripts.TPABOBAP.AlchemyRedone.config.global')


local function updatePermissions()
    ---@type AlchemyPermissionUpdateEvent
    local data = {
        actor = player,
        permissions = {
            enabled = cfgPlayer.main.b_Enabled,
            allowCorpses = cfgPlayer.main.b_AllowCorpseIngredients,
            allowOwned = cfgPlayer.main.b_AllowOwnedContainerIngredients,
        }
    }
    core.sendGlobalEvent('TPA_AlchemyRedone_UpdatePermissions', data)
end

storage.playerSection('TPA_AlchemyRedone/MainSettings'):subscribe(async:callback(updatePermissions))

local needsInitialization = true

---@param prev AlchemyData?
---@return AlchemyData
local function defaultData(prev)
    ---@type AlchemyData
    local data = {
        apparatus = {},
        sources = {},
        selected = {},
        ingredients = {},
        favoriteEffects = prev and prev.favoriteEffects or {},
    }
    return data
end

local buttonPressDuration = {}
local hasData = false

local m = {
    ---@type AlchemyWindow?
    wndAlchemy = nil,
}

---@alias NameOrGetter string|fun():string

---@class AlchemyData
---@field apparatus LocalApparatusIds
---@field sources openmw.GObject[]
---@field ingredients table<string, integer>
---@field selected string[]
---@field matching? openmw.core.MagicEffectWithParams[]
---@field matchingKnowledge? table<integer, boolean>
---@field nonMatching? openmw.core.MagicEffectWithParams[]
---@field nonMatchingKnowledge? table<integer, boolean>
---@field favoriteEffects table<string, boolean>

---@class AlchemyContext: WindowContext
---@field potionModifiers { id: string, mod: TPA_AlchemyRedone.PotionModifier }[]
---@field data AlchemyData
---@field applyMods fun(draft:openmw.types.PotionRecord, ingredients:string[]):openmw.types.PotionRecord
---@field brewPotions fun(name: NameOrGetter, count: integer, ingredients:string[], isPoison: boolean): boolean
---@field selectIngredient fun(info: IngredientItemData)
---@field clearSelectedIngredient fun(n:integer)
---@field clearAllSelectedIngredients fun()
---@field getAllIngredients fun():IngredientItemData[]
---@field getAllEffects fun():EffectItemData[]

---@type AlchemyContext
local ctx = {
    potionModifiers = {},
    updateQueue = {},
    focusedScrollable = nil,
    data = defaultData(),
    selectIngredient = function(info) m.selectIngredient(info) end,
    clearSelectedIngredient = function(n) m.clearSelectedIngredient(n) end,
    clearAllSelectedIngredients = function() m.clearAllSelectedIngredients() end,
    getAllIngredients = function() return m.getAllIngredients() end,
    getAllEffects = function() return m.getAllEffects() end,
    setTooltip = function(id, tipFn, props) return m.setTooltip(id, tipFn, props) end,
    setHovered = function(element) return m.setHovered(element) end,
    applyMods = function(draft, ingredients) return m.applyMods(draft, ingredients) end,
    brewPotions = function(name, count, ingredients, isPoison) return m.brewPotions(name, count, ingredients, isPoison) end,
}

m.onOpenAlchemy = function(data)
    hasData = true
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

    if not hasData then
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

    ctx.data = defaultData(ctx.data)
    hasData = false
end

---@param id string
---@param tooltipFn TipFn
---@param props {position:openmw.util.Vector2?, anchor: openmw.util.Vector2?, relativePosition:openmw.util.Vector2?}
m.setTooltip = function(id, tooltipFn, props)
    if ctx.activeTooltip and ctx.activeTooltip.layout then
        if ctx.activeTooltip.layout.name ~= id then
            auxUi.deepDestroy(ctx.activeTooltip)
            ctx.activeTooltip = nil
        else
            return ctx.activeTooltip
        end
    end
    local tip = tooltipFn and tooltipFn()
    if not tip then return end
    ctx.activeTooltip = ui.create(tip)
    ctx.activeTooltip.layout.name = id

    if props then
        local p = ctx.activeTooltip.layout.props or {}
        if props.position then p.position = props.position end
        if props.anchor then p.anchor = props.anchor end
        if props.relativePosition then p.relativePosition = props.relativePosition end
    end

    ctx.activeTooltip:update()
    return ctx.activeTooltip
end

---@param element openmw.ui.Element?
m.setHovered = function(element)
    if ctx.focusedInteractive and ctx.focusedInteractive.layout then
        ctx.focusedInteractive.layout.userData.hovering = false
        H.setInteractiveColor(ctx.focusedInteractive.layout)
        ctx.updateQueue[ctx.focusedInteractive] = true
    end

    if element and element.layout then
        element.layout.userData.hovering = true
        H.setInteractiveColor(element.layout)
        ctx.updateQueue[element] = true
    end

    m.setFocused(element)
end

---@param element openmw.ui.Element?
m.setFocused = function(element)
    if element and element.layout then
        ctx.focusedInteractiveDelayed = element
    else
        ctx.focusedInteractiveDelayed = false
    end
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

m.clearSelectedIngredient = function(n)
    if ctx.data and ctx.data.selected then
        if ctx.data.selected[n] then
            ctx.data.selected[n] = nil
            if m.wndAlchemy then
                m.wndAlchemy:onIngredientSelectionChanged()
            end
        end
    end
end

m.clearAllSelectedIngredients = function()
    if ctx.data and ctx.data.selected then
        ctx.data.selected = {}
        if m.wndAlchemy then
            m.wndAlchemy:onIngredientSelectionChanged()
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

---@return IngredientItemData[]
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
            searchText = T.Alchemy.getIngredientSearchText(record, player),
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

---@return EffectItemData[]
m.getAllEffects = function()
    if not ctx.data.sources then
        return {}
    end

    ---@type table<string, EffectItemData>
    local effects = {}

    for id, _ in pairs(ctx.data.ingredients) do
        local record = types.Ingredient.record(id)
        local known = A.getKnownEffectFlagsForIngredient(record, player)
        if record then
            for i = 1, #record.effects do
                local effect = record.effects[i]
                local key = A.effectKey(effect)
                if not effects[key] and known[i] then
                    effects[key] = {
                        id = key,
                        effectId = effect.id,
                        affectedAttribute = effect.affectedAttribute,
                        affectedSkill = effect.affectedSkill,
                        isFavorite = function() return ctx.data.favoriteEffects[key] == true end,
                    }
                end
            end
        end
    end
    local result = {}
    for _, data in pairs(effects) do
        local name = H.getMagicEffectString(T.Alchemy.effectDataToEffect(data))
        table.insert(result, {
            id = data.id,
            effectId = data.effectId,
            affectedSkill = data.affectedSkill,
            affectedAttribute = data.affectedAttribute,
            name = name,
            searchText = '"' .. name .. '"',
            activeFn = function()
                if not m.wndAlchemy then return false end
                for i = 1, #m.wndAlchemy.selectedEffects do
                    if m.wndAlchemy.selectedEffects[i].id == data.id then return true end
                end
                return false
            end,
            isFavorite = data.isFavorite,
        })
    end
    return result
end

local function handleModError(...)
    core.sendGlobalEvent('TPA_AlchemyRedone_PrintError', { ... })
end

---@param draft openmw.types.PotionRecord
---@param ingredients string[]
m.applyMods = function(draft, ingredients)
    for i = 1, #ctx.potionModifiers do
        local modData = ctx.potionModifiers[i]
        local ok, result = xpcall(modData.mod, function(err)
            handleModError(('ERROR in potion modifier [%s]'):format(modData.id), err)
        end, draft, ingredients)
        if ok then
            draft = result or draft
        end
    end
    return draft
end

---returns the amount of selected ingredient that's smallest - this is our limit for brewing batch size
---@param ingredients string[]
---@return integer
local function getLeastIngredientAmount(ingredients)
    local min = math.huge
    for i = 1, #ingredients do
        local count = ctx.data.ingredients[ingredients[i]]
        if count then
            min = math.min(min, count)
        end
    end
    return min
end

---@param name NameOrGetter
---@param count integer
---@param ingredients string[]
---@param isPoison boolean
m.brewPotions = function(name, count, ingredients, isPoison)
    count = math.min(count, getLeastIngredientAmount(ingredients))
    local opts = { isPoison = isPoison, useSkillForArtSelection = cfgPlayer.main.b_PotionArtUsesSkill }
    local function getName()
        if type(name) == "string" then return name end
        return name()
    end
    local draft, errorCode, known = A.getPotionStats(getName(), ingredients, ctx.data.apparatus or {}, player, opts)
    local brewed = 0

    if errorCode == A.PotionErrors.OK then
        local factor = A.getAlchemyFactor(player)
        for _ = 1, count do
            if A.checkPotionBrewSuccess(factor) then
                brewed = brewed + 1
            end
        end

        if brewed <= 0 then
            errorCode = A.PotionErrors.FAIL
        end
    end
    if errorCode == A.PotionErrors.OK then --Brewing succeeded
        local effects
        draft = m.applyMods(draft, ingredients)
        local prevDraft = draft
        ---@type {draft:openmw.types.PotionRecord, count:integer}[]
        local drafts = { { draft = draft, count = 0 } }
        local compareOpts = { ignore = { icon = true, model = true }, generated = true }
        local processed = 0
        repeat
            effects = draft.effects
            for i = 1, #effects do
                --this field can't be sent with event and it is not required to create new record
                effects[i].effect = nil
            end

            if A.potionRecordsEqual(prevDraft, draft, compareOpts) then
                drafts[#drafts].count = drafts[#drafts].count + 1
            else
                table.insert(drafts, { draft = draft, count = 1 })
                prevDraft = draft
            end

            A.updateIngredientKnowledge(ingredients, effects, known)
            I.SkillProgression.skillUsed('alchemy', {
                useType = I.SkillProgression.SKILL_USE_TYPES.Alchemy_CreatePotion,
                alchemyRedone = {
                    potion = draft,
                    ingredients = ingredients,
                    isPoison = isPoison,
                },
            })

            processed = processed + 1
            if processed < brewed then
                draft, errorCode, known = A.getPotionStats(getName(), ingredients, ctx.data.apparatus or {}, player, opts)
                draft = m.applyMods(draft, ingredients)
            end
        until processed >= brewed

        local msg = core.getGMST(A.PotionErrors.OK)
        if brewed > 1 then
            msg = msg .. ' ' .. getName() .. ' (' .. H.addSeparators(brewed) .. ')'
        end
        ui.showMessage(msg)
        ambient.playSound('potion success', { scale = false })
        ---@type FinalizePotionsData
        local data = {
            actor = player,
            drafts = drafts,
            ingredients = ingredients,
            count = count,
            sources = ctx.data.sources,
        }
        core.sendGlobalEvent('TPA_AlchemyRedone_FinalizePotions', data)
    elseif errorCode == A.PotionErrors.FAIL then -- Brewing was attempted, but failed
        ui.showMessage(core.getGMST(A.PotionErrors.FAIL))
        ambient.playSound('potion fail', { scale = false })
        ---@type FinalizePotionsData
        local data = {
            actor = player,
            drafts = {},
            ingredients = ingredients,
            count = count,
            sources = ctx.data.sources,
        }
        core.sendGlobalEvent('TPA_AlchemyRedone_FinalizePotions', data)
        --TODO: optionally grant skill use failure XP
    else -- Something prevented brewing, show error
        ui.showMessage(core.getGMST(errorCode))
        return true
    end
    return false
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
    if not cfgGlobal.rework.b_Enabled or not cfgPlayer.main.b_Enabled then return end
    if item.type == types.Potion or item.type == types.Ingredient then
        local effects = H.findLayoutByPathSafe(layout, { 'padding', 'tooltip', 'effects' })
        if not effects then return end
        effects.content = T.Alchemy.getIEMagicEffectsContent(item, player)
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

---@param id number
local function onControllerButtonPress(id)
    if not cfgPlayer.main.b_Enabled then return end
    if m.wndAlchemy then
        m.wndAlchemy:onControllerButtonPress(id)
    end
    buttonPressDuration[id] = 0
end

---@param id number
local function onControllerButtonRelease(id)
    buttonPressDuration[id] = nil
end

local function openWindow()
    m.openWindow()
end

local function closeWindow()
    m.closeWindow()
    core.sendGlobalEvent('TPA_AlchemyRedone_SimScale', { scale = 1 })
end

---@param data CreatedPotionData
m.finalizePotions = function(data)
    for i = 1, #data.potions do
        A.updateBrewedPotionKnowledge(data.potions[i], data.ingredients, player)
    end
end

local function onMouseWheel(v)
    if not cfgPlayer.main.b_Enabled then return end

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

local wasLT = false
local function onFrame()
    if not cfgPlayer.main.b_Enabled then return end
    if I.UI.getMode() ~= I.UI.MODE.Alchemy then return end

    if ctx.focusedInteractiveDelayed ~= nil then
        if ctx.focusedInteractiveDelayed == false then
            ctx.focusedInteractive = nil
        else
            ctx.focusedInteractive = ctx.focusedInteractiveDelayed
        end
        ctx.focusedInteractiveDelayed = nil
    end

    for element in pairs(ctx.updateQueue) do
        element:update()
    end
    ctx.updateQueue = {}

    local dt = core.getRealFrameDuration()
    local mouseMoved
    if I.UI.getMode() ~= nil then
        if input.getMouseMoveX() ~= 0 or input.getMouseMoveY() ~= 0 then
            mouseMoved = true
        end
    end

    local window = m.wndAlchemy
    if window then
        -- Clear stale hovered row pos if mouse moved NOT over the element's item table
        if mouseMoved then
            if window and window.itemTable and window.itemTable.layout and window.itemTable.layout.userData.getState then
                local state = window.itemTable.layout.userData.getState()
                local hadMouseMoveThisFrame = state.hadMouseMoveThisFrame
                state.hadMouseMoveThisFrame = false

                if not hadMouseMoveThisFrame and state.lastPointerRowPos then
                    state.lastPointerRowPos = nil
                    state.isPointerOverContent = false
                end
            end

            if window.element and not window.element.layout.userData.hadMouseMoveThisFrame then
                window:setFocused(false)
            end
            window.element.layout.userData.hadMouseMoveThisFrame = false
        end

        if window.element and window.element.layout.userData then
            local userData = window.element.layout.userData
            local focusDelayed = userData.focusDelayed
            if focusDelayed ~= nil then
                if not focusDelayed then
                    if ctx.cursorAttachedIcon then
                        ctx.cursorAttachedIcon.layout.props.visible = false
                        ctx.updateQueue[ctx.cursorAttachedIcon] = true
                    end
                end
                if focusDelayed ~= userData.focused then
                    userData.focused = focusDelayed
                end
                userData.focusDelayed = nil
            end
        end

        if cfgPlayer.controls.b_RepeatingButtons then
            for id, held in pairs(buttonPressDuration) do
                held = held + dt
                if held > cfgPlayer.controls.n_RepeatingButtonsThreshold then
                    held = held - cfgPlayer.controls.n_RepeatingButtonsStep
                    window:onControllerButtonRepeat(id)
                end
                buttonPressDuration[id] = held
            end
        end

        local LT = input.getAxisValue(input.CONTROLLER_AXIS.TriggerLeft) > 0.55

        if LT ~= wasLT then
            wasLT = LT
            if cfgPlayer.controls.b_AllowPrecisionMode then
                core.sendGlobalEvent('TPA_AlchemyRedone_SimScale', { scale = LT and 0.2 or 1 })
            end
        end
    end

    if ctx.focusedScrollable and ctx.focusedScrollable.layout then
        local rightStick = input.getAxisValue(input.CONTROLLER_AXIS.RightY)
        if math.abs(rightStick) > 0.2 then
            local layout = ctx.focusedScrollable.layout
            local pos = layout.content[1].props.position
            layout.content[1].props.position = util.vector2(
                pos.x,
                util.clamp(pos.y - rightStick * layout.userData.scrollStep / 4 * dt * 60, -layout.userData.scrollLimit, 0)
            )
            layout.userData.onScroll()
        end
    end
end

local function onUpdate()
    if not cfgPlayer.main.b_Enabled then return end
    if needsInitialization then
        needsInitialization = false

        if I.InventoryExtender then
            I.InventoryExtender.registerTooltipModifier('alchemy-redone', m.modifyTooltip)
        end

        updatePermissions()
    end
end

local function onConsume(item)
    if not cfgPlayer.main.b_Enabled then return end
    A.onItemConsumed(item, player)
end

---@class AlchemySaveData
---@field version integer
---@field knowledge AlchemyKnowledge?
---@field favoriteEffects table<string, boolean>?

---@param loadData AlchemySaveData
local function onLoad(loadData)
    A.loadKnowledge(loadData and loadData.knowledge)
    ctx.data.favoriteEffects = loadData and loadData.favoriteEffects or {}
end

---@return AlchemySaveData
local function onSave()
    return {
        version = 1,
        knowledge = A.knowledge,
        favoriteEffects = ctx.data.favoriteEffects
    }
end

---@type openmw.interfaces.TPA_AlchemyRedone
local Interface = {
    apiVersion = 1,
    isEnabled = function() return cfgPlayer.main.b_Enabled end,
    registerPotionModifier = m.registerPotionModifier,
    unregisterPotionModifier = m.unregisterPotionModifier,
    --knowledge = knowledge, --Not sure if this is needed to be exported
    getKnownEffectFlagsForItem = m.getKnownEffectFlagsForItem,
}

--- Requires both lua reload and save load to toggle.
if cfgPlayer.main.b_Enabled then
    I.UI.registerWindow(I.UI.WINDOW.Alchemy, openWindow, closeWindow)
end

return {
    interfaceName = 'TPA_AlchemyRedone',
    interface = Interface,
    engineHandlers = {
        onMouseWheel = onMouseWheel,
        onFrame = onFrame,
        onUpdate = onUpdate,
        onConsume = onConsume,
        onLoad = onLoad,
        onSave = onSave,
        onControllerButtonPress = onControllerButtonPress,
        onControllerButtonRelease = onControllerButtonRelease,
    },
    eventHandlers = {
        TPA_AlchemyRedone_Open = m.onOpenAlchemy,
        TPA_AlchemyRedone_FinalizePotions = m.finalizePotions,
    },
}

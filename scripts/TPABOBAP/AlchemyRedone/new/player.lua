---@omw-context player

local core = require('openmw.core')
local ambient = require('openmw.ambient')
local async = require('openmw.async')
local storage = require('openmw.storage')
local types = require("openmw.types")
local ui = require('openmw.ui')
local util = require('openmw.util')
local player = require('openmw.self')
local camera = require('openmw.camera')
local nearby = require('openmw.nearby')

local I = require('openmw.interfaces')
local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')
local H = require('scripts.UIToolkit.helpers')
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")
local AlchemyHandler = require('scripts.TPABOBAP.AlchemyRedone.new.alchemy_handler')

local T = {
    Base = require("scripts.TPABOBAP.UIToolkit.templates.base"),
    Special = require("scripts.TPABOBAP.UIToolkit.templates.special"),
    Alchemy = require("scripts.TPABOBAP.AlchemyRedone.ui.alchemy")
}
local cfgPlayer = require('scripts.TPABOBAP.AlchemyRedone.config.player')
local cfgGlobal = require('scripts.TPABOBAP.AlchemyRedone.config.global')
local l10n = core.l10n('TPA_AlchemyRedone')
local v2 = util.vector2

local function handleModError(...)
    core.sendGlobalEvent('TPA_AlchemyRedone_PrintError', { ... })
end

local sneaking = false
local WND_NAME = 'AlchemyRedone:Window'
---@type AlchemyRedone.Window?
local handler = nil

local function updatePermissions()
    ---@type AlchemyPermissionUpdateEvent
    local data = {
        actor = player,
        permissions = {
            enabled = cfgPlayer.main.b_Enabled,
            allowNearby = cfgPlayer.nearby.b_AllowNearbySources,
            allowCorpses = cfgPlayer.nearby.b_AllowCorpseIngredients,
            allowOwnedContainerIngredients = cfgPlayer.nearby.b_AllowOwnedContainerIngredients,
            allowFaction = cfgPlayer.nearby.b_AllowFactionOwned,
            allowOwnedApparatus = cfgPlayer.nearby.b_AllowOwnedApparatus,
            sneaking = sneaking,
        }
    }
    core.sendGlobalEvent('TPA_AlchemyRedone_UpdatePermissions', data)
end

-- carry saved values over from the old Main-section keys
do
    local oldMain = storage.playerSection(CFG.SECTION.MENU.Main)
    local nearbyCfg = storage.playerSection(CFG.SECTION.MENU.Nearby)
    for _, key in ipairs({ 'b_AllowOwnedContainerIngredients', 'b_AllowCorpseIngredients' }) do
        if nearbyCfg:get(key) == nil and oldMain:get(key) ~= nil then
            nearbyCfg:set(key, oldMain:get(key))
        end
    end
end

storage.playerSection(CFG.SECTION.MENU.Main):subscribe(async:callback(updatePermissions))
storage.playerSection(CFG.SECTION.MENU.Nearby):subscribe(async:callback(updatePermissions))

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

---@class AlchemyRedone.Context
local ctx = {
    potionModifiers = {},
    data = defaultData(),
    getAllIngredients = function() return m.getAllIngredients() end,
    getAllEffects = function() return m.getAllEffects() end,
    setTooltip = function(id, tipFn, props) return m.setTooltip(id, tipFn, props) end,
    setHovered = function(element) return m.setHovered(element) end,
    applyMods = function(draft, ingredients, opts) return m.applyMods(draft, ingredients, opts) end,
    brewPotions = function(name, count, ingredients, isPoison) return m.brewPotions(name, count, ingredients, isPoison) end,
}

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

---@param draft openmw.types.PotionRecord
---@param ingredients string[]
---@param opts PotionModifierOpts?
m.applyMods = function(draft, ingredients, opts)
    opts = opts or {}
    for i = 1, #ctx.potionModifiers do
        local modData = ctx.potionModifiers[i]
        local ok, result = xpcall(modData.mod, function(err)
            handleModError(('ERROR in potion modifier [%s]'):format(modData.id), err)
        end, draft, ingredients, opts)
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

local NOTICE_DURATION = 3.0
local noticeExpireAt = nil

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
        ---@type PotionModifierOpts
        local modOpts = { isPoison = isPoison }
        draft = m.applyMods(draft, ingredients, modOpts)
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
            xpcall(I.SkillProgression.skillUsed,
                function(err) handleModError('ERROR in `skill used` handler:', err) end,
                'alchemy', {
                    useType = I.SkillProgression.SKILL_USE_TYPES.Alchemy_CreatePotion,
                    alchemyRedone = {
                        potion = draft,
                        ingredients = ingredients,
                        isPoison = isPoison,
                    },
                })
            player:sendEvent('TPA_AlchemyRedone_PotionBrewed', {
                potion = draft,
                ingredients = ingredients,
                isPoison = isPoison,
            })

            processed = processed + 1
            if processed < brewed then
                draft, errorCode, known = A.getPotionStats(getName(), ingredients, ctx.data.apparatus or {}, player, opts)
                draft = m.applyMods(draft, ingredients, modOpts)
            end
        until processed >= brewed

        if handler then
            handler.tools.showNotice(getName(), brewed, count - brewed)
            noticeExpireAt = core.getRealTime() + NOTICE_DURATION
        else
            local msg = core.getGMST(A.PotionErrors.OK)
            if brewed > 1 then
                msg = msg .. ' ' .. getName() .. ' (' .. H.addSeparators(brewed) .. ')'
            end
            ui.showMessage(msg)
        end
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
        if handler then
            handler.tools.showNotice(getName(), 0, count)
            noticeExpireAt = core.getRealTime() + NOTICE_DURATION
        else
            ui.showMessage(core.getGMST(A.PotionErrors.FAIL))
        end
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
m.modifyIETooltip = function(item, layout)
    if not cfgGlobal.rework.b_Enabled or not cfgPlayer.main.b_Enabled then return end
    if item.type == types.Potion or item.type == types.Ingredient then
        local effects = H.findLayoutByPathSafe(layout, { 'padding', 'tooltip', 'effects' })
        if not effects then return end
        effects.content = T.Alchemy.getIEMagicEffectsContent(item, player)
    end
end

---@param tip SharedTooltip.TipContext
m.modifySharedTooltip = function(tip)
    ---@type boolean[]
    local knowledge
    ---@type openmw.ui.Layout
    local group
    ---@type table[]
    local effects
    ---@type boolean|'potion'
    local isAlchemy = true

    if tip.info.ingredientEffects then
        effects = tip.info.ingredientEffects
        group = tip.flex.content['ingredientEffects']
        knowledge = m.getKnownEffectFlagsForIngredient(tip.record.id)
    end

    if tip.info.potionEffects then
        effects = tip.info.potionEffects
        group = tip.flex.content['potionEffects']
        knowledge = m.getKnownEffectFlagsForPotion(tip.record.id)
        isAlchemy = 'potion'
    end

    if not group then return end
    for i = 1, #effects do
        local effect = effects[i]
        if effect then
            effect.known = knowledge[i]
        end
    end

    group.content = ui.content({})
    tip.printEffects(group, effects, isAlchemy)
end

local function findByName(items, name)
    for index, item in ipairs(items or {}) do
        if item.name == name then
            return item, index
        end
    end
end

---@param recipe UTKTooltips.Recipe
---@param tooltip UTKTooltips.Tooltip
m.modifyUTKTooltip = function(recipe, tooltip)
    local type = recipe.type or tooltip.type

    local isPotion = type == I.UTKTooltips.TYPE.Potion
    if not isPotion and type ~= I.UTKTooltips.TYPE.Ingredient then
        return
    end
    local observer = tooltip.observer -- or player
    local recordId = tooltip.key or tooltip.object.recordId
    ---@type boolean[]
    local knowledge = isPotion
        and A.getKnownEffectFlagsForPotion(recordId, observer)
        or A.getKnownEffectFlagsForIngredient(recordId, observer)

    for i = 1, #knowledge do
        knowledge[i] = not knowledge[i]
    end

    local item = findByName(recipe.items, I.UTKTooltips.CONTENT.MagicEffects)
    if not item then return end
    item.unknown = knowledge
end

m.getKnownEffectFlagsForItem = function(item)
    if item.type == types.Potion then
        return A.getKnownEffectFlagsForPotion(A.toPotionRecord(item.recordId), player)
    elseif item.type == types.Ingredient then
        return A.getKnownEffectFlagsForIngredient(A.toIngredientRecord(item.recordId), player)
    end
    return {}
end

m.getKnownEffectFlagsForPotion = function(recordId)
    return A.getKnownEffectFlagsForPotion(recordId, player)
end

m.getKnownEffectFlagsForIngredient = function(recordId)
    return A.getKnownEffectFlagsForIngredient(recordId, player)
end

---@return LocalApparatusIds
m.getActiveApparatus = function()
    return I.UIToolkit.WindowManager.isOpen(WND_NAME) and ctx.data.apparatus or {}
end

m.onOpenAlchemy = function(data)
    hasData = true
    ctx.data.apparatus = data.apparatus
    ctx.data.sources = data.sources
    m.updateIngredients()
    if handler then handler:updateData() end
    if I.UI.getMode() ~= I.UI.MODE.Alchemy then
        I.UI.addMode(I.UI.MODE.Alchemy, { windows = { I.UI.WINDOW.Alchemy } })
    end
end

local function openWindow()
    if not hasData then
        core.sendGlobalEvent('TPA_AlchemyRedone_CollectInfo', { actor = player })
    end
    I.UIToolkit.WindowManager.open(WND_NAME, ctx)
end

local function closeWindow()
    I.UIToolkit.WindowManager.close(WND_NAME)
    core.sendGlobalEvent('TPA_AlchemyRedone_SimScale', { scale = 1 })

    ctx.data = defaultData(ctx.data)
    hasData = false
end

---@param data CreatedPotionData
m.finalizePotions = function(data)
    for i = 1, #data.potions do
        A.updateBrewedPotionKnowledge(data.potions[i], data.ingredients, player)
    end
end

-- crosshair hint over world apparatus (activate = brew, sneak = take)
local hint = { widget = nil, text = nil }

local function hideApparatusHint()
    if not hint.widget then return end
    hint.widget:destroy()
    hint.widget = nil
end

local function showApparatusHint(text)
    if hint.widget and hint.text == text then return end
    hideApparatusHint()
    hint.text = text
    local layout = T.Special.lineTooltip(l10n(text), 'alchemy-usage-hint',
        { textAlignH = ui.ALIGNMENT.Center, textSize = T.Base.TEXT_SIZE, })
    layout.layer = 'HUD'
    layout.props.relativePosition = v2(0.5, 0.55)
    layout.props.anchor = v2(0.5, 0.5)
    hint.widget = ui.create(layout)
end

local hintScan = { last = 0, busy = false }
local function updateApparatusHint()
    if not cfgPlayer.main.b_Enabled
        or not cfgPlayer.nearby.b_AllowNearbySources
        or not cfgPlayer.ui.b_ShowUseHint
        or I.UI.getMode() ~= nil
        or camera.getMode() == camera.MODE.Vanity
        or camera.getMode() == camera.MODE.Static then
        hideApparatusHint()
        return
    end
    if hintScan.busy then return end
    local now = core.getRealTime()
    if now - hintScan.last < 0.25 then return end
    hintScan.last = now
    hintScan.busy = true
    local reach = (core.getGMST('iMaxActivateDist') or 192)
        + camera.getThirdPersonDistance()
    local camPos = camera.getPosition()
    local rayEnd = camPos + camera.viewportToWorldVector(v2(0.5, 0.5)) * reach
    nearby.asyncCastRenderingRay(
        async:callback(function(result)
            hintScan.busy = false
            if result.hit and result.hitObject
                and result.hitObject.type == types.Apparatus then
                showApparatusHint(sneaking and 'Apparatus_Hint_Take' or 'Apparatus_Hint_Use')
            else
                hideApparatusHint()
            end
        end),
        camPos, rayEnd, { ignore = player }
    )
end

local function onFrame()
    if not cfgPlayer.main.b_Enabled then return end
    -- global scripts cannot read input; relay sneak via permissions
    if player.controls.sneak ~= sneaking then
        sneaking = player.controls.sneak
        updatePermissions()
    end
    updateApparatusHint()
    if I.UI.getMode() ~= I.UI.MODE.Alchemy then return end

    if noticeExpireAt and core.getRealTime() >= noticeExpireAt then
        noticeExpireAt = nil
        if handler then handler.tools.hideNotice() end
    end
end

local function onUpdate()
    if not cfgPlayer.main.b_Enabled then return end
    if not needsInitialization then return end
    needsInitialization = false

    if I.InventoryExtender then
        I.InventoryExtender.registerTooltipModifier('alchemy-redone', m.modifyIETooltip)
    end

    if I.SharedTooltip then
        I.SharedTooltip.registerModifier { id = 'TPA_AlchemyRedone', priority = 0, func = m.modifySharedTooltip }
    end

    I.UI.registerWindow(I.UI.WINDOW.Alchemy, openWindow, closeWindow)
    I.UIToolkit.WindowManager.register(WND_NAME, {
        title = core.getGMST('sSkillAlchemy'),
        handler = function()
            handler = AlchemyHandler:new()
            handler:setOnCLoseCallback(function() handler = nil end)
            return handler
        end,
        resizing = true,
    })

    if I.UTKTooltips then
        I.UTKTooltips.addPreCreateTooltipHandler(m.modifyUTKTooltip)
    end

    updatePermissions()
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
    getKnownEffectFlagsForItem = m.getKnownEffectFlagsForItem,
    getKnownEffectFlagsForPotion = m.getKnownEffectFlagsForPotion,
    getKnownEffectFlagsForIngredient = m.getKnownEffectFlagsForIngredient,
    getActiveApparatus = m.getActiveApparatus,
}

return {
    interfaceName = 'TPA_AlchemyRedone',
    interface = Interface,
    engineHandlers = {
        onFrame = onFrame,
        onUpdate = onUpdate,
        onConsume = onConsume,
        onLoad = onLoad,
        onSave = onSave,
    },
    eventHandlers = {
        TPA_AlchemyRedone_Open = m.onOpenAlchemy,
        TPA_AlchemyRedone_FinalizePotions = m.finalizePotions,
    },
}

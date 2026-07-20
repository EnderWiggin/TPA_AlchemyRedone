---@omw-context global
local world = require("openmw.world")
local core = require("openmw.core")
local T = require("openmw.types")
local I = require("openmw.interfaces")
local H = require("scripts.TPABOBAP.UIToolkit.helpers")
local C = require("scripts.TPABOBAP.UIToolkit.constants")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")
local l10n = core.l10n('TPA_AlchemyRedone')

---@alias AlchemyPermissionCfg {enabled: boolean?, allowNearby: boolean?, allowCorpses: boolean?, allowOwned: boolean?, allowFaction: boolean?, sneaking: boolean?}
---@alias AlchemyPermissionUpdateEvent {actor: openmw.Object, permissions: AlchemyPermissionCfg}

---@type table<string, AlchemyPermissionCfg>
local config = {}


local m = {}

---@param actor openmw.GObject
---@return AlchemyPermissionCfg
m.getConfig = function(actor)
    return config[actor.id] or {}
end

---@param actor openmw.GObject
m.activateApparatus = function(object, actor)
    if actor.type == T.Player then
        local cfg = m.getConfig(actor)
        if not cfg.enabled then return true end
        -- sneak-activate = engine default: pick the apparatus up
        if cfg.sneaking then return true end
        if m.isAllowedApparatus(object, actor, cfg) then
            actor:sendEvent('TPA_AlchemyRedone_Open', m.collectAlchemyInfo(actor))
        else
            local type = H.getApparatusTypeLabel(object) or C.Strings.APPARATUS
            actor:sendEvent('ShowMessage', { message = l10n('Cant_Use_Owned_Apparatus', { apparatus = type }) })
        end
        return false
    end
    return true
end

---@param actor openmw.GObject
---@param cfg AlchemyPermissionCfg
---@param ... ObjectList
---@return LocalApparatusIds
m.collectApparatus = function(actor, cfg, ...)
    local lists = { ... }
    ---@type LocalApparatusIds
    local result = {}

    local qAlembic = 0
    local qCalcinator = 0
    local qMortar = 0
    local qRetort = 0

    for j = 1, #lists do
        local objectList = lists[j]
        for i = 1, #objectList do
            ---@type openmw.GObject
            local apparatus = objectList[i]
            local recordId = apparatus.recordId
            local record = T.Apparatus.record(recordId)
            if record and m.isAllowedApparatus(apparatus, actor, cfg) then
                local quality = record.quality
                local type = record.type
                if (type == T.Apparatus.TYPE.Alembic and quality > qAlembic) then
                    result.Alembic = recordId
                    qAlembic = quality
                end
                if (type == T.Apparatus.TYPE.Calcinator and quality > qCalcinator) then
                    result.Calcinator = recordId
                    qCalcinator = quality
                end
                if (type == T.Apparatus.TYPE.MortarPestle and quality > qMortar) then
                    result.Mortar = recordId
                    qMortar = quality
                end
                if (type == T.Apparatus.TYPE.Retort and quality > qRetort) then
                    result.Retort = recordId
                    qRetort = quality
                end
            end
        end
    end

    return result
end

---@param containers openmw.ObjectList<openmw.GObject>
---@param filter fun(container:openmw.GObject):boolean
---@return GObject[]
m.filterContainers = function(containers, filter)
    local result = {}
    for i = 1, #containers do
        ---@type openmw.GObject
        local container = containers[i]
        if filter(container) then
            table.insert(result, container)
        end
    end
    return result
end

---@param list openmw.ObjectList<openmw.Object>
m.formatIngredients = function(list)
    if not list or #list <= 0 then return nil end
    local infos = {}
    for k = 1, #list do
        ---@type openmw.Object
        local ingredient = list[k]
        table.insert(infos, { id = ingredient.recordId, count = ingredient.count })
    end
    return infos
end

---@param actor openmw.GObject
m.collectAlchemyInfo = function(actor)
    --TODO: search for apparatus in containers too? need to check container ownership in that case
    local cfg = m.getConfig(actor)
    local inventory = T.Player.inventory(actor)
    local apparatus = m.collectApparatus(actor, cfg,
        actor.cell:getAll(T.Apparatus),
        inventory:getAll(T.Apparatus)
    )
    local sources = m.filterContainers(actor.cell:getAll(T.Container), function(container)
        return m.isAllowedIngredientContainer(container, cfg, actor)
    end)

    if cfg.allowCorpses then
        local corpses = m.filterContainers(actor.cell:getAll(T.NPC), m.isAllowedCorpseContainer)
        for i = 1, #corpses do
            table.insert(sources, corpses[i])
        end

        corpses = m.filterContainers(actor.cell:getAll(T.Creature), m.isAllowedCorpseContainer)
        for i = 1, #corpses do
            table.insert(sources, corpses[i])
        end
    end

    if I.CCC_cont then
        local carried
        if I.CCC_cont.getContainersCarriedByPlayer then
            carried = I.CCC_cont.getContainersCarriedByPlayer()
            for i = 1, #carried do
                table.insert(sources, carried[i])
            end
        end
        if I.CCC_cont.getContainersNearbyPlayer then
            carried = I.CCC_cont.getContainersNearbyPlayer()
            for i = 1, #carried do
                table.insert(sources, carried[i])
            end
        end
    end

    table.insert(sources, actor)
    return { apparatus = apparatus, sources = sources }
end

m.addObject = function(actor, recordId, count)
    world.createObject(recordId, count or 1):moveInto(actor.type.inventory(actor))
end

---@class FinalizePotionsData
---@field actor openmw.self
---@field drafts {draft:openmw.types.PotionRecord, count:integer}[]
---@field ingredients string[]
---@field count integer
---@field sources openmw.GObject[]

---@class CreatedPotionData
---@field potions string[]
---@field ingredients string[]

---@param data FinalizePotionsData
m.finalizePotions = function(data)
    local potions = {}
    for i = 1, #data.drafts do
        local draft = data.drafts[i].draft
        local count = data.drafts[i].count
        local potion = A.findPotion(draft, { ignore = { icon = true, model = true }, generated = true })
        if not potion then
            draft = T.Potion.createRecordDraft(draft)
            potion = world.createRecord(draft)
        end
        table.insert(potions, potion.id)
        m.addObject(data.actor, potion.id, count)
    end

    if #potions > 0 then
        ---@type CreatedPotionData
        local final = { potions = potions, ingredients = data.ingredients }
        data.actor:sendEvent('TPA_AlchemyRedone_FinalizePotions', final)
    end
    m.deductIngredients(data)
end

---@param data {actor:openmw.GObject, sources:openmw.GObject[], ingredients:string[], count:integer}
m.deductIngredients = function(data)
    ---@type openmw.GObject[]
    local sources = data.sources
    ---@type string[]
    local ingredients = data.ingredients
    ---@type integer
    local count = data.count
    local actor = data.actor

    if not sources or #sources <= 0
        or not ingredients or #ingredients <= 0
        or not count or count <= 0
    then
        return
    end

    local consume = {}
    for i = 1, #ingredients do
        consume[ingredients[i]] = count
    end

    for i = 1, #sources do
        local source = sources[i]
        if source:isValid() then
            ---@type openmw.core.Inventory
            local inv = source.type.inventory(source)
            for id, need in pairs(consume) do
                local items = inv:findAll(id)
                for j = 1, #items do
                    local item = items[j]
                    local take = math.min(need, item.count)
                    item:remove(take)
                    need = need - take
                    if need <= 0 then
                        consume[id] = nil
                        break
                    else
                        consume[id] = need
                    end
                end
            end
        end
    end
    for _, need in pairs(consume) do
        if need > 0 then
            core.sendGlobalEvent('TPA_AlchemyRedone_PrintError', { 'WARNING: not consumed:', H.deepPrint(consume) })
            break
        end
    end
    actor:sendEvent('TPA_AlchemyRedone_Open', m.collectAlchemyInfo(actor))
end

---Returns whether apparatus is owned by someone
---@param object openmw.GObject
---@return boolean
m.isOwned = function(object)
    return object.owner ~= nil and (object.owner.recordId ~= nil or object.owner.factionId ~= nil)
end

---Returns whether object is unowned or faction owned with sufficient rank
---@param object openmw.GObject
---@param actor openmw.GObject
---@return boolean
m.isFreeToUse = function(object, actor)
    if not m.isOwned(object) then return true end
    local owner = object.owner
    if owner.recordId ~= nil then return false end
    if owner.factionId == nil then return false end
    local ok, rank = pcall(function()
        return T.NPC.getFactionRank(actor, owner.factionId)
    end)
    if not ok or not rank or rank <= 0 then return false end
    -- both 1-based (owner.factionRank via toLuaIndex; nil = no requirement)
    return rank >= (owner.factionRank or 1)
end

---Returns whether apparatus can be used by player
---@param object openmw.GObject
---@param actor openmw.GObject
---@param cfg AlchemyPermissionCfg
---@return boolean
m.isAllowedApparatus = function(object, actor, cfg)
    if cfg.allowOwned then return true end
    if cfg.allowFaction then return m.isFreeToUse(object, actor) end
    return not m.isOwned(object)
end

---@param object openmw.GObject
---@return boolean
m.isResolved = function(object)
    local inv = object.type.inventory and object.type.inventory(object)
    return inv and inv.isResolved and inv:isResolved()
end

---@param object openmw.GObject
---@param cfg AlchemyPermissionCfg
---@param actor openmw.GObject
---@return boolean
m.isAllowedIngredientContainer = function(object, cfg, actor)
    local usable = cfg.allowOwned == true
        or not m.isOwned(object)
        or (cfg.allowFaction == true and m.isFreeToUse(object, actor))
    return usable and m.isResolved(object)
end

---@param object openmw.GObject
---@return boolean
m.isAllowedCorpseContainer = function(object)
    return (object.type == T.Creature or object.type == T.NPC)
        and T.Actor.stats.dynamic.health(object).current == 0
        and m.isResolved(object)
end

---@param data AlchemyPermissionUpdateEvent
local function onUpdatePermissions(data)
    local p = data.permissions
    -- master off = all extra sources off; unowned stays available
    if p.allowNearby == false then
        p.allowCorpses, p.allowFaction, p.allowOwned = false, false, false
    end
    config[data.actor.id] = p
end

local function onUpdateSimScale(data)
    local scale = data and data.scale or 1
    world.setSimulationTimeScale(scale)
end

local function printError(data)
    if #data > 0 then
        local parts = {}
        for i = 1, #data do
            table.insert(parts, H.deepPrint(data[i]))
        end
        error(table.concat(parts, '\n\t'))
    else
        error(H.deepPrint(data))
    end
end

I.Activation.addHandlerForType(T.Apparatus, m.activateApparatus)

return {
    eventHandlers = {
        TPA_AlchemyRedone_CollectInfo = function(data)
            data.actor:sendEvent('TPA_AlchemyRedone_Open', m.collectAlchemyInfo(data.actor))
        end,
        TPA_AlchemyRedone_FinalizePotions = m.finalizePotions,
        TPA_AlchemyRedone_DeductIngredients = m.deductIngredients,
        TPA_AlchemyRedone_UpdatePermissions = onUpdatePermissions,
        TPA_AlchemyRedone_SimScale = onUpdateSimScale,
        TPA_AlchemyRedone_PrintError = printError,
    },
}

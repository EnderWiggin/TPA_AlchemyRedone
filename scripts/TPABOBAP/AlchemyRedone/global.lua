---@omw-context global
local world = require("openmw.world")
local core = require("openmw.core")
local T = require("openmw.types")
local I = require("openmw.interfaces")
local H = require("scripts.TPABOBAP.UIToolkit.helpers")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")
local config = require('scripts.TPABOBAP.AlchemyRedone.config')


local m = {}

---@param actor openmw.GObject
m.activateApparatus = function(_, actor)
    if actor.type == T.Player then
        actor:sendEvent('TPA_AlchemyRedone_Open', m.collectAlchemyInfo(actor))
        return false
    end
    return true
end

---@alias LocalApparatusIds {Mortar: string?, Alembic: string?, Calcinator: string?, Retort: string?}

---@param ... ObjectList
---@return LocalApparatusIds
m.collectApparatus = function(...)
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
            if record and m.isAllowedApparatus(apparatus) then
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
    local inventory = T.Player.inventory(actor)
    local apparatus = m.collectApparatus(
        actor.cell:getAll(T.Apparatus),
        inventory:getAll(T.Apparatus)
    )
    local sources = m.filterContainers(actor.cell:getAll(T.Container), m.isAllowedIngredientContainer)

    if config.main.b_AllowCorpseIngredients then
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

---@class CreateAndAddNewPotionData
---@field actor openmw.self
---@field batch integer
---@field brewed integer
---@field draft openmw.types.PotionRecord
---@field ingredients string[]

---@param data CreateAndAddNewPotionData
m.createAndAddNewPotion = function(data)
    local potion = A.findPotion(data.draft, { ignore = { icon = true, model = true }, generated = true })
    if not potion then
        local draft = T.Potion.createRecordDraft(data.draft)
        potion = world.createRecord(draft)
    end

    m.addObject(data.actor, potion.id, data.brewed)

    data.actor:sendEvent('TPA_AlchemyRedone_UseSkill', {
        batch = data.batch,
        brewed = data.brewed,
        potion = potion.id,
        ingredients = data.ingredients,
    })
end

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
                local item = inv:find(id)
                ---@cast item openmw.GObject
                if item then
                    local take = math.min(need, item.count)
                    item:remove(take)
                    need = need - take
                    if need <= 0 then
                        consume[id] = nil
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

---Returns whether apparatus can be used by player
---@param object openmw.GObject
---@return boolean
m.isAllowedApparatus = function(object)
    return not m.isOwned(object)
end

---@param object openmw.GObject
---@return boolean
m.isResolved = function(object)
    local inv = object.type.inventory and object.type.inventory(object)
    return inv and inv.isResolved and inv:isResolved()
end

---@param object openmw.GObject
---@return boolean
m.isAllowedIngredientContainer = function(object)
    return (config.main.b_AllowOwnedContainerIngredients or not m.isOwned(object)) and m.isResolved(object)
end

---@param object openmw.GObject
---@return boolean
m.isAllowedCorpseContainer = function(object)
    return (object.type == T.Creature or object.type == T.NPC)
        and T.Actor.stats.dynamic.health(object).current == 0
        and m.isResolved(object)
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
        TPA_AlchemyRedone_CreateAndAddNewPotion = m.createAndAddNewPotion,
        TPA_AlchemyRedone_AddItem = function(data) m.addObject(data.actor, data.recordId, data.count) end,
        TPA_AlchemyRedone_DeductIngredients = m.deductIngredients,
        TPA_AlchemyRedone_PrintError = printError,
    },
}

---@omw-context global
local world = require("openmw.world")
local T = require("openmw.types")
local I = require("openmw.interfaces")
local H = require("scripts.UIToolkit.helpers")



local m = {}

---@param object GameObject
---@param actor openmw.GObject
m.activateApparatus = function(object, actor)
    --TODO: search for apparatus in containers too? need to check container ownership in that case
    if actor.type == T.Player then
        local inventory = T.Player.inventory(actor)
        local apparatus = m.collectApparatus(
            actor.cell:getAll(T.Apparatus),
            inventory:getAll(T.Apparatus)
        )
        local ingredients = m.collectIngredients(actor.cell:getAll(T.Container))
        local actorIngredients = m.formatIngredients(inventory:getAll(T.Ingredient))
        if actorIngredients and #actorIngredients > 0 then
            ingredients[actor.id] = actorIngredients
        end
        actor:sendEvent('TPA_AlchemyRedone_Open', { apparatus = apparatus, ingredients = ingredients })
    end
    return false
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
            if record and m.isAllowed(apparatus) then
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
---@return LocalApparatusIds
m.collectIngredients = function(containers)
    local result = {}
    for i = 1, #containers do
        ---@type openmw.GObject
        local container = containers[i]
        if m.isAllowed(container) then
            local tmp = T.Container.inventory(container):getAll(T.Ingredient)
            local ingredients = m.formatIngredients(tmp)
            if ingredients and #ingredients > 0 then
                result[container.id] = ingredients
            end
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

m.collectAlchemyInfo = function(data)
    local cell = world.getCellById(data.cellId)
    local apparatus = m.collectApparatus(cell:getAll(T.Apparatus))
    --TODO: send event with this info?
end

m.addObject = function(actor, recordId, count)
    world.createObject(recordId, count or 1):moveInto(actor.type.inventory(actor))
end

m.createAndAddNewPotion = function(data)
    local draft = T.Potion.createRecordDraft(data.draft)
    local potion = world.createRecord(draft)
    m.addObject(data.actor, potion.id, 1)
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
m.isAllowed = function(object)
    return not m.isOwned(object)
end

I.Activation.addHandlerForType(T.Apparatus, m.activateApparatus)

return {
    eventHandlers = {
        TPA_AlchemyRedone_CollectInfo = m.collectAlchemyInfo,
        TPA_AlchemyRedone_CreateAndAddNewPotion = m.createAndAddNewPotion,
        TPA_AlchemyRedone_AddItem = function(data) m.addObject(data.actor, data.recordId, data.count) end,
    },
}

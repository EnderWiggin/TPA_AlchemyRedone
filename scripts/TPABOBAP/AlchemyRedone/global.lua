---@omw-context global
local world = require("openmw.world")
local T = require("openmw.types")
local I = require("openmw.interfaces")
local H = require("scripts.UIToolkit.helpers")



local m = {}

---@param object GameObject
---@param actor openmw.GObject
m.activateApparatus = function(object, actor)
    print('activateApparatus', object, actor)
    --TODO: search for apparatus in containers too? need to check container ownership in that case
    if actor.type == T.Player then
        local apparatus = m.collectApparatus(
            actor.cell:getAll(T.Apparatus),
            T.Player.inventory(actor):getAll(T.Apparatus)
        )
        actor:sendEvent('TPA_AlchemyRedone_Open', { apparatus = apparatus })
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
            ---@type GameObject
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

m.collectAlchemyInfo = function(data)
    local cell = world.getCellById(data.cellId)
    local apparatus = m.collectApparatus(cell:getAll(T.Apparatus))
    print('collectAlchemyInfo', cell, H.deepPrint(apparatus))
    --TODO: send event with this info?
end

---Returns whether apparatus is owned by someone
---@param object GameObject
---@return boolean
m.isOwned = function(object)
    return object.owner ~= nil and (object.owner.recordId ~= nil or object.owner.factionId ~= nil)
end

---Returns whether apparatus can be used by player
---@param object GameObject
---@return boolean
m.isAllowed = function(object)
    return not m.isOwned(object)
end

I.Activation.addHandlerForType(T.Apparatus, m.activateApparatus)

return {
    eventHandlers = {
        TPA_AlchemyRedone_CollectInfo = m.collectAlchemyInfo
    },
}

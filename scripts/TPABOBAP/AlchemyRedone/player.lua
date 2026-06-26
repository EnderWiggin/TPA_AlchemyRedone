---@omw-context player

local core = require('openmw.core')
local input = require('openmw.input')
local ui = require('openmw.ui')
local player = require('openmw.self')

local T = require("openmw.types")
local I = require('openmw.interfaces')
local H = require('scripts.UIToolkit.helpers')
local AlchemyWindow = require('scripts.TPABOBAP.AlchemyRedone.ui.alchemy_window')
local IngredientWindow = require('scripts.TPABOBAP.AlchemyRedone.ui.ingredient_window')


local m = {}

---@class AlchemyContext: WindowContext
---@field data {apparatus: LocalApparatusIds}?

---@type AlchemyContext
local ctx = {
    updateQueue = {},
    data = nil,
}

---@type AlchemyWindow?
local wndAlchemy
---@type IngredientWindow?
local wndIngredient

m.onOpenAlchemy = function(data)
    print('onOpenAlchemy', H.deepPrint(data))
    ctx.data = data
    I.UI.setMode(I.UI.MODE.Alchemy, { windows = { I.UI.WINDOW.Alchemy } })
end

m.openWindow = function()
    print('openWindow')
    m.closeWindow()
    wndAlchemy = AlchemyWindow:new()
    wndIngredient = IngredientWindow:new()

    if not ctx.data then
        ctx.data = {}
        core.sendGlobalEvent('TPA_AlchemyRedone_CollectInfo', { cellId = player.cell.id })
    end

    wndAlchemy:init(ctx)
    wndIngredient:init(ctx)
end

m.closeWindow = function()
    if wndAlchemy then
        wndAlchemy:destroy()
        wndAlchemy = nil
        ctx.data = nil
    end

    if wndIngredient then
        wndIngredient:destroy()
        wndIngredient = nil
        ctx.data = nil
    end
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

local function onFrame()
    for element in pairs(ctx.updateQueue) do
        element:update()
    end
    ctx.updateQueue = {}

    local mouseMoved
    if I.UI.getMode() ~= nil then
        if input.getMouseMoveX() ~= 0 or input.getMouseMoveY() ~= 0 then
            mouseMoved = true
        end
    end
end

I.UI.registerWindow(I.UI.WINDOW.Alchemy, openWindow, closeWindow)

return {
    engineHandlers = {
        onKeyRelease = onKeyRelease,
        onFrame = onFrame,
    },
    eventHandlers = {
        TPA_AlchemyRedone_Open = m.onOpenAlchemy
    },
}

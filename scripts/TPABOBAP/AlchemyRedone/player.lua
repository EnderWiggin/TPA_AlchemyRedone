---@omw-context player

local core = require('openmw.core')
local input = require('openmw.input')
local util = require('openmw.util')
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
    focusedScrollable = nil,
    data = nil,
}

---@type AlchemyWindow?
local wndAlchemy
---@type IngredientWindow?
local wndIngredient

m.onOpenAlchemy = function(data)
    ctx.data = data
    I.UI.setMode(I.UI.MODE.Alchemy, { windows = { I.UI.WINDOW.Alchemy } })
end

m.openWindow = function()
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
        onMouseWheel = onMouseWheel,
        onFrame = onFrame,
    },
    eventHandlers = {
        TPA_AlchemyRedone_Open = m.onOpenAlchemy
    },
}

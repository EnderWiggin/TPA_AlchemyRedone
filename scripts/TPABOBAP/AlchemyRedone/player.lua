---@omw-context player

local core = require('openmw.core')
local input = require('openmw.input')
local util = require('openmw.util')
local player = require('openmw.self')
local auxUi = require('openmw_aux.ui')

local T = require("openmw.types")
local I = require('openmw.interfaces')
local H = require('scripts.UIToolkit.helpers')
local AlchemyWindow = require('scripts.TPABOBAP.AlchemyRedone.ui.alchemy_window')
local IngredientWindow = require('scripts.TPABOBAP.AlchemyRedone.ui.ingredient_window')


local m = {
    ---@type AlchemyWindow?
    wndAlchemy = nil,
    ---@type IngredientWindow?
    wndIngredient = nil,
}

---@class AlchemyContext: WindowContext
---@field data {apparatus: LocalApparatusIds, sources: openmw.GObject[]}?
---@field selectIngredient fun(info: IngredientInfo)
---@field updateIngredients fun(deep: boolean)

---@type AlchemyContext
local ctx = {
    updateQueue = {},
    focusedScrollable = nil,
    data = nil,
    selectIngredient = function(info) m.selectIngredient(info) end,
    updateIngredients = function(deep) m.updateWnd(m.wndIngredient, deep) end,
}

m.onOpenAlchemy = function(data)
    if not ctx.data then
        ctx.data = data
    else
        ctx.data.apparatus = data.apparatus
        ctx.data.sources = data.sources
    end
    if m.wndIngredient then m.wndIngredient:updateData() end
    if m.wndAlchemy then m.wndAlchemy:updateData() end
    I.UI.setMode(I.UI.MODE.Alchemy, { windows = { I.UI.WINDOW.Alchemy } })
end

m.openWindow = function()
    m.closeWindow()
    m.wndAlchemy = AlchemyWindow:new()
    m.wndIngredient = IngredientWindow:new()

    if not ctx.data then
        ctx.data = {}
        core.sendGlobalEvent('TPA_AlchemyRedone_CollectInfo', { actor = player })
    end

    m.wndAlchemy:init(ctx)
    m.wndIngredient:init(ctx)
end

m.closeWindow = function()
    if m.wndAlchemy then
        m.wndAlchemy:destroy()
        m.wndAlchemy = nil
        ctx.data = nil
    end

    if m.wndIngredient then
        m.wndIngredient:destroy()
        m.wndIngredient = nil
        ctx.data = nil
    end

    if ctx.activeTooltip then
        auxUi.deepDestroy(ctx.activeTooltip)
        ctx.activeTooltip = nil
    end
end

m.selectIngredient = function(info)
    if m.wndAlchemy then
        if m.wndAlchemy:onSelectIngredient(info) then
            m.updateWnd(m.wndIngredient, true)
        end
    end
end

m.updateWnd = function(wnd, deep)
    if wnd then wnd:update(deep) end
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

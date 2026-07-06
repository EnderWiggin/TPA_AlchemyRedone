---@omw-context player

local ui = require('openmw.ui')
local util = require('openmw.util')
local auxUi = require('openmw_aux.ui')
local input = require('openmw.input')
local async = require('openmw.async')

local v2 = util.vector2
local H = require("scripts.TPABOBAP.UIToolkit.helpers")
local T = {
    Base = require("scripts.TPABOBAP.UIToolkit.templates.base"),
    Special = require("scripts.TPABOBAP.UIToolkit.templates.special"),
}
local C = require("scripts.TPABOBAP.UIToolkit.constants")

---@generic TItemData : BaseItemData
---@alias ColumnRenderer fun(item: TItemData, w: number, h:number):openmw.ui.Layout

---@generic TItemData : BaseItemData
---@alias Column {id: string, visible: boolean?, width: number?, textAlignH: any?, renderer: TItemData?}

local IngredientTable = {}

---@class BaseItemData
---@field id string

local scrollbarWidth = 24
local scrollStep = 2 --TODO: add config?
-- Add buffer to render slightly outside viewport for smoothness
local buffer = 1

local function getScrollbarWidth(scrollable)
    if not scrollable then
        return 0
    elseif scrollable.layout.userData.canScroll then
        return scrollbarWidth
    else
        return 0
    end
end

---@param columns Column[]
---@param state table
local function setColumnWidths(columns, state)
    local contentWidth = math.floor(math.max(0, state.currentSize.x - scrollbarWidth))
    local widths = {}
    local fixedWidth = 0
    local flexCount = 0

    for i, col in ipairs(columns) do
        if col.visible ~= false then
            if col.width then
                widths[i] = col.width
                fixedWidth = fixedWidth + col.width
            else
                flexCount = flexCount + 1
            end
        end
    end

    local remainingWidth = math.max(0, contentWidth - fixedWidth)
    local flexWidth = flexCount > 0 and math.floor(remainingWidth / flexCount) or 0

    for i, col in ipairs(columns) do
        if col.visible ~= false and not col.width then
            widths[i] = flexWidth
        end
    end

    state.columnWidths = widths
end

---@param a BaseItemData
---@param b BaseItemData
---@return boolean
local function defaultComparator(a, b)
    return a.id < b.id
end

---@class IngredientTableOpts
---@field columns Column[]?
---@field data BaseItemData[]?
---@field size openmw.util.Vector2?
---@field rowHeight number?
---@field parentWindow AlchemyWindow
---@field comparator? fun(a:any, b:any):boolean

---@generic TItemData : BaseItemData
---@param ctx WindowContext
---@param opts IngredientTableOpts<TItemData>
IngredientTable.create = function(ctx, opts)
    ---@type Column[]
    local columns = opts.columns or {}
    local dataRows = opts.data or {}
    local size = opts.size or v2(400, 300)
    local rowHeight = opts.rowHeight or 30
    local onRowUse = opts.onRowUse or opts.onRowClick
    local onKBMRowUse = opts.onKBMRowUse or opts.onKBMRowClick
    local tooltipFn = opts.tooltipFn
    local comparator = opts.comparator or defaultComparator

    local state = {
        ---@type BaseItemData[]
        sortedRows = {}, -- List of items after sorting
        columns = columns,
        columnWidths = {},
        currentSize = size,
        filters = {},
        parentWindow = opts.parentWindow,
        hadMouseMoveThisFrame = false,
        rowCache = {} -- Stores generated row layouts by item ID or index
    }

    setColumnWidths(columns, state)

    for _, item in ipairs(dataRows) do
        table.insert(state.sortedRows, item)
    end

    local scrollable
    local updateRows
    local function sortRows()
        table.sort(state.sortedRows, comparator)
    end

    local function resetScroll()
        if scrollable and scrollable.layout.content[1] then
            scrollable.layout.content[1].props.position = util.vector2(0, 0)
        end
    end

    local function getContentWidth()
        return math.floor(math.max(0, state.currentSize.x) - getScrollbarWidth(scrollable))
    end

    local function getViewportSlotPosAtOffset(offsetX, offsetY)
        if not scrollable then
            return nil
        end

        local viewHeight = state.currentSize.y
        local viewY = offsetY
        if viewY < 0 or viewY >= viewHeight then
            return nil
        end

        local contentWidth = getContentWidth()
        if offsetX < 0 or offsetX >= contentWidth then
            return nil
        end

        local scrollPos = scrollable.layout.userData.getScrollPos() or 0
        return util.vector2(0, math.floor((viewY + scrollPos) / rowHeight) * rowHeight - scrollPos)
    end

    local function viewportSlotEquals(a, b)
        return a ~= nil and b ~= nil
            and math.abs(a.x - b.x) <= 0.1
            and math.abs(a.y - b.y) <= 0.1
    end

    local function createContent(row)
        local cells = ui.content {}

        local totalW = 0
        for cIdx, col in ipairs(columns) do
            local w = state.columnWidths[cIdx] or 0
            local cellContent

            if col.renderer then
                cellContent = col.renderer(row, w, rowHeight)
            else
                local val = row[col.id]
                if type(val) == 'function' then
                    val = val()
                end
                if type(val) == 'number' then val = H.addSeparators(val) end
                local textStr = val ~= nil and tostring(val) or ""
                if textStr == "0" or textStr == "" then textStr = "-" end
                cellContent = {
                    name = col.id,
                    template = T.Base.textNormal,
                    props = {
                        text = textStr,
                        size = v2(w, rowHeight),
                        textAlignH = col.textAlignH or ui.ALIGNMENT.Start,
                        textAlignV = ui.ALIGNMENT.Center,
                        autoSize = false,
                    },
                    userData = {
                        colorable = true,
                    }
                }
            end
            cellContent.props.position = util.vector2(totalW, 0)
            totalW = totalW + w

            cells:add(cellContent)
        end

        return cells
    end

    local function getVisibleIndexRange()
        local effectiveRowHeight = rowHeight
        local viewHeight = state.currentSize.y
        local contentLayer = scrollable.layout.content[1]

        -- Virtualization mathematics
        -- contentLayer.props.position.y is negative when scrolled down
        local scrollY = -contentLayer.props.position.y
        local startRowIndex = math.floor(scrollY / effectiveRowHeight)
        local visibleRowCount = math.ceil(viewHeight / effectiveRowHeight)

        -- Calculate index range
        local indexFrom = math.max(1, startRowIndex + 1 - buffer)
        local indexTo = math.min(#state.sortedRows, startRowIndex + visibleRowCount + buffer)

        return indexFrom, indexTo
    end

    local function getScrollYToFocusRow(row, bottom)
        local effectiveRowHeight = rowHeight
        local y
        if bottom then
            local viewHeight = state.currentSize.y
            local visibleRowCount = math.floor(viewHeight / effectiveRowHeight)
            y = -effectiveRowHeight * (row - visibleRowCount)
        else
            y = -effectiveRowHeight * (row - 1)
        end
        return util.clamp(y, -scrollable.layout.userData.scrollLimit, 0)
    end

    local function renderVisibleRows(forceRedraw)
        if not scrollable then return end

        local contentLayer = scrollable.layout.content[1]
        contentLayer.type = ui.TYPE.Widget
        contentLayer.props.autoSize = nil
        local contentWidth = getContentWidth()
        scrollable.layout.userData.setScrollStep(rowHeight * scrollStep)

        local indexFrom, indexTo = getVisibleIndexRange()

        local pendingFocusRestorePos = nil
        local restoredFocus = false
        local hoveredViewportPos = nil
        local scrollPos = scrollable.layout.userData.getScrollPos() or 0
        --local focused = state.parentWindow:isFocused()
        local focused = true --we have only 1 active window
        if focused and not scrollable.layout.userData.isDraggingScrollBar then
            hoveredViewportPos = state.isPointerOverContent and state.lastPointerRowPos or nil
            if state.lastUsedRowPos then
                pendingFocusRestorePos = state.lastUsedRowPos
                hoveredViewportPos = pendingFocusRestorePos
                state.lastUsedRowPos = nil
            end
        end

        local newRowElements = {}

        local currentContent = contentLayer.content
        local k = 1

        for i = indexFrom, indexTo do
            local row = state.sortedRows[i]
            if row then
                local cacheKey = row.id

                local anyChanged = false
                local active = false
                local disabled = false
                if row.activeFn then
                    active = row.activeFn(row)
                end
                if row.disabledFn then
                    disabled = row.disabledFn(row)
                end
                if (not state.rowCache[cacheKey]) or forceRedraw then
                    local widgetContent
                    if state.rowCache[cacheKey] then
                        auxUi.deepDestroy(state.rowCache[cacheKey])
                    end
                    widgetContent = createContent(row)

                    local function getCurrentRow()
                        local rowWidget = state.rowCache[cacheKey]
                        if rowWidget and rowWidget.layout and rowWidget.layout.userData then
                            return rowWidget.layout.userData.row
                        end
                        return row
                    end

                    state.rowCache[cacheKey] = T.Special.interactive({
                        canClick = function()
                            for _, button in pairs(input.CONTROLLER_BUTTON) do
                                if input.isControllerButtonPressed(button) then
                                    return false
                                end
                            end
                            return true
                        end,
                        onClick = function()
                            local currentRow = getCurrentRow()
                            if onRowUse then
                                return onRowUse(currentRow, state.rowCache[cacheKey])
                            end
                        end,
                        onMouseMove = function()
                            state.hadMouseMoveThisFrame = true
                            if not scrollable.layout.userData.isDraggingScrollBar then
                                if state.rowCache[cacheKey] then
                                    local currentScrollPos = scrollable.layout.userData.getScrollPos() or 0
                                    state.isPointerOverContent = true
                                    state.lastPointerRowPos = util.vector2(
                                        state.rowCache[cacheKey].layout.props.position.x,
                                        state.rowCache[cacheKey].layout.props.position.y - currentScrollPos
                                    )
                                end
                            end
                        end,
                        tooltipFn = function()
                            local currentRow = getCurrentRow()
                            if tooltipFn then
                                return tooltipFn(row)
                            end
                            return T.Special.lineTooltip(currentRow.id, currentRow.id)
                        end,
                        name = row.id or 'item',
                    }, {
                        props = {
                            size = v2(contentWidth, rowHeight),
                            position = v2(0, 0),
                        },
                        content = widgetContent,
                        userData = {
                            row = row,
                            onKBMRowUse = function()
                                local currentRow = getCurrentRow()
                                if onKBMRowUse then
                                    return onKBMRowUse(currentRow, state.rowCache[cacheKey])
                                elseif onRowUse then
                                    return onRowUse(currentRow, state.rowCache[cacheKey])
                                end
                            end,
                            onRowUse = function()
                                local currentRow = getCurrentRow()
                                if onRowUse then
                                    return onRowUse(currentRow, state.rowCache[cacheKey])
                                end
                            end,
                            onKBMRowClick = function()
                                local currentRow = getCurrentRow()
                                if onKBMRowUse then
                                    return onKBMRowUse(currentRow, state.rowCache[cacheKey])
                                elseif onRowUse then
                                    return onRowUse(currentRow, state.rowCache[cacheKey])
                                end
                            end,
                            onRowClick = function()
                                local currentRow = getCurrentRow()
                                if onRowUse then
                                    return onRowUse(currentRow, state.rowCache[cacheKey])
                                end
                            end,
                            active = active,
                            disabled = disabled,
                        }
                    }, ctx)
                    H.setInteractiveColor(state.rowCache[cacheKey].layout)
                else
                    local totalW = 0
                    for cIdx, col in ipairs(columns) do
                        local w = state.columnWidths[cIdx] or 0
                        local rowWidget = state.rowCache[cacheKey]
                        local cellContent = rowWidget.layout.content[cIdx]

                        if cellContent then
                            if col.renderer then
                                local newCellContent = col.renderer(row, w, rowHeight)
                                if cellContent.userData and newCellContent.userData and not H.mapEquals(cellContent.userData, newCellContent.userData) then
                                    rowWidget.layout.content[cIdx] = newCellContent
                                    cellContent = newCellContent
                                    anyChanged = true
                                end
                            else
                                if cellContent.props.text then
                                    local val = row[col.id]
                                    if type(val) == 'function' then
                                        val = val()
                                    end
                                    if type(val) == 'number' then val = H.addSeparators(val) end
                                    local textStr = val ~= nil and tostring(val) or ""
                                    if textStr == "0" or textStr == "" then textStr = "-" end
                                    if textStr ~= cellContent.props.text then
                                        cellContent.props.text = textStr
                                        anyChanged = true
                                    end
                                end
                            end
                            cellContent.props.size = v2(w, rowHeight)
                            cellContent.props.position = v2(totalW, 0)
                        end
                        totalW = totalW + w
                    end
                end

                local rowWidget = state.rowCache[cacheKey]
                rowWidget.layout.userData.row = row

                local targetX = 0
                local targetY = (i - 1) * rowHeight

                local targetW = contentWidth
                local targetH = rowHeight

                local targetViewportPos = v2(targetX, targetY - scrollPos)

                local isHoveredRow = viewportSlotEquals(hoveredViewportPos, targetViewportPos)
                if pendingFocusRestorePos ~= nil and isHoveredRow and not restoredFocus then
                    restoredFocus = true
                    ctx.focusedInteractive = rowWidget
                end

                if rowWidget.layout.userData.hovering ~= isHoveredRow then
                    rowWidget.layout.userData.hovering = isHoveredRow
                    anyChanged = true
                end

                if math.abs(rowWidget.layout.props.size.x - targetW) > 0.1
                    or math.abs(rowWidget.layout.props.position.y - targetY) > 0.1
                    or math.abs(rowWidget.layout.props.position.x - targetX) > 0.1
                    or rowWidget.layout.userData.active ~= active
                    or rowWidget.layout.userData.disabled ~= disabled
                    or anyChanged then
                    rowWidget.layout.props.size = util.vector2(targetW, targetH)
                    rowWidget.layout.props.position = util.vector2(targetX, targetY)
                    rowWidget.layout.userData.active = active
                    rowWidget.layout.userData.disabled = disabled

                    H.setInteractiveColor(rowWidget.layout)

                    rowWidget:update()
                end

                if currentContent[k] ~= rowWidget then
                    currentContent[k] = rowWidget
                end
                k = k + 1
            end
        end

        while k <= #currentContent do
            currentContent[k] = nil
            k = k + 1
        end

        for i = 1, #currentContent do
            newRowElements[i] = currentContent[i]
        end

        contentLayer.content = ui.content(newRowElements)
        scrollable:update()
    end

    updateRows = function(forceRedraw)
        if not scrollable then return end

        local viewHeight = state.currentSize.y
        local contentWidth = getContentWidth()

        local totalHeight = math.floor(math.max(#state.sortedRows * rowHeight, viewHeight))

        renderVisibleRows(forceRedraw)

        scrollable.layout.userData.update(
            util.vector2(state.currentSize.x, viewHeight),
            util.vector2(state.currentSize.x - getScrollbarWidth(scrollable), totalHeight)
        )
    end

    local dummyContent = ui.content({})
    local totalY = #state.sortedRows * rowHeight
    local flexSize = util.vector2(getContentWidth(), totalY)

    scrollable = T.Base.scrollable(
        v2(size.x, size.y),
        dummyContent,
        flexSize,
        0,
        0,
        rowHeight * 2,
        false,
        function(e)
            ctx.focusedScrollable = e
        end,
        function()
            ctx.focusedScrollable = nil
        end,
        0,
        'ingredientTable_Scroll'
    )

    local originalOnScroll = scrollable.layout.userData.onScroll
    ---@diagnostic disable-next-line: duplicate-set-field
    scrollable.layout.userData.onScroll = function()
        if type(originalOnScroll) == 'function' then
            originalOnScroll()
        end
        renderVisibleRows()
    end

    sortRows()
    updateRows()

    local wrapper = ui.create {
        name = 'itemTable',
        type = ui.TYPE.Flex,
        props = {
            size = size,
        },
        content = ui.content {
            scrollable
        },
        userData = {},
        events = {},
    }

    wrapper.layout.userData.resize = function(newSize)
        state.currentSize = newSize
        setColumnWidths(columns, state)
        wrapper.layout.props.size = newSize
        updateRows()
        wrapper:update()
    end

    wrapper.layout.userData.setFilter = function(filterId, filterFn)
        state.filters[filterId] = filterFn
    end

    wrapper.layout.userData.setViewMode = function(mode)
        if state.viewMode == mode then return end
        state.viewMode = mode
        -- Clear cache
        for i = 1, #state.rowCache do
            auxUi.deepDestroy(state.rowCache[i])
        end
        state.rowCache = {}

        updateRows()
        wrapper:update()
    end

    wrapper.layout.userData.resetScroll = resetScroll

    wrapper.layout.userData.getViewportSlotPosAtOffset = getViewportSlotPosAtOffset

    wrapper.layout.events.mouseMove = async:callback(function(e)
        state.hadMouseMoveThisFrame = true
        if not scrollable.layout.userData.isDraggingScrollBar then
            state.lastPointerRowPos = getViewportSlotPosAtOffset(e.offset.x, e.offset.y)
            state.isPointerOverContent = state.lastPointerRowPos ~= nil
        end
        return true
    end)

    local function getFilteredRows(excludedFilterId)
        local filteredRows = {}
        for i = 1, #dataRows do
            local row = dataRows[i]
            local include = true
            for filterId, filterFn in pairs(state.filters) do
                if filterId ~= excludedFilterId and not filterFn(row) then
                    include = false
                    break
                end
            end
            if include then
                table.insert(filteredRows, row)
            end
        end

        return filteredRows
    end

    wrapper.layout.userData.refresh = function(forceRedraw)
        -- Re-apply filters
        state.sortedRows = getFilteredRows()

        sortRows()
        updateRows(forceRedraw)
    end

    wrapper.layout.userData.updateData = function(newDataRows)
        -- Create a map of old items by ID for quick lookup
        local oldItemsMap = {}
        for i = 1, #dataRows do
            local row = dataRows[i]
            local itemId = row.id
            if itemId then
                oldItemsMap[itemId] = row
            end
        end

        -- Create a map of new items by ID
        local newItemsMap = {}
        for i = 1, #newDataRows do
            local row = newDataRows[i]
            local itemId = row.id
            if itemId then
                newItemsMap[itemId] = row
            end
        end

        -- Remove cache entries for items no longer present
        for itemId, row in pairs(oldItemsMap) do
            if not newItemsMap[itemId] and state.rowCache[row.id] then
                auxUi.deepDestroy(state.rowCache[row.id])
                state.rowCache[row.id] = nil
            end
        end

        -- Update the dataRows reference
        dataRows = newDataRows

        wrapper.layout.userData.refresh()
    end

    wrapper.layout.userData.getState = function()
        return state
    end

    wrapper.layout.userData.getFilteredRows = getFilteredRows

    wrapper.layout.userData.setColumns = function(newColumns, deferRedraw)
        if not newColumns or H.tableEquals(columns, newColumns) then
            return
        end

        columns = newColumns
        state.columns = newColumns
        setColumnWidths(columns, state)

        for key, rowWidget in pairs(state.rowCache) do
            auxUi.deepDestroy(rowWidget)
            state.rowCache[key] = nil
        end

        if deferRedraw then
            wrapper:update()
            return
        end

        sortRows()
        updateRows(true)
        wrapper:update()
    end

    -- Use this after editing state.columns directly
    wrapper.layout.userData.redrawColumns = function()
        setColumnWidths(state.columns, state)
        updateRows(true)
        wrapper:update()
    end

    local function scrollTo(row, bottom)
        if not scrollable or not scrollable.layout then return end
        local layout = scrollable.layout
        local pos = layout.content[1].props.position
        local y = getScrollYToFocusRow(row, bottom)
        layout.content[1].props.position = util.vector2(pos.x, y)
        layout.userData.onScroll()
    end

    local function findHoveredRowIndices()
        local id = nil
        local cIdx = nil
        local content = scrollable.layout.content[1].content
        for i = 1, #content do
            local element = content[i]
            if ctx.focusedInteractive == element then
                cIdx = i
                id = element.layout.userData.row.id
                break
            end
        end

        if not id or not cIdx then return nil, nil end

        local rIdx
        for i = 1, #state.sortedRows do
            if state.sortedRows[i].id == id then
                rIdx = i
                break
            end
        end

        return id, rIdx, cIdx
    end

    local function findContendIdxById(id)
        local content = scrollable.layout.content[1].content
        for i = 1, #content do
            local layout = H.toLayout(content[i])
            if layout and layout.userData and layout.userData.row.id == id then
                return i
            end
        end
        return nil
    end

    local function setHoveredRow(n)
        local content = scrollable.layout.content[1].content
        ---@type openmw.ui.Element
        local element = content[n]
        ctx.focusedInteractiveDelayed = false

        if ctx.focusedInteractive and ctx.focusedInteractive.layout then
            ctx.focusedInteractive.layout.userData.hovering = false
            H.setInteractiveColor(ctx.focusedInteractive)
            ctx.updateQueue[ctx.focusedInteractive] = true
        end

        if element and element.layout then
            local layout = H.toLayout(element)
            ctx.focusedInteractiveDelayed = element
            layout.userData.hovering = true
            H.setInteractiveColor(element)
            ctx.updateQueue[element] = true

            ---@type TipPositioning
            local props
            local pos = wrapper.layout.userData.controllerTooltipPos
            if wrapper.layout.userData.controllerTooltipPos then
                props = {
                    position = pos,
                    anchor = v2(0, 0.5),
                }
            else
                props = {
                    anchor = v2(1, 0.5),
                    relativePosition = v2(0.95, 0.5),
                }
            end

            local currentScrollPos = scrollable.layout.userData.getScrollPos() or 0
            state.isPointerOverContent = true
            state.lastPointerRowPos = util.vector2(
                element.layout.props.position.x,
                element.layout.props.position.y - currentScrollPos
            )

            local tip = ctx.setTooltip(layout.name, function() return tooltipFn(layout.userData.row) end, props)
            tip:update()
        end
    end

    ---@param d integer?
    local function highlightNextItem(d)
        local rows = state.sortedRows
        d = d or math.floor(state.currentSize.y / rowHeight)
        local id, rIdx, cIdx = findHoveredRowIndices()
        local from, to = getVisibleIndexRange()
        local tIdx = from
        if rIdx then
            if rIdx == #rows then
                tIdx = 1
            else
                tIdx = rIdx + d
            end
        end
        tIdx = util.clamp(tIdx, 1, #rows)
        local tId = rows[tIdx].id

        if tIdx < from or tIdx >= to - buffer then
            scrollTo(tIdx)
        end
        local n = findContendIdxById(tId)

        if n then
            setHoveredRow(n)
        end
    end

    local function highlightPrevItem(d)
        local rows = state.sortedRows
        d = d or math.floor(state.currentSize.y / rowHeight)
        local id, rIdx, cIdx = findHoveredRowIndices()
        local from, to = getVisibleIndexRange()

        local tIdx = to - buffer
        if rIdx then
            if rIdx == 1 then
                tIdx = #rows
            else
                tIdx = rIdx - d
            end
        end
        tIdx = util.clamp(tIdx, 1, #rows)
        local tId = rows[tIdx].id

        if tIdx < from + buffer or tIdx >= to - buffer then
            scrollTo(tIdx, true)
        end
        local n = findContendIdxById(tId)

        if n then
            setHoveredRow(n)
        end
    end

    wrapper.layout.userData.findContendIdxById = findContendIdxById
    wrapper.layout.userData.setHoveredRow = setHoveredRow
    wrapper.layout.userData.highlightNextItem = highlightNextItem
    wrapper.layout.userData.highlightPrevItem = highlightPrevItem

    ---@return openmw.ui.Element?
    wrapper.layout.userData.getHighlightedRow = function()
        local _, _, cIdx = findHoveredRowIndices()
        local content = scrollable.layout.content[1].content

        if cIdx then return content[cIdx] end
        return nil
    end

    wrapper.layout.userData.invalidateCache = function(id)
        state.rowCache[id] = nil
    end

    return wrapper
end


return IngredientTable

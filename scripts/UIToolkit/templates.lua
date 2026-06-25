---@omw-context player
local ui = require("openmw.ui")
local util = require("openmw.util")
local async = require('openmw.async')
local ambient = require('openmw.ambient')
local auxUi = require('openmw_aux.ui')
local I = require("openmw.interfaces")

local v2 = util.vector2
local omwConstants = require('scripts.omw.mwui.constants')
local constants = require('scripts.UIToolkit.constants')
local helpers = require('scripts.UIToolkit.helpers')

local Templates = {}

--TODO: add option to enable Interface reimagined support
local intRe = true --configPlayer.modIntegration.b_InterfaceReimagined

local HEADER_HEIGHT = 20
local SCROLL_BAR_OUTER_WIDTH = 16
local SCROLL_BAR_INNER_WIDTH = 14
local BORDER_THICKNESS = omwConstants.border
local BORDER_THICKNESS_THICK = omwConstants.thickBorder

Templates.TEXT_SIZE = omwConstants.textNormalSize --TODO: add option to customize font size?
Templates.TEXTURES = {}
Templates.createTexture = function(path, size, offset)
    size = size or util.vector2(0, 0)
    offset = offset or util.vector2(0, 0)
    if Templates.TEXTURES[path]
        and Templates.TEXTURES[path][size.x] and Templates.TEXTURES[path][size.x][size.y]
        and Templates.TEXTURES[path][size.x][size.y][offset.x] and Templates.TEXTURES[path][size.x][size.y][offset.x][offset.y] then
        return Templates.TEXTURES[path][size.x][size.y][offset.x][offset.y]
    else
        local tex = ui.texture { path = path, size = size, offset = offset }
        Templates.TEXTURES[path] = Templates.TEXTURES[path] or {}
        Templates.TEXTURES[path][size.x] = Templates.TEXTURES[path][size.x] or {}
        Templates.TEXTURES[path][size.x][size.y] = Templates.TEXTURES[path][size.x][size.y] or {}
        Templates.TEXTURES[path][size.x][size.y][offset.x] = Templates.TEXTURES[path][size.x][size.y][offset.x] or {}
        Templates.TEXTURES[path][size.x][size.y][offset.x][offset.y] = tex
        return tex
    end
end

local headerTextures = {
    [1] = Templates.createTexture('textures/menu_head_block_top_left_corner.dds'),
    [2] = Templates.createTexture('textures/menu_head_block_top.dds'),
    [3] = Templates.createTexture('textures/menu_head_block_top_right_corner.dds'),
    [4] = Templates.createTexture('textures/menu_head_block_left.dds'),
    [5] = Templates.createTexture('textures/menu_head_block_middle.dds'),
    [6] = Templates.createTexture('textures/menu_head_block_right.dds'),
    [7] = Templates.createTexture('textures/menu_head_block_bottom_left_corner.dds'),
    [8] = Templates.createTexture('textures/menu_head_block_bottom.dds'),
    [9] = Templates.createTexture('textures/menu_head_block_bottom_right_corner.dds'),
}

local function headerImage(i, tile, size)
    return {
        type = ui.TYPE.Image,
        props = {
            resource = headerTextures[i],
            size = size or v2(0, 0),
            tileH = tile,
            tileV = false,
        },
        external = {
            grow = 1,
            stretch = 1,
        }
    }
end

local headerSection = {
    type = ui.TYPE.Flex,
    props = {
        horizontal = true,
    },
    external = {
        grow = 1,
        stretch = 1,
    },
    content = ui.content {
        {
            type = ui.TYPE.Flex,
            props = {
                autoSize = false,
                size = v2(2, HEADER_HEIGHT),
            },
            content = ui.content {
                headerImage(1, false, v2(2, 2)),
                headerImage(4, false, v2(2, 16)),
                headerImage(7, false, v2(2, 2)),
            }
        },
        {
            type = ui.TYPE.Flex,
            props = {
                autoSize = false,
                size = v2(0, HEADER_HEIGHT),
            },
            content = ui.content {
                headerImage(2, true, v2(0, 2)),
                headerImage(5, true, v2(0, 16)),
                headerImage(8, true, v2(0, 2)),
            },
            external = {
                grow = 1,
                stretch = 1,
            }
        },
        {
            type = ui.TYPE.Flex,
            props = {
                autoSize = false,
                size = v2(2, HEADER_HEIGHT),
            },
            content = ui.content {
                headerImage(3, false, v2(2, 2)),
                headerImage(6, false, v2(2, 16)),
                headerImage(9, false, v2(2, 2)),
            }
        }
    }
}

local emptyHeaderSection = {
    props = {
        size = v2(0, 20),
    },
    external = {
        grow = 1,
        stretch = 1,
    }
}

Templates.padding = function(size)
    size = util.vector2(1, 1) * size
    return {
        type = ui.TYPE.Container,
        content = ui.content {
            {
                props = {
                    size = size,
                },
            },
            {
                external = { slot = true },
                props = {
                    position = size,
                    relativeSize = util.vector2(1, 1),
                },
            },
            {
                props = {
                    position = size,
                    relativePosition = util.vector2(1, 1),
                    size = size,
                },
            },
        }
    }
end

local buttonBorderSize = 4
local borderSideParts = {
    left = v2(0, 0),
    right = v2(1, 0),
    top = v2(0, 0),
    bottom = v2(0, 1),
}
local borderCornerParts = {
    top_left = v2(0, 0),
    top_right = v2(1, 0),
    bottom_left = v2(0, 1),
    bottom_right = v2(1, 1),
}

local borderSidePattern = 'textures/menu_%s_border_%s.dds'
local borderCornerPattern = 'textures/menu_%s_border_%s_corner.dds'

local borderResources = {}
local borderPieces = {}

for _, thickness in ipairs { 'thin', 'thick' } do
    borderResources[thickness] = {}
    for k in pairs(borderSideParts) do
        borderResources[thickness][k] = ui.texture { path = borderSidePattern:format(thickness, k) }
    end
    for k in pairs(borderCornerParts) do
        borderResources[thickness][k] = ui.texture { path = borderCornerPattern:format(thickness, k) }
    end

    borderPieces[thickness] = {}
    for k in pairs(borderSideParts) do
        local horizontal = k == 'top' or k == 'bottom'
        borderPieces[thickness][k] = {
            type = ui.TYPE.Image,
            props = {
                resource = borderResources[thickness][k],
                tileH = horizontal,
                tileV = not horizontal,
            },
        }
    end
    for k in pairs(borderCornerParts) do
        borderPieces[thickness][k] = {
            type = ui.TYPE.Image,
            props = {
                resource = borderResources[thickness][k],
            },
        }
    end
end

local function borderTemplates(thickness)
    local borderSize = (thickness == 'thin') and omwConstants.border or omwConstants.thickBorder
    local borderV = v2(1, 1) * borderSize
    local result = {}

    result.bordersDraggable = {
        content = ui.content {},
    }
    for k, v in pairs(borderSideParts) do
        local horizontal = k == 'top' or k == 'bottom'
        local direction = horizontal and v2(1, 0) or v2(0, 1)
        result.bordersDraggable.content:add {
            template = borderPieces[thickness][k],
            props = {
                position = (direction - v) * borderSize,
                relativePosition = v,
                size = (v2(1, 1) - direction * 3) * borderSize,
                relativeSize = direction,
            },
            userData = {
                dragType = k
            }
        }
    end
    for k, v in pairs(borderCornerParts) do
        result.bordersDraggable.content:add {
            template = borderPieces[thickness][k],
            props = {
                position = -v * borderSize,
                relativePosition = v,
                size = borderV,
            },
            userData = {
                dragType = k
            }
        }
    end
    result.bordersDraggable.content:add {
        external = { slot = true },
        props = {
            position = borderV,
            size = borderV * -2,
            relativeSize = v2(1, 1),
        }
    }

    return result
end

Templates.bordersDraggable = borderTemplates('thin').bordersDraggable
Templates.bordersDraggableThick = borderTemplates('thick').bordersDraggable
Templates.intervalH = function(size)
    return {
        props = {
            size = util.vector2(size, 0),
        },
    }
end

Templates.intervalV = function(size)
    return {
        props = {
            size = util.vector2(0, size),
        },
    }
end

Templates.textNormal = helpers.deepCopy(I.MWUI.templates.textNormal)
Templates.textHeader = helpers.deepCopy(I.MWUI.templates.textHeader)
Templates.textParagraph = helpers.deepCopy(I.MWUI.templates.textParagraph)
Templates.textEditLine = helpers.deepCopy(I.MWUI.templates.textEditLine)
Templates.textNormal.props.textColor = constants.Colors.DEFAULT
Templates.textHeader.props.textColor = constants.Colors.DEFAULT_LIGHT
Templates.textParagraph.props.textColor = constants.Colors.DEFAULT
Templates.textEditLine.props.textColor = constants.Colors.DEFAULT
Templates.textNormal.props.textSize = Templates.TEXT_SIZE
Templates.textHeader.props.textSize = Templates.TEXT_SIZE
Templates.textParagraph.props.textSize = Templates.TEXT_SIZE
Templates.textEditLine.props.textSize = Templates.TEXT_SIZE
Templates.textEditLine.props.size = v2(0, 0)

local dragTypePointers = {
    [constants.DragType.ResizeL] = 'hresize',
    [constants.DragType.ResizeR] = 'hresize',
    [constants.DragType.ResizeT] = 'vresize',
    [constants.DragType.ResizeB] = 'vresize',
    [constants.DragType.ResizeTL] = 'dresize',
    [constants.DragType.ResizeTR] = 'dresize2',
    [constants.DragType.ResizeBL] = 'dresize2',
    [constants.DragType.ResizeBR] = 'dresize',
    [constants.DragType.Move] = 'arrow',
}

local function makeDraggable(borderTemplate, onDragTypeChanged)
    local template = auxUi.deepLayoutCopy(borderTemplate)
    local content = template.content

    local function setDragType(index)
        local borderPiece = content[index]
        if borderPiece.userData and borderPiece.userData.dragType then
            borderPiece.props.pointer = dragTypePointers[borderPiece.userData.dragType] or 'arrow'
            borderPiece.events = {
                focusGain = async:callback(function(e, layout)
                    if onDragTypeChanged then
                        onDragTypeChanged(layout.userData.dragType)
                    end
                end),
                focusLoss = async:callback(function(e, layout)
                    if onDragTypeChanged then
                        onDragTypeChanged(nil)
                    end
                end),
            }
        end
    end

    for i = 1, 8 do
        setDragType(i)
    end

    return template
end

---@alias WindowOpts {draggable:boolean?, onDrag:function?}

---@param title string
---@param content openmw.ui.Content
---@param ctx table
---@param opts WindowOpts?
Templates.window = function(title, content, ctx, opts)
    local draggable = opts and opts.draggable
    local onDrag = opts and opts.onDrag

    local baseTemplate = I.MWUI.templates.bordersThick
    local userData = {}
    if draggable then
        baseTemplate = makeDraggable(Templates.bordersDraggableThick, function(dragType)
            userData.dragType = dragType
        end)
    end
    local window = {
        layer = 'Windows',
        template = baseTemplate,
        props = {},
        content = ui.content {
            {
                name = 'background',
                type = ui.TYPE.Image,
                props = {
                    resource = Templates.createTexture('transparent'),
                    color = constants.Colors.BACKGROUND,
                    relativeSize = util.vector2(1, 1),
                }
            },
            {
                name = 'foreground',
                type = ui.TYPE.Flex,
                props = {
                    relativeSize = util.vector2(1, 1),
                },
                content = ui.content {
                    {
                        name = 'header',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                        },
                        external = {
                            stretch = 1,
                        },
                        content = ui.content {
                            intRe and emptyHeaderSection or headerSection,
                            Templates.intervalH(8),
                            {
                                name = 'title',
                                template = intRe and Templates.textHeader or Templates.textNormal,
                                props = {
                                    text = title,
                                }
                            },
                            Templates.intervalH(8),
                            intRe and emptyHeaderSection or headerSection,
                        },
                        events = {
                            focusGain = async:callback(function()
                                if draggable then
                                    userData.dragType = constants.DragType.Move
                                end
                            end),
                            focusLoss = async:callback(function()
                                if draggable then
                                    userData.dragType = nil
                                end
                            end),
                        }
                    },
                    {
                        name = 'body',
                        template = not intRe and baseTemplate,
                        external = {
                            grow = 1,
                            stretch = 1,
                        },
                        content = ui.content(content),
                    },
                }
            }
        },
        events = {},
        userData = userData,
    }

    window = ui.create(window)

    if draggable then
        local minWidth = 200
        local minHeight = 60
        userData.dragging = false
        userData.dragStartAbs = nil
        userData.dragStartSize = nil
        userData.dragStartPos = nil

        window.layout.events = {
            mousePress = async:callback(function(e, layout)
                if e.button ~= 1 then return end
                if userData.dragType == nil then return end
                userData.dragging = true
                userData.dragStartAbs = e.position
                userData.dragStartSize = layout.props.size
                userData.dragStartPos = layout.props.position
                if userData.dragType == constants.DragType.Move then
                    ambient.playSound('menu click')
                end
            end),
            mouseMove = async:callback(function(e, layout)
                userData.hadMouseMoveThisFrame = true
                ctx.lastCursorPos = e.position
                if ctx.cursorAttachedIcon then
                    ctx.cursorAttachedIcon.layout.props.visible = true
                    ctx.cursorAttachedIcon.layout.props.position = e.position
                    ctx.cursorAttachedIcon:update()
                end
                if userData.dragging and userData.dragStartAbs and userData.dragStartSize and userData.dragStartPos then
                    local delta = e.position - userData.dragStartAbs
                    local layerSize = ui.layers[ui.layers.indexOf('Windows')].size
                    local newSize = userData.dragStartSize
                    local newPos = userData.dragStartPos
                    local dX, dY, w, h

                    -- Horizontal resizing
                    if userData.dragType == constants.DragType.ResizeL or userData.dragType == constants.DragType.ResizeTL or userData.dragType == constants.DragType.ResizeBL then
                        local maxDeltaX = userData.dragStartSize.x - minWidth
                        dX = util.clamp(delta.x, -userData.dragStartPos.x, maxDeltaX)
                        newSize = util.vector2(userData.dragStartSize.x - dX, newSize.y)
                        newPos = util.vector2(userData.dragStartPos.x + dX, newPos.y)
                    elseif userData.dragType == constants.DragType.ResizeR or userData.dragType == constants.DragType.ResizeTR or userData.dragType == constants.DragType.ResizeBR then
                        local maxWidth = layerSize.x - userData.dragStartPos.x
                        w = util.clamp(userData.dragStartSize.x + delta.x, minWidth, maxWidth)
                        newSize = util.vector2(w, newSize.y)
                    end

                    -- Vertical resizing
                    if userData.dragType == constants.DragType.ResizeT or userData.dragType == constants.DragType.ResizeTL or userData.dragType == constants.DragType.ResizeTR then
                        local maxDeltaY = userData.dragStartSize.y - minHeight
                        dY = util.clamp(delta.y, -userData.dragStartPos.y, maxDeltaY)
                        newSize = util.vector2(newSize.x, userData.dragStartSize.y - dY)
                        newPos = util.vector2(newPos.x, userData.dragStartPos.y + dY)
                    elseif userData.dragType == constants.DragType.ResizeB or userData.dragType == constants.DragType.ResizeBL or userData.dragType == constants.DragType.ResizeBR then
                        local maxHeight = layerSize.y - userData.dragStartPos.y
                        h = util.clamp(userData.dragStartSize.y + delta.y, minHeight, maxHeight)
                        newSize = util.vector2(newSize.x, h)
                    end

                    -- Moving
                    if userData.dragType == constants.DragType.Move then
                        newPos = userData.dragStartPos + delta
                        newPos = util.vector2(
                            util.clamp(newPos.x, 0, layerSize.x - newSize.x),
                            util.clamp(newPos.y, 0, layerSize.y - newSize.y)
                        )
                    end

                    layout.props.size = newSize
                    layout.props.position = newPos

                    window:update()

                    if onDrag then
                        onDrag(window.layout)
                    end
                end
            end),
            focusGain = async:callback(function()
                window.layout.userData.focusDelayed = true
            end),
            focusLoss = async:callback(function()
                window.layout.userData.focusDelayed = false
            end),
            mouseRelease = async:callback(function(e)
                if e.button ~= 1 then return end
                userData.dragging = false
            end),
        }
    end

    userData.getInnerSize = function()
        local size = window.layout.props.size
        local borderMult = intRe and 2 or 4
        return util.vector2(
            size.x - BORDER_THICKNESS_THICK * borderMult,
            size.y - BORDER_THICKNESS_THICK * borderMult - HEADER_HEIGHT
        )
    end

    userData.setTitle = function(newTitle)
        window.layout.content[2].content[1].content[3].props.text = newTitle
        window:update()
    end

    return window
end

return Templates

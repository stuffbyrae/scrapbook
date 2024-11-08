import("CoreLibs/animator")
import("CoreLibs/math")
import("CoreLibs/timer")
import("CoreLibs/ui")

import("screenshot")

local fle <const> = playdate.file
local gfx <const> = playdate.graphics
local tmr <const> = playdate.timer
local ui <const> = playdate.ui
local snd <const> = playdate.sound

local lerp = playdate.math.lerp

gfx.setBackgroundColor(gfx.kColorBlack)

local background = gfx.image.new("images/background")
local edgeStencil = gfx.image.new("images/edgeStencil")

local loadCoro, viewerLoadCoro
local newPic = false

local sfx_up = snd.sampleplayer.new("audio/up")
local sfx_down = snd.sampleplayer.new("audio/down")
local sfx_go = snd.sampleplayer.new("audio/go")
local sfx_back = snd.sampleplayer.new("audio/back")

local upTimer, downTimer, leftTimer, rightTimer
local crankAccum = 0
local scrollBarAnimator

local maxCrankAccum <const> = 100

focus = "gallery"
pics = nil
viewerScreenshot = nil

local function loadAllPics()
	if type(pics) ~= "table" or #pics == 0 then
		return
	end
	
	for i = 1, #pics do
		pics[i]:load()
	end
end

local function getScrollBarPos(row)
	return lerp(8, 232, (row - 1) / math.ceil(#pics / 2))
end

function refreshPics()
	local screenshots = fle.listFiles("/Screenshots/")
	pics = table.create(128, 0)
	
	for _, filename in ipairs(screenshots) do
		table.insert(pics, Screenshot(filename))
	end
	
	loadCoro = coroutine.create(loadAllPics)
	
	return #pics
end

-- Variables for the "actively selected item" rect, and margins for the grid view
local selectRectOffset <const> = 6
local selectRectLineWidth <const> = 4
local gridRightMargin <const> = 4
local gridBottomMargin <const> = 4
local gridXTotalSize = (400*Screenshot.scale)+(selectRectOffset*2)+gridRightMargin
local gridYTotalSize = (240*Screenshot.scale)+(selectRectOffset*2)+gridBottomMargin
gfx.setLineWidth(selectRectLineWidth)

local gridview = ui.gridview.new(gridXTotalSize, gridYTotalSize)
gridview:setNumberOfColumns(2)
gridview:setSectionHeaderHeight(0)
gridview:setContentInset(6, 6, 6, 6)
gridview:setScrollDuration(200)

function gridview:drawCell(section, row, column, selected, x, y, w, h)
	local screenshot = pics[(row - 1) * 2 + column]
	
	if screenshot ~= nil then
		screenshot:update()
		screenshot:drawThumb(x+selectRectOffset+(selectRectLineWidth/2), y+selectRectOffset+(selectRectLineWidth/2))
		if selected == true then
			gfx.setStencilImage(nil)
			gfx.drawRoundRect(x+(selectRectLineWidth/2), y+(selectRectLineWidth/2), w-(selectRectLineWidth), h-(selectRectLineWidth), 10)
			gfx.setStencilImage(edgeStencil)
		end
	end
end

gridview:setNumberOfRows(math.ceil(refreshPics() / 2))

local function setScrollBarAnimator(row, newRow)
	local prevPos
	
	if scrollBarAnimator == nil then
		prevPos = getScrollBarPos(row)
	else
		prevPos = scrollBarAnimator:currentValue()
	end
	
	scrollBarAnimator = gfx.animator.new(200, prevPos, getScrollBarPos(newRow), playdate.easingFunctions.outCubic)
end

-- Function to move around in the gallery.
function moveGallery(direction)
	local section, row, column = gridview:getSelection()
	if direction == "up" then
		row -= 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectPreviousRow(false)
			setScrollBarAnimator(row + 1, row)
			sfx_up:play()
		else
			sfx_back:play()
		end
	elseif direction == "down" then
		row += 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectNextRow(false)
			setScrollBarAnimator(row - 1, row)
			sfx_down:play()
		else
			sfx_back:play()
		end
	elseif direction == "left" then
		column -= 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectPreviousColumn(true)
			local _, newRow, _ = gridview:getSelection()
			if newRow ~= row then
				setScrollBarAnimator(row, newRow)
			end
			sfx_up:play()
		else
			sfx_back:play()
		end
	elseif direction == "right" then
		column += 1
		if pics[(row - 1) * 2 + column] ~= nil then
			gridview:selectNextColumn(true)
			local _, newRow, _ = gridview:getSelection()
			if newRow ~= row then
				setScrollBarAnimator(row, newRow)
			end
			sfx_down:play()
		else
			sfx_back:play()
		end
	end
end

local galleryHandlers = {
	upButtonDown = function()
		upTimer = tmr.keyRepeatTimer(function()
			moveGallery("up")
		end)
	end,
	upButtonUp = function()
		if upTimer ~= nil then
			upTimer:remove()
			upTimer = nil
		end
	end,
	downButtonDown = function()
		downTimer = tmr.keyRepeatTimer(function()
			moveGallery("down")
		end)
	end,
	downButtonUp = function()
		if downTimer ~= nil then
			downTimer:remove()
			downTimer = nil
		end
	end,
	leftButtonDown = function()
		leftTimer = tmr.keyRepeatTimer(function()
			moveGallery("left")
		end)
	end,
	leftButtonUp = function()
		if leftTimer ~= nil then
			leftTimer:remove()
			leftTimer = nil
		end
	end,
	rightButtonDown = function()
		rightTimer = tmr.keyRepeatTimer(function()
			moveGallery("right")
		end)
	end,
	rightButtonUp = function()
		if rightTimer ~= nil then
			rightTimer:remove()
			rightTimer = nil
		end
	end,
	cranked = function(change, acceleratedChange)
		if math.abs(change) >= 2 then
			crankAccum = crankAccum + acceleratedChange
			if crankAccum > maxCrankAccum then
				moveGallery("right")
				crankAccum = 0
			elseif crankAccum < -maxCrankAccum then
				moveGallery("left")
				crankAccum = 0
			end
		else
			crankAccum = 0
		end
	end,
	AButtonDown = function()
		openViewer(gridview:getSelection())
	end
}

local viewerHandlers = {
	leftButtonDown = function()
		leftTimer = tmr.keyRepeatTimer(function()
			moveViewer("left")
		end)
	end,
	leftButtonUp = function()
		if leftTimer ~= nil then
			leftTimer:remove()
			leftTimer = nil
		end
	end,
	rightButtonDown = function()
		rightTimer = tmr.keyRepeatTimer(function()
			moveViewer("right")
		end)
	end,
	rightButtonUp = function()
		if rightTimer ~= nil then
			rightTimer:remove()
			rightTimer = nil
		end
	end,
	cranked = function(change, acceleratedChange)
		if math.abs(change) >= 2 then
			crankAccum = crankAccum + acceleratedChange
			if crankAccum > maxCrankAccum then
				moveViewer("right")
				crankAccum = 0
			elseif crankAccum < -maxCrankAccum then
				moveViewer("left")
				crankAccum = 0
			end
		else
			crankAccum = 0
		end
	end,
	BButtonDown = function()
		closeViewer(false)
	end
}

function deleteKeyTimers()
	if upTimer ~= nil then
		upTimer:remove()
		upTimer = nil
	end
	if downTimer ~= nil then
		downTimer:remove()
		downTimer = nil
	end
	if leftTimer ~= nil then
		leftTimer:remove()
		leftTimer = nil
	end
	if rightTimer ~= nil then
		rightTimer:remove()
		rightTimer = nil
	end
end

playdate.deviceWillLock = deleteKeyTimers

function openViewer(selection, row, column)
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(viewerHandlers)
	switchAnim = gfx.animator.new(1, 0, 0)
	fadeAnim = gfx.animator.new(1, 1, 1)
	crankAccum = 0
	focus = "viewer"
	viewerScreenshot = pics[(row - 1) * 2 + column]
	viewerLoadCoro = coroutine.create(function() viewerScreenshot:load() end)
	if viewerScreenshot ~= nil then
		deleteKeyTimers()
		sfx_go:play()
		viewerUpdate = true
	else
		closeViewer(true)
	end
end

local moveViewerTransitioning = false

function moveViewer(direction)
	if moveViewerTransitioning == false then
		local section, row, column = gridview:getSelection()
		if direction == "left" then
			test = pics[(row - 1) * 2 + column - 1]
			if (gridview:getNumberOfSections()*-1) + (#pics + 1) < 1 then
				test = nil
			end
		elseif direction == "right" then
			test = pics[(row - 1) * 2 + column + 1]
		end
		if test ~= nil then
			moveViewerTransitioning = true
			lockViewerUpdate = true
			viewerUpdate = true
			if direction == "left" then
				gridview:selectPreviousColumn(true)
				switchAnim = gfx.animator.new(40, 0, 80, playdate.easingFunctions.inCubic)
				sfx_up:play()
			elseif direction == "right" then
				gridview:selectNextColumn(true)
				switchAnim = gfx.animator.new(40, 0, -80, playdate.easingFunctions.inCubic)
				sfx_down:play()
			end
			tmr.performAfterDelay(40, function()
				if direction == "left" then
					switchAnim = gfx.animator.new(40, -80, 0, playdate.easingFunctions.outCubic)
				elseif direction == "right" then
					switchAnim = gfx.animator.new(40, 80, 0, playdate.easingFunctions.outCubic)
				end
				local section, row, column = gridview:getSelection()
				viewerScreenshot = pics[(row - 1) * 2 + column]
				if viewerScreenshot ~= nil then
					viewerScreenshot:update()
					viewerScreenshot:draw(0+switchAnim:currentValue(), 0)
				end
				tmr.performAfterDelay(42, function()
					lockViewerUpdate = false
					moveViewerTransitioning = false
				end)
			end)
		else
			sfx_back:play()
			return
		end
	end
end

function closeViewer(forced)
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(galleryHandlers)
	crankAccum = 0
	focus = "gallery"
	viewerScreenshot = nil
	newPic = true
	deleteKeyTimers()
	if forced then
		sfx_back:play()
	else
		scrollBarAnimator = nil
	end
end

playdate.inputHandlers.push(galleryHandlers)

function playdate.update()
	if type(viewerLoadCoro) == "thread" and coroutine.status(viewerLoadCoro) ~= "dead" then
		coroutine.resume(viewerLoadCoro)
	end
	
	if type(loadCoro) == "thread" and coroutine.status(loadCoro) ~= "dead" then
		coroutine.resume(loadCoro)
		newPic = true
	end
	
	if focus == "gallery" then
		if gridview.needsDisplay or newPic then
			if newPic then
				newPic = false
			end
			
			background:draw(0, 0)
			
			gfx.setStencilImage(edgeStencil)
			gridview:drawInRect(8, 0, 400, 240)
			gfx.setStencilImage(nil)
			
			if #pics > 4 then
				local section, row, column = gridview:getSelection()
				local scrollBarStart = scrollBarAnimator ~= nil and scrollBarAnimator:currentValue() or getScrollBarPos(row)
				local scrollBarHeight = 224 * (1 / math.ceil(#pics / 2))
				
				gfx.setColor(gfx.kColorBlack)
				gfx.fillRoundRect((gridXTotalSize + 12) * 2 + 8, scrollBarStart, 8, scrollBarHeight, 4)
			end
		end
	end

	if focus == "viewer" then
		if viewerUpdate then
			viewerScreenshot:update()
			gfx.clear(gfx.kColorBlack)
			viewerScreenshot:draw(0+switchAnim:currentValue(), 0)
			if viewerScreenshot.loaded and lockViewerUpdate == false then
				viewerUpdate = false
			end
		end
	end
	
	tmr.updateTimers()
end

playdate.display.setRefreshRate(40)
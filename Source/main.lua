import("CoreLibs/timer")
import("CoreLibs/ui")
import("CoreLibs/animator")

import("screenshot")

local fle <const> = playdate.file
local gfx <const> = playdate.graphics
local tmr <const> = playdate.timer
local ui <const> = playdate.ui
local snd <const> = playdate.sound

gfx.setBackgroundColor(gfx.kColorBlack)

local background = gfx.image.new("images/background")
local edgeStencil = gfx.image.new("images/edgeStencil")

local loadCoro
local newPic = false

local sfx_up = snd.sampleplayer.new("audio/up")
local sfx_down = snd.sampleplayer.new("audio/down")
local sfx_go = snd.sampleplayer.new("audio/go")
local sfx_back = snd.sampleplayer.new("audio/back")

local upTimer, downTimer, leftTimer, rightTimer

focus = "gallery"
pics = nil

local function loadAllPics()
	if type(pics) ~= "table" or #pics == 0 then
		return
	end
	
	for i = 1, #pics do
		pics[i]:load()
	end
end

function refreshPics()
	scrapbook.fs.unlock()
	local screenshots = fle.listFiles("/Screenshots")
	scrapbook.fs.lock()
	
	pics = table.create(128, 0)
	for _, filename in ipairs(screenshots) do
		table.insert(pics, Screenshot(filename))
	end
	
	loadCoro = coroutine.create(loadAllPics)
	
	return #pics
end

-- Variables for the "actively selected item" rect, and margins for the grid view
local selectRectOffset = 6
local selectRectLineWidth = 4
local gridRightMargin = 4
local gridBottomMargin = 4
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

-- Function to move around in the gallery.
function moveGallery(direction)
	local selection, row, column = gridview:getSelection()
	if direction == "up" then
		row -= 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectPreviousRow(false)
			sfx_up:play()
		else
			sfx_back:play()
		end
	elseif direction == "down" then
		row += 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectNextRow(false)
			sfx_down:play()
		else
			sfx_back:play()
		end
	elseif direction == "left" then
		column -= 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectPreviousColumn(true)
			sfx_up:play()
		else
			sfx_back:play()
		end
	elseif direction == "right" then
		column += 1
		if pics[(row - 1) * 2 + column] ~= nil then
			gridview:selectNextColumn(true)
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

function openViewer(selection, row, column)
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(viewerHandlers)
	switchAnim = gfx.animator.new(1, 0, 0)
	fadeAnim = gfx.animator.new(1, 1, 1)
	focus = "viewer"
	viewerScreenshot = pics[(row - 1) * 2 + column]
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
		local selection, row, column = gridview:getSelection()
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
				local selection, row, column = gridview:getSelection()
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
	focus = "gallery"
	newPic = true
	deleteKeyTimers()
	if forced then
	else
		sfx_back:play()
	end
end

playdate.inputHandlers.push(galleryHandlers)

function playdate.update()
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

playdate.gameWillTerminate = scrapbook.fs.lock
playdate.deviceWillSleep = scrapbook.fs.lock

playdate.display.setRefreshRate(40)
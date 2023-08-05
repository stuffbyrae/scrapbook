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
local loadCoro
local newPic = false

local sfx_up = snd.sampleplayer.new('audio/up')
local sfx_down = snd.sampleplayer.new('audio/down')
local sfx_go = snd.sampleplayer.new('audio/go')
local sfx_back = snd.sampleplayer.new('audio/back')

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
local gridXTotalSize = (400*(10/24))+(selectRectOffset*2)+gridRightMargin
local gridYTotalSize = (240*(10/24))+(selectRectOffset*2)+gridBottomMargin
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
			gfx.drawRoundRect(x+(selectRectLineWidth/2), y+(selectRectLineWidth/2), w-(selectRectLineWidth), h-(selectRectLineWidth), 10)
		end
	end
end

gridview:setNumberOfRows(math.ceil(refreshPics() / 2))

-- Function to move around in the gallery. hopefully in the future we can use this to play sounds,
-- and also make a little "bonk" animation if we hit an edge. for now, it loops just for fun.
function moveGallery(direction)
	local selection, row, column = gridview:getSelection()
	if direction == "up" then
		row -= 1
		if pics[(row - 1) * 2 + column] ~= nil then 
			gridview:selectPreviousRow(false)
			sfx_down:play()
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
			gridview:selectPreviousColumn(false)
			sfx_down:play()
		else
			sfx_back:play()
		end
	elseif direction == "right" then
		column += 1
		if pics[(row - 1) * 2 + column] ~= nil then
			gridview:selectNextColumn(false)
			sfx_down:play()
		else
			sfx_back:play()
		end
	end
end

local galleryHandlers = {
	upButtonDown = function() local function upCallback() moveGallery("up") end upTimer = tmr.keyRepeatTimer(upCallback) end,
	upButtonUp = function() upTimer:remove() end,
	downButtonDown = function() local function downCallback() moveGallery("down") end downTimer = tmr.keyRepeatTimer(downCallback) end,
	downButtonUp = function() downTimer:remove() end,
	leftButtonDown = function() local function leftCallback() moveGallery("left") end leftTimer = tmr.keyRepeatTimer(leftCallback) end,
	leftButtonUp = function() leftTimer:remove() end,
	rightButtonDown = function() local function rightCallback() moveGallery("right") end rightTimer = tmr.keyRepeatTimer(rightCallback) end,
	rightButtonUp = function() rightTimer:remove() end,
	AButtonDown = function() openViewer(gridview:getSelection()) end
}
local viewerHandlers = {
	leftButtonDown = function() local function leftCallback() moveViewer("left") end leftTimer = tmr.keyRepeatTimer(leftCallback) end,
	leftButtonUp = function() leftTimer:remove() end,
	rightButtonDown = function() local function rightCallback() moveViewer("right") end rightTimer = tmr.keyRepeatTimer(rightCallback) end,
	rightButtonUp = function() rightTimer:remove() end,
	BButtonDown = function() closeViewer(false) end
}

function openViewer(selection, row, column)
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(viewerHandlers)
	switchAnim = gfx.animator.new(1, 0, 0)
	fadeAnim = gfx.animator.new(1, 1, 1)
	focus = "viewer"
	viewerScreenshot = pics[(row - 1) * 2 + column]
	if viewerScreenshot ~= nil then
		sfx_go:play()
		viewerScreenshot:update()
		viewerScreenshot:draw(0+switchAnim:currentValue(), 0)
		viewerUpdate = true
	else
		closeViewer(true)
	end
end

function moveViewer(direction)
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
		lockViewerUpdate = true
		viewerUpdate = true
		if direction == "left" then
			gridview:selectPreviousColumn(true)
			switchAnim = gfx.animator.new(50, 0, 80, playdate.easingFunctions.inCubic)
			sfx_down:play()
		elseif direction == "right" then
			gridview:selectNextColumn(true)
			switchAnim = gfx.animator.new(50, 0, -80, playdate.easingFunctions.inCubic)
			sfx_up:play()
		end
		tmr.performAfterDelay(200, function()
			if direction == "left" then
				switchAnim = gfx.animator.new(50, -80, 0, playdate.easingFunctions.outCubic)
			elseif direction == "right" then
				switchAnim = gfx.animator.new(50, 80, 0, playdate.easingFunctions.outCubic)
			end
			local selection, row, column = gridview:getSelection()
			viewerScreenshot = pics[(row - 1) * 2 + column]
			if viewerScreenshot ~= nil then
				viewerScreenshot:update()
				viewerScreenshot:draw(0+switchAnim:currentValue(), 0)
			end
			function switchAnim:ended()
				lockViewerUpdate = false
			end
		end)
	else
		sfx_back:play()
		return
	end
end

function closeViewer(forced)
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(galleryHandlers)
	focus = "gallery"
	newPic = true
	if forced then
		sfx_back:play()
	else
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
			gridview:drawInRect(8, 0, 400, 240)
		end
	end

	if focus == "viewer" then
		if viewerUpdate then
			viewerScreenshot:update()
			gfx.image.new(400, 240, gfx.kColorBlack):draw(0, 0)
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
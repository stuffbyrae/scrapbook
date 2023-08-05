import("CoreLibs/timer")
import("CoreLibs/ui")
import("CoreLibs/animator")

import("screenshot")

local fle <const> = playdate.file
local gfx <const> = playdate.graphics
local tmr <const> = playdate.timer
local ui <const> = playdate.ui
local snd <const> = playdate.sound

local background = gfx.image.new("images/background")
local loadCoro
local newPic = false

local sfx_up = playdate.sound.sampleplayer.new('audio/up')
local sfx_down = playdate.sound.sampleplayer.new('audio/down')
local sfx_go = playdate.sound.sampleplayer.new('audio/go')
local sfx_open = playdate.sound.sampleplayer.new('audio/open')
local sfx_close = playdate.sound.sampleplayer.new('audio/close')

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
-- and also make a little "bonk" animation if we hit an edge. for now, it loops just for fun
function moveGallery(direction)
	if direction == "up" then
		gridview:selectPreviousRow(true)
		sfx_down:play()
	elseif direction == "down" then
		gridview:selectNextRow(true)
		sfx_up:play()
	elseif direction == "left" then
		gridview:selectPreviousColumn(true)
		sfx_down:play()
	elseif direction == "right" then
		gridview:selectNextColumn(true)
		sfx_up:play()
	end
end

-- function moveViewer(direction)
-- 	if direction == "left" then
-- 		gridview:selectPreviousColumn(true)
-- 	elseif direction == "right" then
-- 		gridview:selectNextColumn(true)
-- 	end
-- 	local screenshot = pics[(row - 1) * 2 + column]
-- 	if screenshot ~= nil then
-- 		screenshot:update()
-- 		screenshot:draw(0, 0)
-- 	end
-- end

local galleryHandlers = {
	upButtonDown = function() moveGallery("up") end,
	downButtonDown = function() moveGallery("down") end,
	leftButtonDown = function() moveGallery("left") end,
	rightButtonDown = function() moveGallery("right") end,
	AButtonDown = function() openViewer(gridview:getSelection()) end
}
local viewerHandlers = {
	-- leftButtonDown = function() moveViewer("left") end,
	-- rightButtonDown = function() moveViewer("right") end,
	BButtonDown = function() closeViewer(false) end
}

function openViewer(selection, row, column)
	sfx_open:play()
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(viewerHandlers)
	focus = "viewer"
	viewerScreenshot = pics[(row - 1) * 2 + column]
	if viewerScreenshot ~= nil then
		viewerScreenshot:update()
		viewerScreenshot:draw(0, 0)
		viewerUpdate = true
	else
		closeViewer(true)
	end
end

function closeViewer(forced)
	sfx_close:play()
	playdate.inputHandlers.pop()
	playdate.inputHandlers.push(galleryHandlers)
	focus = "gallery"
	newPic = true
	if forced then
		-- this is for if it's backed out due to a nil image trying to be opened
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
			viewerScreenshot:draw(0, 0)
			if viewerScreenshot.loaded then
				viewerUpdate = false
			end
		end
	end
	
	tmr.updateTimers()
end

playdate.gameWillTerminate = scrapbook.fs.lock
playdate.deviceWillSleep = scrapbook.fs.lock

playdate.display.setRefreshRate(40)
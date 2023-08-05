import("CoreLibs/timer")
import("CoreLibs/ui")
import("CoreLibs/animator")

import("screenshot")

local fle <const> = playdate.file
local gfx <const> = playdate.graphics
local tmr <const> = playdate.timer
local ui <const> = playdate.ui

local background = gfx.image.new("images/background")
local loadCoro
local newPic = false

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
	elseif direction == "down" then
		gridview:selectNextRow(true)
	elseif direction == "left" then
		gridview:selectPreviousColumn(true)
	elseif direction == "right" then
		gridview:selectNextColumn(true)
	end
end

function playdate.upButtonDown() moveGallery("up") end
function playdate.downButtonDown() moveGallery("down") end
function playdate.leftButtonDown() moveGallery("left") end
function playdate.rightButtonDown() moveGallery("right") end

function playdate.update()
	if type(loadCoro) == "thread" and coroutine.status(loadCoro) ~= "dead" then
		coroutine.resume(loadCoro)
		newPic = true
	end
	
	if gridview.needsDisplay or newPic then
		if newPic then
			newPic = false
		end
		
		background:draw(0, 0)
		gridview:drawInRect(8, 0, 400, 240)
	end
	
	tmr.updateTimers()
end

playdate.gameWillTerminate = scrapbook.fs.lock
playdate.deviceWillSleep = scrapbook.fs.lock

playdate.display.setRefreshRate(40)
import("CoreLibs/sprite")
import("CoreLibs/timer")
import("CoreLibs/ui")

import("screenshot")

local fle <const> = playdate.file
local gfx <const> = playdate.graphics
local tmr <const> = playdate.timer
local ui <const> = playdate.ui

local background = gfx.image.new("images/background")

pics = {}

function refreshPics()
	scrapbook.fs.unlock()
	local screenshots = fle.listFiles("/Screenshots")
	scrapbook.fs.lock()
	
	pics = table.create(128, 0)
	for _, filename in ipairs(screenshots) do
		table.insert(pics, Screenshot(filename))
	end
	
	return #pics
end

local gridview = ui.gridview.new(178, 112)
gridview:setNumberOfColumns(2)
gridview:setNumberOfRows(2)
gridview:setSectionHeaderHeight(0)
gridview:setContentInset(6, 6, 6, 6)
gridview:setScrollDuration(100)

gfx.sprite.setBackgroundDrawingCallback(function(x, y, w, h)
	background:draw(0, 0)
end)

function gridview:drawCell(section, row, column, selected, x, y, w, h)
	local screenshot = pics[(row - 1) * 2 + column]
	if screenshot ~= nil then
		screenshot:drawThumb(x, y)
	end
end

refreshPics()

function playdate.update()
	if gridview.needsDisplay then
		gridview:drawInRect(14, 0, 372, 240)
	end
		
	tmr.updateTimers()
end

playdate.gameWillTerminate = scrapbook.fs.lock
playdate.deviceWillSleep = scrapbook.fs.lock
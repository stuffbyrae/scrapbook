import("CoreLibs/timer")
import("CoreLibs/ui")

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

local gridview = ui.gridview.new(178, 112)
gridview:setNumberOfColumns(2)
gridview:setSectionHeaderHeight(0)
gridview:setContentInset(6, 6, 6, 6)
gridview:setScrollDuration(100)

function gridview:drawCell(section, row, column, selected, x, y, w, h)
	local screenshot = pics[(row - 1) * 2 + column]
	
	if screenshot ~= nil then
		screenshot:update()
		screenshot:drawThumb(x, y)
	end
end

gridview:setNumberOfRows(math.ceil(refreshPics() / 2))

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
		gridview:drawInRect(14, 0, 372, 240)
	end
	
	tmr.updateTimers()
end

playdate.gameWillTerminate = scrapbook.fs.lock
playdate.deviceWillSleep = scrapbook.fs.lock

playdate.display.setRefreshRate(40)
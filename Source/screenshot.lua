import("CoreLibs/animation")
import("CoreLibs/object")
import("CoreLibs/utilities/sampler")

local fle <const> = playdate.file
local gfx <const> = playdate.graphics

local loadTable = gfx.imagetable.new("images/loading")
local loadThumbTable = gfx.imagetable.new("images/loadingThumb")

local loadLoop = gfx.animation.loop.new(25, loadTable)
local loadThumbLoop = gfx.animation.loop.new(25, loadThumbTable)

class("Screenshot", {scale = 10/24}).extends()

function Screenshot:init(path)
	local begin = string.find(path, "(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d)%.?(%d%d)%.?(%d%d)%.gif$")
	self.game = string.sub(path, 1, begin - 2)
	
	local yr, mo, dy, hr, mi, sec = string.match(path, "(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d)%.?(%d%d)%.?(%d%d)%.gif$")
	self.timestamp = playdate.epochFromTime({
		year = yr,
		month = mo,
		day = dy,
		hour = hr,
		minute = mi,
		second = sec,
		millisecond = 0
	})
	
	self.path = path
	self.loaded = false
end

function Screenshot:load()
	scrapbook.fs.unlock()
	
	local file = fle.open("/Screenshots/" .. self.path)
	
	local gif = scrapbook.gif.open(file)
	if gif == nil then
		error("Error opening GIF at path: " .. self.path)
		file:close()
		return
	end
	
	local t = playdate.getCurrentTimeMilliseconds()
	self.image = gif:getFrame()
	print(playdate.getCurrentTimeMilliseconds() - t)
	self.thumb = nil
	
	gif:close()
	file:close()
	
	scrapbook.fs.lock()
	self.loaded = true
end

function Screenshot:update()
	if not self.loaded then
		self.image = loadLoop:image()
		self.thumb = loadThumbLoop:image()
	end
end

function Screenshot:drawThumb(x, y)
	if not self.loaded then
		self.thumb:draw(x, y)
	else
		self.image:drawScaled(x, y, Screenshot.scale)
	end
end

function Screenshot:draw(x, y)
	self.image:draw(x, y)
end
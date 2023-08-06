import("CoreLibs/animation")
import("CoreLibs/object")

local dts <const> = playdate.datastore
local fle <const> = playdate.file
local gfx <const> = playdate.graphics

local loadTable = gfx.imagetable.new("images/loading")
local loadThumbTable = gfx.imagetable.new("images/loadingThumb")

local loadLoop = gfx.animation.loop.new(25, loadTable)
local loadThumbLoop = gfx.animation.loop.new(25, loadThumbTable)

class("Screenshot", {scale = 1/3}).extends()

function Screenshot:init(path)
	local begin = string.find(path, "(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d)%.(%d%d)%.(%d%d)%.gif$")
	if begin == nil then
		scrapbook.fs.unlock()
		self.timestamp = fle.modtime("/Screenshots/" .. path)
		scrapbook.fs.lock()
	else
		self.game = string.sub(path, 1, begin - 2)
		
		local yr, mo, dy, hr, mi, sec = string.match(path, "(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d)%.(%d%d)%.(%d%d)%.gif$")
		self.timestamp = playdate.epochFromTime({
			year = yr,
			month = mo,
			day = dy,
			hour = hr,
			minute = mi,
			second = sec,
			millisecond = 0
		})
	end
	
	self.path = path
	self.loaded = false
end

function Screenshot:load()
	if fle.exists("cache/" .. string.gsub(self.path, ".gif", ".pdi")) then
		self.image = gfx.image.new("cache/" .. string.gsub(self.path, ".gif", ".pdi"))
		self.thumb = nil
		self.loaded = true
		return
	end
	
	scrapbook.fs.unlock()
	
	local file = fle.open("/Screenshots/" .. self.path)
	
	local gif = scrapbook.gif.open(file)
	if gif == nil then
		gif:close()
		file:close()
		scrapbook.fs.lock()
		error("Error opening GIF at path: " .. self.path)
		return
	end
	
	local dec, err = gif:getDecoder()
	if dec == nil then
		gif:close()
		file:close()
		scrapbook.fs.lock()
		error("Error loading " .. self.path .. ": " .. err)
		return
	end
	
	local success, status = dec:step()
	
	while success == true and status ~= false do
		coroutine.yield()
		success, status = dec:step()
	end
	
	if not success then
		gif:close()
		file:close()
		scrapbook.fs.lock()
		error("Error loading " .. self.path .. ": " .. status)
		return
	end
	
	self.image = gif:getFrame()
	self.thumb = nil
	
	gif:close()
	file:close()
	
	scrapbook.fs.lock()
	dts.writeImage(self.image, "cache/" .. string.gsub(self.path, ".gif", ".pdi"))
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

function Screenshot:drawFaded(x, y, alpha, ditherType)
	self.image:drawFaded(x, y, alpha, ditherType)
end
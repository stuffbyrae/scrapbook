import("CoreLibs/object")

local fle <const> = playdate.file

class("Screenshot", {scale = 10/24}).extends()

function Screenshot:init(path)
	local begin = string.find(path, "(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d)%.?(%d%d)%.?(%d%d)%.gif$")
	self.game = string.sub(path, 1, begin - 1)
	
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
	
	scrapbook.fs.unlock()
	
	local file = fle.open("/Screenshots/" .. path)
	local gif = scrapbook.gif.open(file)
	if gif == nil then
		error("Error opening GIF at path: " .. path)
		file:close()
		return
	end
	
	self.image = gif:getFrame():copy()
	self.image:removeMask()
	
	gif:close()
	file:close()
	
	scrapbook.fs.lock()
end

function Screenshot:drawThumb(x, y)
	self.image:drawScaled(x, y, Screenshot.scale)
end

function Screenshot:draw(x, y)
	self.image:draw(x, y)
end
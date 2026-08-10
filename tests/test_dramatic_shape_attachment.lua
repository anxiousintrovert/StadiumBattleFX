local loader = love and love.filesystem and love.filesystem.load or loadfile
local Attachment = assert(loader("lib/DramaticShapeAttachment.lua"))()

local x = Attachment.position(function() return nil end, "enemy", 0x64)
assert(x == nil and not Attachment.status().supported)

local calls = {}
local Stadium = { attachment = function(side, tag)
  calls[#calls + 1] = { side, tag }
  if side == "enemy" then return 91.5, 42.25 end
end,
center = function(side)
  if side == "enemy" then return 90, 36 end
end,
attachmentTags = function(side, moveId, stage)
  assert(side == "enemy" and moveId == 84 and stage == "primary")
  return 0x0D, 0x0E
end }
local companion = function()
  return { exports = { lib = { require = function(name)
    assert(name == "Stadium")
    return Stadium
  end } } }
end

local ax, ay = Attachment.position(companion, "enemy", 0x07)
assert(ax == 91.5 and ay == 42.25)
assert(calls[1][1] == "enemy" and calls[1][2] == 0x07)
assert(Attachment.position(companion, "player") == nil)
local cx, cy = Attachment.position(companion, "enemy", 0xFF)
assert(cx == 90 and cy == 36)
local ta, tb = Attachment.tags(companion, "enemy", 84, "primary")
assert(ta == 0x0D and tb == 0x0E)
local status = Attachment.status()
assert(status.supported and status.requests == 4 and status.resolved == 2)
assert(status.lastError == nil)
print("ok projected Stadium attachment bridge")

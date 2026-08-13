local loader = love and love.filesystem and love.filesystem.load or loadfile
local enabled = false
local calls = {}
local Host = { call = function(_, method, side, value, stage)
  if not enabled then return false, "no active models provider" end
  calls[#calls + 1] = { method, side, value, stage }
  if method == "attachment" and side == "enemy" then return true, 91.5, 42.25 end
  if method == "center" and side == "enemy" then return true, 90, 36 end
  if method == "attachmentTags" then return true, 0x0D, 0x0E end
  if method == "synchronizeMove" then return true, true end
  return true
end }
local Attachment = assert(loader("lib/DramaticShapeAttachment.lua"))({
  require = function(name) assert(name == "BattleHost"); return Host end,
})

assert(Attachment.position(nil, "enemy", 0x64) == nil)
assert(not Attachment.status().supported)
enabled = true
local ax, ay = Attachment.position(nil, "enemy", 0x07)
assert(ax == 91.5 and ay == 42.25)
assert(calls[#calls][1] == "attachment" and calls[#calls][3] == 0x07)
assert(Attachment.position(nil, "player") == nil)
local cx, cy = Attachment.position(nil, "enemy", 0xFF)
assert(cx == 90 and cy == 36)
local ta, tb = Attachment.tags(nil, "enemy", 84, "primary")
assert(ta == 0x0D and tb == 0x0E)
assert(Attachment.synchronizeMove(nil, "enemy", 84, 17.5))
assert(calls[#calls][1] == "synchronizeMove" and calls[#calls][4] == 17.5)
local status = Attachment.status()
assert(status.supported and status.requests == 4 and status.resolved == 2)
print("ok selected model-provider attachment bridge")

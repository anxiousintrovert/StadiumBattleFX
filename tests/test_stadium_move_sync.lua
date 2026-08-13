-- DSM6 retains all native per-species/per-move controller bytes.

local function u16(v)
  return string.char(v % 256, math.floor(v / 256) % 256)
end

local parts = { "DSM6" }
-- species; bone/primitive/texture/animation/aux/attachment counts
parts[#parts + 1] = u16(25) .. string.rep(u16(0), 6)
-- root scale, static flag, height/floor/radius
parts[#parts + 1] = string.rep("\0", 4) .. "\0" .. string.rep("\0", 12)
-- animation indices and aux indices
parts[#parts + 1] = string.rep(u16(0xFFFF), 165)
parts[#parts + 1] = string.rep(u16(0xFFFF), 165)
-- attachment A/B
parts[#parts + 1] = string.rep(string.char(0x64), 165)
parts[#parts + 1] = string.rep(string.char(0xFF), 165)
-- Native bytes 0x04..0x0F. Give move 84 a recognizable row.
for move = 1, 165 do
  if move == 84 then
    parts[#parts + 1] = string.char(7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18)
  else
    parts[#parts + 1] = string.rep("\0", 12)
  end
end
-- 20 context animation indices and their two attachment tables
parts[#parts + 1] = string.rep(u16(0xFFFF), 20)
parts[#parts + 1] = string.rep(string.char(0xFF), 40)
local bytes = table.concat(parts)

local modules = {}
local V = {
  mod = { read = function(_, path)
    assert(path == "assets/stadium/025.dsm")
    return bytes
  end },
  log = { warn = function(_, message) error(message) end },
}
function V.require(name)
  if name == "ModStorage" then return { bytes = function() return nil end } end
  if name == "StadiumInstall" then return { ready = function() return false end } end
  if not modules[name] then modules[name] = assert(loadfile("lib/" .. name .. ".lua"))(V) end
  return modules[name]
end

local Pack = V.require("StadiumPack")
local model = assert(Pack.load(25))
local row = assert(model.moveSync[84])
for field = 5, 16 do
  assert(row[field] == field + 2, ("field %d was %s"):format(field, tostring(row[field])))
end
assert(model.moveAttachA[84] == 0x64 and model.moveAttachB[84] == 0xFF)

print("ok DSM6 native move synchronization rows")

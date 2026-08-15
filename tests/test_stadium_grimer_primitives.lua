local source = assert(io.open("lib/StadiumPack.lua", "rb"))
local chunk = assert(load(source:read("*a"), "@lib/StadiumPack.lua"))
source:close()

local function u16(value)
  return string.char(value % 256, math.floor(value / 256) % 256)
end

local function i16(value)
  if value < 0 then value = value + 65536 end
  return u16(value)
end

local function buildPack(species)
  local out = { "DSM7", u16(species), u16(0), u16(8), u16(0), u16(0),
    u16(0), u16(0), "\0\0\128?", "\0", "\0\0\128?", "\0\0\128?",
    "\0\0\128?" }
  for _ = 1, 165 do out[#out + 1] = u16(0) end
  for _ = 1, 165 do out[#out + 1] = i16(0) end
  for _ = 1, 165 * 2 + 165 * 12 do out[#out + 1] = "\0" end
  for _ = 1, 20 do out[#out + 1] = u16(0) end
  for _ = 1, 20 * 2 do out[#out + 1] = "\0" end
  for primitive = 1, 8 do
    out[#out + 1] = u16(primitive - 1)
    out[#out + 1] = "\0\0"
    out[#out + 1] = primitive == 2 and "\1" or "\0"
    out[#out + 1] = i16(-1)
    out[#out + 1] = "\0"
    out[#out + 1] = u16(0)
    out[#out + 1] = u16(0)
    out[#out + 1] = u16(0)
  end
  return table.concat(out)
end

local bytes = buildPack(88)
local Pack = chunk({
  mod = { read = function() return bytes end },
  require = function(name)
    if name == "ModStorage" then return { bytes = function() return nil end } end
    if name == "StadiumInstall" then return { ready = function() return false end } end
    error("unexpected module: " .. name)
  end,
  log = { warn = function() end },
})

local grimer = assert(Pack.loadBase(88))
assert(grimer.primCount == 8 and #grimer.prims == 8,
  "a pack reader must retain every primitive emitted by the graph interpreter")
assert(grimer.prims[2].texGen and not grimer.prims[1].texGen,
  "DSM7 must preserve per-material texture-coordinate generation")

print("ok Stadium 1 generated texture coordinates")

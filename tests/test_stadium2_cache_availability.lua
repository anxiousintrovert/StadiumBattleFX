local source = assert(io.open("lib/stadium2/cache.lua", "rb"))
local chunk = assert(load(source:read("*a"), "@lib/stadium2/cache.lua"))
source:close()

local probes = 0
love = love or {}
love.filesystem = love.filesystem or {}
local oldGetInfo, oldRead = love.filesystem.getInfo, love.filesystem.read
love.filesystem.getInfo = function()
  probes = probes + 1
  return { type = "file" }
end
love.filesystem.read = function(path)
  if path:match("pack%.info$") then return "format=S2G1M02\ncount=2\n" end
  return "pack"
end

local Cache = chunk()
assert(Cache.available(2))
local first = probes
assert(first == 6, "availability did not probe the expected cache records")
assert(Cache.available(2))
assert(probes == first, "cached availability repeated filesystem probes")

Cache.invalidateAvailability()
assert(Cache.available(2))
assert(probes == first * 2, "availability invalidation did not rescan cache records")

love.filesystem.getInfo, love.filesystem.read = oldGetInfo, oldRead

print("ok Stadium 2 availability memoization")

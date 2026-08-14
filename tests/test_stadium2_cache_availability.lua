local source = assert(io.open("lib/stadium2/cache.lua", "rb"))
local chunk = assert(load(source:read("*a"), "@lib/stadium2/cache.lua"))
source:close()

local probes = 0
local Storage = {}
function Storage.bundled(path)
  probes = probes + 1
  if path:match("pack%.info$") then return "format=S2G1M02\ncount=2\n" end
  return "pack"
end

local Cache = chunk({ require = function(name)
  assert(name == "ModStorage")
  return Storage
end })
assert(Cache.available(2))
local first = probes
assert(first == 6, "availability did not probe the expected cache records")
assert(Cache.available(2))
assert(probes == first, "cached availability repeated filesystem probes")

Cache.invalidateAvailability()
assert(Cache.available(2))
assert(probes == first * 2, "availability invalidation did not rescan cache records")

print("ok Stadium 2 availability memoization")

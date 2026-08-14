local source = assert(io.open("lib/StadiumRig.lua", "rb"))
local chunk = assert(load(source:read("*a"), "@lib/StadiumRig.lua"))
source:close()

local Rig = chunk({ require = function(name)
  if name == "StadiumPack" then return { FPS = 30, SLOT = {} } end
  return {}
end })

local calls = 0
local texture = { setWrap = function(_, s, t)
  calls = calls + 1
  assert(type(s) == "string" and type(t) == "string")
end }
local part = { texture = texture, prim = { wrapS = "clamp", wrapT = "repeat" } }

Rig._applyWrap(part)
Rig._applyWrap(part)
assert(calls == 1, "unchanged texture wrap state was applied more than once")
part.prim.wrapT = "clamp"
Rig._applyWrap(part)
assert(calls == 2, "changed texture wrap state was not applied")

print("ok Stadium rig texture wrap cache")

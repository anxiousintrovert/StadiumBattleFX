local loader = love and love.filesystem and love.filesystem.load or loadfile
local native = assert(loader("lib/effects/StadiumNativePrograms.lua"))()

assert(native.schema == 2, "unexpected native program schema")
local moveCount, programCount, eventCount = 0, 0, 0
for id = 1, 165 do
  local move = assert(native.moves[id], "missing native move " .. id)
  assert(type(move.key) == "string")
  moveCount = moveCount + 1
end
for _, program in pairs(native.programs) do
  programCount = programCount + 1
  for _, event in ipairs(program.events) do
    assert(type(event.at) == "number", "native event tick was not resolved")
    eventCount = eventCount + 1
  end
end
assert(moveCount == 165, "native move coverage changed")
assert(programCount == 193, "native program coverage changed")
assert(eventCount == 671, "native emission schedule coverage changed")
assert(type(native.renderPresets) == "table"
  and type(native.renderPresets[0].target) == "string",
  "native render preset table is missing")
assert(type(native.particlePresets) == "table"
  and type(native.particlePresets[0].draw) == "string"
  and type(native.particlePresets[0].initialize) == "string",
  "native particle preset table is missing")

local shock = native.moves[84]
assert(shock.primary[1] == "primary:0x3B")
assert(shock.impact[1] == "impact:0x08")
local primary = native.programs[shock.primary[1]]
assert(primary.events[3].at == 0 and primary.events[3].interval == 8
  and primary.events[3].repeats == 3,
  "Thunder Shock native burst schedule changed")
assert(primary.events[6].at == 35 and primary.events[6].particleCount == 20,
  "Thunder Shock native bolt emission changed")

print("ok Stadium native program schedules")

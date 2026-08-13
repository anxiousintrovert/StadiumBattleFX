local loader = love and love.filesystem and love.filesystem.load or loadfile
local Interpreter = assert(loader("lib/effects/StadiumNativeInterpreter.lua"))()

local primary = { events = {
  { at = 3, interval = 4, repeats = 3, callback = "bolt" },
  { at = 9, interval = 0, repeats = 1, callback = "flash" },
} }
local impact = { events = {
  { at = 0, interval = 2, repeats = 2, callback = "hit" },
} }
local spec = {
  impactAt = 20,
  nativePrograms = { primary = { primary }, alternate = {}, impact = { impact } },
}

local active = Interpreter.active(spec, 8, 6)
assert(#active == 2 and active[1].born == 3 and active[1].age == 5)
assert(active[2].born == 7 and active[2].age == 1)
local births = Interpreter.births(spec, 6.5, 9)
assert(#births == 2 and births[1].born == 7 and births[2].born == 9)
local hit = Interpreter.births(spec, 19, 22)
assert(#hit == 2 and hit[1].channel == "impact" and hit[2].born == 2)

print("ok frame-exact Stadium scheduler interpreter")

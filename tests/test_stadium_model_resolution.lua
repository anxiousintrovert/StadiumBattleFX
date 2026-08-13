local loader = love and love.filesystem and love.filesystem.load or loadfile

local modules = {
  StadiumRender = { available = function() return true end },
  StadiumPack = { invalidate = function() end },
  StadiumMon = { new = function() return { release = function() end } end },
}

local Stadium = assert(loader("lib/StadiumModels.lua"))({
  require = function(name)
    assert(modules[name], "unexpected module " .. tostring(name))
    return modules[name]
  end,
  log = { info = function() end, warn = function() end },
})

local battle = {
  data = { pokemon = { PIKACHU = { dex = 25 } } },
}
assert(Stadium._dexOf("PIKACHU", battle) == 25,
  "live BattleState data did not resolve the Stadium species pack")
assert(Stadium._dexOf("MISSINGNO", battle) == nil)

local gameBattle = {
  game = { data = { pokemon = { MEW = { dex = 151 } } } },
}
assert(Stadium._dexOf("MEW", gameBattle) == 151,
  "live game data fallback did not resolve the Stadium species pack")

-- A send-out flag becomes true while its message is still on screen. It is
-- context, not permission to draw: the model enters on the first update after
-- that message is cleared, and never flashes over the text.
assert(not Stadium._arrivalReady(true, true, true),
  "Pokemon became visible before its send-out text was cleared")
assert(Stadium._arrivalReady(false, true, true),
  "Pokemon did not enter after its send-out text was cleared")
assert(Stadium._arrivalReady(false, false, true),
  "Pokemon missed the text-clear edge after the send-out flag ended")
assert(not Stadium._arrivalReady(false, false, false),
  "Pokemon entered without observing a send-out")

local function fieldBattle(kind, side)
  local battler = { sprite = {} }
  local battle = {
    kind = kind,
    phase = "intro",
    player = side == "player" and battler or nil,
    enemy = side == "enemy" and battler or nil,
    fxHidden = function() return false end,
  }
  return battle
end

assert(not Stadium._onField(fieldBattle("trainer", "enemy"), "enemy", {}),
  "trainer Pokemon flashed before the opening send-out")
assert(not Stadium._onField(fieldBattle("link", "enemy"), "enemy", {}),
  "link Pokemon flashed before the opening send-out")
assert(Stadium._onField(fieldBattle("wild", "enemy"), "enemy", {}),
  "wild Pokemon was incorrectly hidden during its appearance")
assert(not Stadium._onField(fieldBattle("trainer", "player"), "player", {}),
  "player Pokemon flashed before the opening send-out")

print("ok live Stadium model species resolution")

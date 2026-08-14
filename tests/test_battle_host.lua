local loader = loadfile or (love and love.filesystem and love.filesystem.load)
local FALLBACK = {}
local calls = {}
local arena = { player = { 0, 24 }, enemy = { 0, -24 }, mid = { 0, 0 } }
local arenaProvider = {
  arena = function() calls[#calls + 1] = "arena"; return arena end,
  begin = function(_, context, got) assert(got == arena); calls[#calls + 1] = "arena.begin" end,
  update = function() calls[#calls + 1] = "arena.update" end,
  finish = function() calls[#calls + 1] = "arena.finish" end,
}
local modelProvider = {
  begin = function(_, context, got) assert(got == arena); calls[#calls + 1] = "models.begin" end,
  update = function() calls[#calls + 1] = "models.update" end,
  showing = function(_, _, side) return side == "player" end,
  finish = function() calls[#calls + 1] = "models.finish" end,
}
local serviceProvider = {
  begin = function() calls[#calls + 1] = "service.begin" end,
  event = function(_, _, name) calls[#calls + 1] = name end,
  update = function() calls[#calls + 1] = "service.update" end,
  finish = function() calls[#calls + 1] = "service.finish" end,
}
local failedUpdates = 0
local failedFinished = false
local compatClaim, compatUpdates = false, 0
local portraitApplyCalls = 0
local failingProvider = {
  update = function() failedUpdates = failedUpdates + 1; error("expected") end,
  finish = function() failedFinished = true end,
}
local rejectArena = false
local rejectingArena = {
  arena = function() return arena end,
  begin = function() return false end,
}
local builtin = {
  arena = function() return { id = "builtin", player = { 0, 24 },
    enemy = { 0, -24 }, mid = { 0, 0 } } end,
  begin = function() calls[#calls + 1] = "builtin.begin" end,
}
local providers = {
  VERSION = 1, FALLBACK = FALLBACK, DEFAULT = "stadium:default",
  resolve = function(slot)
    if slot == "arena" then
      return rejectArena and rejectingArena or arenaProvider, { id = "TEST:arena" }
    end
    if slot == "models" then return modelProvider, { id = "TEST:models" } end
    if slot == "effects" then return serviceProvider, { id = "TEST:effects" } end
    if slot == "camera" then return serviceProvider, { id = "stadium:default" } end
    if slot == "animations" then return failingProvider, { id = "TEST:failing" } end
  end,
  builtin = function(slot)
    if slot == "arena" then return builtin, { id = "stadium:default" } end
  end,
}
local log = { info = function() end, warn = function() end, error = function() end }
local Host = assert(loader("lib/BattleHost.lua"))({
  log = log,
  require = function(name)
    if name == "BattleProviders" then return providers end
    if name == "Mat4" then return {} end
    if name == "StadiumRender" then return {} end
    if name == "BattleCinematicsCompat" then
      return {
        claim = function() return compatClaim end,
        shot = function()
          return { eye = { 9, 8, 7 }, focus = { 1, 2, 3 }, fov = 0.5 }, 0.25
        end,
        update = function() compatUpdates = compatUpdates + 1 end,
      }
    end
    if name == "StadiumTrainerPortraits" then
      return { apply = function() portraitApplyCalls = portraitApplyCalls + 1 end,
        update = function() end,
        restore = function() end }
    end
    if name == "AttackCinematics" then
      return { camera = function(base) return base end }
    end
    error(name)
  end,
})

local battle = {
  kind = "trainer", oppClass = "OPP_BROCK", partyIndex = 1,
  player = {}, enemy = {}, game = {},
  currentMapId = function() return "PEWTER_GYM" end,
}
assert(Host.begin(battle))
assert(portraitApplyCalls == 1, "trainer portraits were not enabled by default")
assert(Host.session.context.arena == arena)
local captureOk, captureValue =
  Host.session.context.services.withNativeBattlePics(function() return 42 end)
assert(captureOk and captureValue == 42,
  "native battle-pic capture service did not scope the callback")
compatClaim = true
local pose, pitch = Host.cameraPose()
assert(pose.eye[1] == 9 and pitch == 0.25,
  "legacy compatibility pose did not reach the battle host")
Host.update(1 / 60)
Host.update(1 / 60)
assert(compatUpdates == 2, "legacy compatibility camera was not updated")
assert(failedUpdates == 1, "a failed provider must stay disabled for the battle")
Host.event("battle.move_used", { move = { index = 84 } })
local ok, showing = Host.call("models", "showing", "player")
assert(ok and showing)
Host.finish("test")
assert(Host.session == nil)
assert(failedFinished, "disabled providers must still receive finish")
local joined = table.concat(calls, "|")
for _, wanted in ipairs({ "arena", "arena.begin", "models.begin", "service.begin",
  "arena.update", "models.update", "service.update", "battle.move_used",
  "models.finish", "arena.finish", "service.finish" }) do
  assert(joined:find(wanted, 1, true), "missing lifecycle call " .. wanted)
end

rejectArena = true
assert(Host.begin(battle))
assert(Host.session.context.arena.id == "builtin")
assert(table.concat(calls, "|"):find("builtin.begin", 1, true))
Host.finish("fallback-test")

assert(Host.begin(battle, false))
assert(portraitApplyCalls == 2,
  "disabling trainer portraits still replaced the opening trainer sprite")
Host.finish("portraits-disabled-test")
print("ok protected battle-provider lifecycle")

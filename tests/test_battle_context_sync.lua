local loader = loadfile or (love and love.filesystem and love.filesystem.load)
local FALLBACK = {}
local arena = { player = { 0, 24 }, enemy = { 0, -24 }, mid = { 0, 0 } }
local observed = {}

local arenaProvider = {
  arena = function() return arena end,
  begin = function() return true end,
  update = function() end,
  finish = function() end,
}

local modelProvider = {
  begin = function() return true end,
  update = function() end,
  finish = function() end,
}

local serviceProvider = {
  begin = function(_, context)
    observed.beginPlayer = context.sides.player.battler
    observed.beginEnemy = context.sides.enemy.battler
  end,
  event = function(_, context, name)
    if name == "battle.battler_switched" then
      observed.eventPlayer = context.sides.player.battler
      observed.eventEnemy = context.sides.enemy.battler
    end
  end,
  update = function(_, context)
    observed.updatePlayer = context.sides.player.battler
    observed.updateEnemy = context.sides.enemy.battler
  end,
  finish = function() end,
}

local providers = {
  VERSION = 1,
  FALLBACK = FALLBACK,
  DEFAULT = "stadium:default",
  resolve = function(slot)
    if slot == "arena" then return arenaProvider, { id = "TEST:arena" } end
    if slot == "models" then return modelProvider, { id = "TEST:models" } end
    if slot == "effects" then return serviceProvider, { id = "TEST:effects" } end
  end,
  builtin = function() return nil end,
}

local log = { info = function() end, warn = function() end, error = function() end }
local battle
local Host = assert(loader("lib/BattleHost.lua"))({
  log = log,
  require = function(name)
    if name == "BattleProviders" then return providers end
    if name == "Mat4" then return {} end
    if name == "StadiumRender" then return {} end
    if name == "BattleCinematicsCompat" then
      return { claim = function() return false end, update = function() end }
    end
    if name == "BattleArtCompat" then
      return {
        owner = function() return nil end,
        ownsBattle = function() return false end,
      }
    end
    if name == "StadiumTrainerPortraits" then
      return {
        apply = function() return nil end,
        update = function() end,
        restore = function() end,
        owns = function() return false end,
      }
    end
    if name == "AttackCinematics" then
      return { camera = function(base) return base end }
    end
    error(name)
  end,
})

local openingPlayer = { id = "opening-player" }
local openingEnemy = { id = "opening-enemy" }
battle = {
  kind = "trainer",
  player = openingPlayer,
  enemy = openingEnemy,
  game = {},
  currentMapId = function() return "TEST_MAP" end,
}

assert(Host.begin(battle))
assert(observed.beginPlayer == openingPlayer, "provider begin did not receive opening player")
assert(observed.beginEnemy == openingEnemy, "provider begin did not receive opening enemy")

local switchedPlayer = { id = "switched-player" }
local switchedEnemy = { id = "switched-enemy" }
battle.player = switchedPlayer
battle.enemy = switchedEnemy
Host.event("battle.battler_switched", { side = "player" })
assert(observed.eventPlayer == switchedPlayer,
  "switch event retained the opening player battler")
assert(observed.eventEnemy == switchedEnemy,
  "switch event retained the opening enemy battler")

local latestPlayer = { id = "latest-player" }
local latestEnemy = { id = "latest-enemy" }
battle.player = latestPlayer
battle.enemy = latestEnemy
Host.update(1 / 60)
assert(observed.updatePlayer == latestPlayer,
  "provider update retained a stale player battler")
assert(observed.updateEnemy == latestEnemy,
  "provider update retained a stale enemy battler")

Host.finish("test")
print("ok live battler context synchronization")

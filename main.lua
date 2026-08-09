-- Stadium Attack Animations: portable Stadium move effects for Gen1Recomp.

local mod = ...

if love and os and os.getenv and os.getenv("STADIUM_ANNOUNCER_TEST") == "1" then
  return require("tests.test_announcer")
end

-- The repository doubles as a small LÖVE research harness. Gen1Recomp
-- supplies a mod object here; a direct `love .` launch does not.
if love and (type(mod) ~= "table" or type(mod.read) ~= "function") then
  if os and os.getenv and os.getenv("STADIUM_FX_SELFTEST") == "1" then
    return require("viewer.SelfTest")
  end
  return require("viewer.App")
end

local namespace = { mod = mod, path = mod.path }
local modules = {}

local function moduleChunk(name)
  local rel = "lib/" .. name .. ".lua"
  local source = mod:read(rel)
  if not source then
    error(("STADIUM_BATTLE_FX: missing %s; reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("STADIUM_BATTLE_FX: %s did not compile: %s")
      :format(rel, tostring(err)), 0)
  end
  return chunk
end

function namespace.require(name)
  if modules[name] ~= nil then return modules[name] end
  local value = moduleChunk(name)(namespace)
  modules[name] = value
  return value
end

local StadiumRom = namespace.require("StadiumRom")
local ThunderShockSpec = namespace.require("effects/ThunderShockSpec")
local StadiumAssets = namespace.require("StadiumAssets")
local MoveSpecs = namespace.require("effects/MoveSpecs")
local StadiumFxPlayer = namespace.require("effects/StadiumFxPlayer")
local StadiumScreenFx = namespace.require("effects/StadiumScreenFx")
local EffectCacheScreen = namespace.require("EffectCacheScreen")
local AttackCinematics = namespace.require("AttackCinematics")
local Announcer = namespace.require("Announcer")
local FailureNotice = namespace.require("FailureNotice")

local function dramalessCompanion()
  return mod.find("DRAMALESS_SHAPE")
end

mod.options:define({
  { key = "enabled", label = "STADIUM FX", type = "toggle", default = true },
  { key = "attack_camera", label = "ATTACK CAMERA", type = "toggle", default = true },
  { key = "announcer", label = "STADIUM ANNOUNCER", type = "toggle", default = true },
  { key = "battle_cinematics_zoom", label = "BC ZOOM OUT", type = "choice",
    default = "off",
    choices = {
      { "OFF", "off" }, { "10%", "10" }, { "25%", "25" },
      { "35%", "35" }, { "50%", "50" },
    } },
})

mod.exports.version = "1.0.1"
mod.exports.rom = StadiumRom
mod.exports.thunderShock = ThunderShockSpec
mod.exports.moves = MoveSpecs
mod.exports.attackCinematics = AttackCinematics.status
mod.exports.textureStatus = StadiumAssets.status
mod.exports.announcerStatus = Announcer.status
mod.exports.dramaticShape = function()
  return dramalessCompanion()
end
mod.exports.dramalessShape = dramalessCompanion
mod.exports.battleCinematics = function()
  return mod.find("BATTLE_CINEMATICS")
end

-- Offer the one-time cache build only after the real overworld owns the
-- stack. The fixed-step seam supplies the live Game object on desktop and
-- Android, including configurations that do not enable a render pipeline.
mod.hooks:wrap("input.step", function(next, game, dt)
  local result = next(game, dt)
  Announcer.update(dt)
  FailureNotice.update(dt)
  if mod.options:get("enabled") ~= false then
    local ok, err = pcall(EffectCacheScreen.maybePush, game)
    if not ok then mod.log:warn("attack cache screen unavailable: %s", tostring(err)) end
  end
  return result
end)

-- Continue screen-wide move layers into desktop borderless margins after the
-- game canvas is composed. Anchored particles remain on the battle surface.
mod.hooks:wrap("render.hud", function(next, game, viewport)
  local result = next(game, viewport)
  StadiumScreenFx.present(game, viewport)
  FailureNotice.draw(viewport)
  return result
end)

-- BattleState creates one AnimPlayer per battle. Replacing that instance with
-- a narrow adapter preserves the engine's queue/draw contract and also lets
-- Dramaless Shape keeps transforming the ordinary animation layer. The
-- adapter now owns a presentation for the complete 165-move Gen 1 roster.
mod.events:on("battle.started", function(payload)
  local battle = payload and payload.battle
  Announcer.beginBattle(battle)
  if not (battle and battle.animPlayer) then return end
  if getmetatable(battle.animPlayer) == StadiumFxPlayer then return end
  local options = battle.game and battle.game.save and battle.game.save.options
  StadiumScreenFx.setBorderless(options and options.videoMode == "borderless")

  if mod.options:get("enabled") ~= false then
    local ready, err = StadiumAssets.preload()
    if ready then
      local status = StadiumAssets.status()
      mod.log:info("loaded %d Stadium effect primitives from %s",
        tonumber(status.assets) or 0, tostring(status.source or "runtime"))
    else
      mod.log:warn("Stadium effect cache unavailable: %s", tostring(err))
    end
  end

  AttackCinematics.configure(
    dramalessCompanion,
    function() return mod.find("BATTLE_CINEMATICS") end,
    function()
      if mod.options:get("enabled") == false then return "off" end
      return mod.options:get("battle_cinematics_zoom") or "off"
    end)

  battle.animPlayer = StadiumFxPlayer.new(
    battle.animPlayer,
    function() return mod.options:get("enabled") ~= false end,
    mod.log,
    dramalessCompanion,
    function() return mod.find("BATTLE_CINEMATICS") end,
    function() return mod.options:get("attack_camera") ~= false end,
    nil,
    function(subject, reason) FailureNotice.show(subject, reason) end)
end)

-- The context is recorded read-only for attachment/timing work. The adapter
-- still receives the actual move at AnimPlayer:start, which remains the
-- authoritative trigger for queue ownership.
mod.events:on("battle.move_used", function(payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.setMoveContext then player:setMoveContext(payload) end
  Announcer.moveUsed(payload)
end)

-- Damage is calculated while Gen1Recomp is building the queue. Retain its
-- target and effectiveness now, then ask Dramaless Shape for the skeletal
-- reaction only when this move's authored impact frame is reached.
mod.events:on("battle.damage_dealt", function(payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.recordDamage then player:recordDamage(payload) end
  Announcer.damageDealt(payload)
end)

mod.events:on("battle.battler_switched", Announcer.battlerSwitched)
mod.events:on("battle.status_inflicted", Announcer.statusInflicted)
mod.events:on("battle.fainted", Announcer.fainted)

mod.events:on("battle.ended", function(payload)
  Announcer.finishBattle(payload)
  AttackCinematics.stop()
  StadiumScreenFx.clear()
  StadiumScreenFx.setBorderless(false)
end)

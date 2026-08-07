-- Stadium Attack Animations: portable Stadium move effects for Gen1Recomp.

local mod = ...

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
local EffectCacheScreen = namespace.require("EffectCacheScreen")
local AttackCinematics = namespace.require("AttackCinematics")

mod.options:define({
  { key = "enabled", label = "STADIUM FX", type = "toggle", default = true },
  { key = "attack_camera", label = "ATTACK CAMERA", type = "toggle", default = true },
})

mod.exports.version = "0.5.0"
mod.exports.rom = StadiumRom
mod.exports.thunderShock = ThunderShockSpec
mod.exports.moves = MoveSpecs
mod.exports.attackCinematics = AttackCinematics.status
mod.exports.textureStatus = StadiumAssets.status
mod.exports.dramaticShape = function()
  return mod.find("DRAMATIC_SHAPE")
end
mod.exports.battleCinematics = function()
  return mod.find("BATTLE_CINEMATICS")
end

-- Offer the one-time cache build only after the real overworld owns the
-- stack. The fixed-step seam supplies the live Game object on desktop and
-- Android, including configurations that do not enable a render pipeline.
mod.hooks:wrap("input.step", function(next, game, dt)
  local result = next(game, dt)
  if mod.options:get("enabled") ~= false then
    local ok, err = pcall(EffectCacheScreen.maybePush, game)
    if not ok then mod.log:warn("attack cache screen unavailable: %s", tostring(err)) end
  end
  return result
end)

-- BattleState creates one AnimPlayer per battle. Replacing that instance with
-- a narrow adapter preserves the engine's queue/draw contract and also lets
-- Dramatic Shapes keep transforming the ordinary animation layer. The
-- adapter now owns a presentation for the complete 165-move Gen 1 roster.
mod.events:on("battle.started", function(payload)
  local battle = payload and payload.battle
  if not (battle and battle.animPlayer) then return end
  if getmetatable(battle.animPlayer) == StadiumFxPlayer then return end

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

  battle.animPlayer = StadiumFxPlayer.new(
    battle.animPlayer,
    function() return mod.options:get("enabled") ~= false end,
    mod.log,
    function() return mod.find("DRAMATIC_SHAPE") end,
    function() return mod.find("BATTLE_CINEMATICS") end,
    function() return mod.options:get("attack_camera") ~= false end)
end)

-- The context is recorded read-only for attachment/timing work. The adapter
-- still receives the actual move at AnimPlayer:start, which remains the
-- authoritative trigger for queue ownership.
mod.events:on("battle.move_used", function(payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.setMoveContext then player:setMoveContext(payload) end
end)

mod.events:on("battle.ended", function()
  AttackCinematics.stop()
end)

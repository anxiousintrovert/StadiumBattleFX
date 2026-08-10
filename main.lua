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

mod.exports.version = "1.0.7"

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
local StadiumLog = namespace.require("StadiumLog")
namespace.log = StadiumLog.new(mod.log)
local ThunderShockSpec = namespace.require("effects/ThunderShockSpec")
local StadiumAssets = namespace.require("StadiumAssets")
local MoveSpecs = namespace.require("effects/MoveSpecs")
local StadiumFxPlayer = namespace.require("effects/StadiumFxPlayer")
local StadiumScreenFx = namespace.require("effects/StadiumScreenFx")
local EffectCacheScreen = namespace.require("EffectCacheScreen")
local StadiumRomPicker = namespace.require("StadiumRomPicker")
local AttackCinematics = namespace.require("AttackCinematics")
local DramaticShapeFaint = namespace.require("DramaticShapeFaint")
local Announcer = namespace.require("Announcer")
local FailureNotice = namespace.require("FailureNotice")
local StadiumLogExport = namespace.require("StadiumLogExport")

local function dramalessCompanion()
  return mod.find("DRAMALESS_SHAPE")
end

mod.options:define({
  { key = "enabled", label = "STADIUM FX", type = "toggle", default = true },
  { key = "attack_camera", label = "ATTACK CAMERA", type = "toggle", default = true },
  { key = "attack_speed", label = "ATTACK SPEED", type = "choice", default = "100",
    choices = {
      { "100%", "100" }, { "90%", "90" }, { "80%", "80" },
      { "70%", "70" }, { "60%", "60" }, { "50%", "50" },
      { "40%", "40" }, { "30%", "30" }, { "20%", "20" },
      { "10%", "10" }, { "0% (OFF)", "0" },
    } },
  { key = "announcer", label = "STADIUM ANNOUNCER", type = "toggle", default = true },
  { key = "battle_cinematics_zoom", label = "BC ZOOM OUT", type = "choice",
    default = "off",
    choices = {
      { "OFF", "off" }, { "10%", "10" }, { "25%", "25" },
      { "35%", "35" }, { "50%", "50" },
    } },
})

mod.exports.rom = StadiumRom
mod.exports.thunderShock = ThunderShockSpec
mod.exports.moves = MoveSpecs
mod.exports.attackCinematics = AttackCinematics.status
mod.exports.textureStatus = StadiumAssets.status
mod.exports.announcerStatus = Announcer.status
mod.exports.faintStatus = DramaticShapeFaint.status
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
  -- Android's Storage Access Framework returns from the picker asynchronously.
  -- Poll before first-run detection so an imported ROM can start its cache
  -- build on the very frame the app regains focus.
  pcall(StadiumRomPicker.poll, game)
  if mod.options:get("enabled") ~= false then
    local ok, err = pcall(EffectCacheScreen.maybePush, game)
    if not ok then namespace.log:warn("attack cache screen unavailable: %s", tostring(err)) end
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
  namespace.log:info("battle started; animation adapter=%s", battle and battle.animPlayer and "available" or "missing")
  Announcer.beginBattle(battle)
  if not (battle and battle.animPlayer) then return end
  if getmetatable(battle.animPlayer) == StadiumFxPlayer then return end
  local options = battle.game and battle.game.save and battle.game.save.options
  StadiumScreenFx.setBorderless(options and options.videoMode == "borderless")

  if mod.options:get("enabled") ~= false then
    local ready, err = StadiumAssets.preload()
    if ready then
      local status = StadiumAssets.status()
      namespace.log:info("loaded %d Stadium effect primitives from %s",
        tonumber(status.assets) or 0, tostring(status.source or "runtime"))
    else
      namespace.log:warn("Stadium cartridge textures unavailable; procedural FX "
        .. "remain enabled: %s", tostring(err))
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
    namespace.log,
    dramalessCompanion,
    function() return mod.find("BATTLE_CINEMATICS") end,
    function() return mod.options:get("attack_camera") ~= false end,
    nil,
    function(subject, reason) FailureNotice.show(subject, reason) end,
    function()
      return (tonumber(mod.options:get("attack_speed")) or 100) / 100
    end)
end)

-- These are actions, not persisted mod settings: importing replaces the
-- player-owned ROM and rebuilding refreshes derived cache data immediately.
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  out[#out + 1] = StadiumRomPicker.importRow()
  out[#out + 1] = StadiumRomPicker.refreshRow()
  out[#out + 1] = StadiumLogExport.row()
  return out
end)

-- The context is recorded read-only for attachment/timing work. The adapter
-- still receives the actual move at AnimPlayer:start, which remains the
-- authoritative trigger for queue ownership.
mod.events:on("battle.move_used", function(payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.setMoveContext then player:setMoveContext(payload) end
  local move = payload and payload.move
  namespace.log:info("move used: id=%s called=%s", tostring(move and (move.index or move.id)), tostring(payload and payload.isCalled == true))
  Announcer.moveUsed(payload)
end)

-- Damage is calculated while Gen1Recomp is building the queue. Retain its
-- target and effectiveness now, then ask Dramaless Shape for the skeletal
-- reaction only when this move's authored impact frame is reached.
mod.events:on("battle.damage_dealt", function(payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.recordDamage then player:recordDamage(payload) end
  namespace.log:info("damage event: move=%s damage=%s multiplier=%s", tostring(payload and payload.move and (payload.move.index or payload.move.id)), tostring(payload and payload.damage), tostring(payload and payload.typeMult))
  Announcer.damageDealt(payload)
end)

mod.events:on("battle.battler_switched", Announcer.battlerSwitched)
mod.events:on("battle.status_inflicted", Announcer.statusInflicted)
-- Dramaless Shape owns the model clip and waits for the engine's HP drain.
-- We only forward the authoritative faint event, so the player's Pokemon
-- reaches its Stadium faint animation without racing the battle queue.
mod.events:on("battle.fainted", function(payload)
  Announcer.fainted(payload)

  local battle = payload and payload.battle
  local battler = payload and payload.battler
  local side
  if battler and battle then
    if battler == battle.player then side = "player"
    elseif battler == battle.enemy then side = "enemy" end
  end
  if not side then
    namespace.log:warn("faint event had no resolvable battle side")
    return
  end

  local disposition = DramaticShapeFaint.disposition(battle, battler)
  local ok, err = DramaticShapeFaint.request(dramalessCompanion, side, disposition)
  if ok then
    namespace.log:info("Stadium faint queued: side=%s disposition=%s", side, disposition)
  else
    namespace.log:info("Stadium faint unavailable: %s", tostring(err))
  end
end)

mod.events:on("battle.ended", function(payload)
  namespace.log:info("battle ended")
  Announcer.finishBattle(payload)
  AttackCinematics.stop()
  StadiumScreenFx.clear()
  StadiumScreenFx.setBorderless(false)
end)

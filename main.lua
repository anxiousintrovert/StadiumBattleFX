-- Stadium Attack Animations: portable Stadium move effects for Gen1Recomp.

local mod = ...

-- The repository doubles as a small LÖVE research harness. Gen1Recomp
-- supplies a mod object here; a direct `love .` launch does not.
if love and (type(mod) ~= "table" or type(mod.read) ~= "function") then
  return require("viewer.App")
end

local VERSION = "2.1.8.1"
mod.exports.version = VERSION

local namespace = { mod = mod, path = mod.path, engineRequire = require }
local modules = {}

local function moduleChunk(name)
  local rel = "lib/" .. name .. ".lua"
  local source = mod:read(rel)
  if not source then
    error(("STADIUM_BATTLE_FX: missing %s; reinstall the mod"):format(rel), 0)
  end
  -- Current Gen1Recomp sandboxes keep require available but no longer expose
  -- the mutable package table.  The embedded Stadium 2 importer used to
  -- register aliases in package.preload; give those chunks a private require
  -- instead so their original dotted module names stay isolated to this mod.
  if name:match("^stadium2/") then
    source = [[
local __sbfxNamespace = ...
local function require(name)
  local embedded = type(name) == "string" and
    name:match("^mods%.STADIUM_BATTLE_FX%.lib%.stadium2%.(.+)$")
  if embedded then
    return __sbfxNamespace.require("stadium2/" .. embedded:gsub("%.", "/"))
  end
  return __sbfxNamespace.engineRequire(name)
end
]] .. source
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
local ModStorage = namespace.require("ModStorage")
namespace.storage = ModStorage
-- Route the embedded Stadium 2 extractor through playthrough-scoped mod
-- storage. Neither the importer nor the mod receives a host filesystem path.
local STADIUM2_STORAGE = "stadium2/"
namespace.cacheWriter = {
  active = function() return ModStorage.active() end,
  read = function(path)
    return ModStorage.bytes(STADIUM2_STORAGE .. path)
  end,
  write = function(path, bytes)
    return ModStorage.writeBytes(STADIUM2_STORAGE .. path, bytes)
  end,
  ensure = function() return true end,
  clear = function(root, count)
    count = math.min(151, math.max(1, tonumber(count) or 151))
    ModStorage.delete(STADIUM2_STORAGE .. root .. "/pack.info")
    ModStorage.delete(STADIUM2_STORAGE .. root .. "/import_error.log")
    ModStorage.delete(STADIUM2_STORAGE .. root .. "/battle/substitute.dsm")
    for species = 1, count do
      local file = ("%03d.dsm"):format(species)
      ModStorage.delete(STADIUM2_STORAGE .. root .. "/normal/" .. file)
      ModStorage.delete(STADIUM2_STORAGE .. root .. "/shiny/" .. file)
    end
    return true
  end,
}
local StadiumLog = namespace.require("StadiumLog")
namespace.log = StadiumLog.new(mod.log)
local BattleProviders = namespace.require("BattleProviders")
local StadiumModelSources = namespace.require("StadiumModelSources")
local Stadium2Importer = namespace.require("stadium2/importer")
local Stadium2ModelPackApi = namespace.require("stadium2/model_pack_api")
Stadium2Importer.bind(mod)
-- Retain Stadium 2 pose bundles when building the locally derived cache.  The
-- shared Stadium renderer remains the draw backend; the hybrid source uses
-- Stadium 1 only when a Stadium 2 pose bundle cannot be decoded.
Stadium2Importer.configure({ count=151, meshOnly=false, includeUnownForms=false })
local stadium2SourceDefinition = {
  label = "STADIUM 2 (GEN 1 RIG)",
  embedded = true,
  available = function() return Stadium2ModelPackApi.available() end,
  load = function(species, variant, base)
    return Stadium2ModelPackApi.hybridModel(species, variant, base)
  end,
  -- Hybrid records are resident until invalidateHybrids(), so this source
  -- deliberately has no per-frame keep callback.
  invalidate = function() Stadium2ModelPackApi.invalidateHybrids() end,
}
-- Preserve the companion mod's old source id so existing saved selections
-- continue to resolve after installing the combined release.
local STADIUM2_SOURCE_ID = StadiumModelSources.register(
  "STADIUM2_IMPORTER", "gen1-model-pack", stadium2SourceDefinition)
local ThunderShockSpec = namespace.require("effects/ThunderShockSpec")
local StadiumAssets = namespace.require("StadiumAssets")
local StadiumArenaAssets = namespace.require("StadiumArenaAssets")
local StadiumTrainerPortraits = namespace.require("StadiumTrainerPortraits")
local ModelInstall = namespace.require("StadiumInstall")
local EffectCacheScreen = namespace.require("EffectCacheScreen")
local MoveSpecs = namespace.require("effects/MoveSpecs")
local StadiumFxPlayer = namespace.require("effects/StadiumFxPlayer")
local StadiumScreenFx = namespace.require("effects/StadiumScreenFx")
local AttackCinematics = namespace.require("AttackCinematics")
local DramaticShapeFaint = namespace.require("DramaticShapeFaint")
local Announcer = namespace.require("Announcer")
local FailureNotice = namespace.require("FailureNotice")
local StadiumLogExport = namespace.require("StadiumLogExport")
local StadiumArena = namespace.require("StadiumArena")
local StadiumModels = namespace.require("StadiumModels")
local StadiumModelProvider = namespace.require("StadiumModelProvider")
local StadiumModelApi = namespace.require("StadiumModelApi")
local BattleHost = namespace.require("BattleHost")
local BuiltinProviders = namespace.require("BuiltinProviders")
local BattleCinematicsCompat = namespace.require("BattleCinematicsCompat")
local BattleArtCompat = namespace.require("BattleArtCompat")

local function noLegacyCompanion() return nil end

local optionSchema = {
  { key = "enabled", label = "STADIUM FX", type = "toggle", default = true },
  { key = "trainer_portraits", label = "STADIUM TRAINER PORTRAITS",
    type = "toggle", default = true,
    help = "Replace opening trainer sprites with portraits imported from Pokemon Stadium." },
  { key = "attack_camera", label = "ATTACK CAMERA", type = "toggle", default = true },
  { key = "attack_speed", label = "ATTACK SPEED", type = "choice", default = "100",
    choices = {
      { "100%", "100" }, { "90%", "90" }, { "80%", "80" },
      { "70%", "70" }, { "60%", "60" }, { "50%", "50" },
      { "40%", "40" }, { "30%", "30" }, { "20%", "20" },
      { "10%", "10" }, { "0% (OFF)", "0" },
    } },
  { key = "announcer", label = "STADIUM ANNOUNCER", type = "toggle", default = true },
  { key = "announcer_scope", label = "ANNOUNCER BATTLES", type = "choice",
    default = "gym",
    choices = {
      { "GYM / ELITE 4 / CHAMPION", "gym" },
      { "ALL TRAINER BATTLES", "trainer" },
      { "ALL BATTLES", "all" },
    } },
  { key = "battle_cinematics_zoom", label = "BC ZOOM OUT", type = "choice",
    default = "off",
    choices = {
      { "OFF", "off" }, { "10%", "10" }, { "25%", "25" },
      { "35%", "35" }, { "50%", "50" },
    } },
  { key = "stadium2_shader", label = "MODEL SHADER", type = "choice",
    default = "stadium",
    choices = { { "STADIUM", "stadium" }, { "WATERCOLOR MANGA", "cel" } },
    help = "Shader used by the embedded Stadium 2 appearance pack." },
}
local modelSourceRow = StadiumModelSources.optionRow()
-- Stadium 2 appearances carry substantially more geometry than the Stadium 1
-- battle packs and are CPU-skinned by the shared runtime. Keep the lightweight
-- source as the safe default; players can opt into the imported appearance pack.
modelSourceRow.default = StadiumModelSources.DEFAULT
optionSchema[#optionSchema + 1] = modelSourceRow
for _, row in ipairs(BattleProviders.optionRows()) do
  optionSchema[#optionSchema + 1] = row
end
mod.options:define(optionSchema)

BattleProviders.setBuiltin("arena", StadiumArena, {
  description = "Automatic arena; Battle Art map stages or Stadium special arenas",
  available = function(context)
    if not StadiumArena:available(context) then return false end
    -- Battle Art is the ordinary map-backed stage when it is actively serving
    -- this battle.  Keep Stadium's authored boss rooms available, but do not
    -- silently fall back to a generic portable theme beneath an active map.
    if not StadiumArena.venueFor(context and context.battle)
        and BattleArtCompat.enabled() then
      return false
    end
    return true
  end,
})
BattleProviders.setBuiltin("models", StadiumModelProvider, {
  description = "Pokemon Stadium battle models, poses, attachments, and reactions",
  available = function() return StadiumModelProvider:available() end,
})
for slot, provider in pairs(BuiltinProviders) do
  BattleProviders.setBuiltin(slot, provider, {
    description = "StadiumBattleFX built-in " .. slot .. " provider",
  })
end
local modelsInstalled, modelInstallErr = pcall(StadiumModels.install)
if not modelsInstalled then
  namespace.log:warn("Stadium model engine hooks unavailable: %s", tostring(modelInstallErr))
end
local hostInstalled, hostInstallErr = pcall(BattleHost.install)
if not hostInstalled then
  namespace.log:warn("battle presentation host hooks unavailable: %s", tostring(hostInstallErr))
end

mod.exports.rom = StadiumRom
mod.exports.thunderShock = ThunderShockSpec
mod.exports.moves = MoveSpecs
mod.exports.attackCinematics = AttackCinematics.status
mod.exports.textureStatus = StadiumAssets.status
mod.exports.arenaStatus = StadiumArenaAssets.status
mod.exports.trainerPortraitStatus = StadiumTrainerPortraits.status
mod.exports.announcerStatus = Announcer.status
mod.exports.diagnosticLog = function() return namespace.log:contents() end
mod.exports.faintStatus = DramaticShapeFaint.status
mod.exports.arenaProvider = StadiumArena
mod.exports.modelProvider = StadiumModelProvider
mod.exports.models = StadiumModelApi
mod.exports.modelSources = {
  version = StadiumModelSources.VERSION,
  DEFAULT = StadiumModelSources.DEFAULT,
  register = function(_, owner, id, definition)
    return StadiumModelSources.register(owner, id, definition)
  end,
  list = function() return StadiumModelSources.list() end,
  selectedId = function() return StadiumModelSources.selectedId() end,
}
mod.exports.stadium2 = {
  version = "1",
  speciesCount = 151,
  sourceId = STADIUM2_SOURCE_ID,
  modelPack = Stadium2ModelPackApi,
  status = Stadium2Importer.status,
  available = Stadium2Importer.available,
  request = Stadium2Importer.request,
  beginFrom = Stadium2Importer.beginFrom,
  beginPath = Stadium2Importer.beginPath,
  modelPath = Stadium2Importer.modelPath,
  readPack = Stadium2Importer.readPack,
  parsePack = Stadium2Importer.parsePack,
  loadModel = Stadium2Importer.loadModel,
  releaseModels = Stadium2Importer.releaseModels,
  US_MD5 = Stadium2Importer.US_MD5,
  FORMAT = Stadium2Importer.FORMAT,
}
mod.exports.battles = {
  version = BattleProviders.VERSION,
  FALLBACK = BattleProviders.FALLBACK,
  enabled = function()
    return mod.options:get("enabled") ~= false
  end,
  registerComponent = function(_, owner, slot, id, definition)
    return BattleProviders.registerComponent(owner, slot, id, definition)
  end,
  componentList = function(_, slot) return BattleProviders.componentList(slot) end,
  selectedId = function(_, slot) return BattleProviders.selectedId(slot) end,
  resolve = function(_, slot, context) return BattleProviders.resolve(slot, context) end,
  isSelected = function(_, slot, id) return BattleProviders.isSelected(slot, id) end,
  slots = function() return BattleProviders.slots() end,
}

local function stadiumOwns(slot)
  return BattleProviders.resolve(slot) == BuiltinProviders[slot]
end

mod.exports.battleCinematics = function()
  return mod.find("BATTLE_CINEMATICS")
end
mod.exports.battleCinematicsCompatibility = BattleCinematicsCompat.status
mod.exports.externalBattleCompatibility = BattleArtCompat.status
-- Retained for consumers of the original single-backend export name.
mod.exports.battleArtCompatibility = BattleArtCompat.status

-- Offer the one-time cache build only after the real overworld owns the
-- stack. The fixed-step seam supplies the live Game object on desktop and
-- Android, including configurations that do not enable a render pipeline.
mod.hooks:wrap("input.step", function(next, game, dt)
  ModStorage.setGame(game)
  local result = next(game, dt)
  EffectCacheScreen.maybePush(game)
  BattleHost.update(dt)
  if stadiumOwns("announcer") then Announcer.update(dt, game) end
  FailureNotice.update(dt)
  return result
end)

-- Continue screen-wide move layers into desktop borderless margins after the
-- game canvas is composed. Anchored particles remain on the battle surface.
mod.hooks:wrap("render.hud", function(next, game, viewport)
  local result = next(game, viewport)
  if stadiumOwns("effects") then StadiumScreenFx.present(game, viewport) end
  FailureNotice.draw(viewport)
  return result
end)

-- BattleState creates one AnimPlayer per battle. Replacing that instance with
-- a narrow adapter preserves the engine's queue/draw contract. The adapter
-- owns a presentation for the complete 165-move Gen 1 roster.
mod.events:on("battle.started", function(payload)
  ModStorage.setGame(payload and (payload.game
    or (payload.battle and payload.battle.game)))
  local battle = payload and payload.battle
  -- Some UI mods finalize BattleState:draw after mods.loaded. Reattach at the
  -- battle boundary, before the first frame, if our wrapper was displaced.
  local hookOk, hookErr = pcall(BattleHost.install, true)
  if not hookOk then
    namespace.log:warn("battle presentation host reattachment failed: %s",
      tostring(hookErr))
  elseif hookErr then
    namespace.log:info("battle presentation host reattached at battle start")
  end
  -- A disabled Stadium FX must leave all presentation ownership with the
  -- engine (or another mod).  Providers may remain registered for the next
  -- enabled battle, but no SBFX session is created while this switch is off.
  if mod.options:get("enabled") ~= false then
    BattleHost.begin(battle, mod.options:get("trainer_portraits") ~= false)
  end
  namespace.log:info("battle started; animation adapter=%s", battle and battle.animPlayer and "available" or "missing")
  if stadiumOwns("announcer") then Announcer.beginBattle(battle) end
  if not (battle and battle.animPlayer) then return end
  if not (stadiumOwns("animations") and stadiumOwns("effects")) then return end
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
    noLegacyCompanion,
    function() return mod.find("BATTLE_CINEMATICS") end,
    function()
      if mod.options:get("enabled") == false then return "off" end
      return mod.options:get("battle_cinematics_zoom") or "off"
    end)

  battle.animPlayer = StadiumFxPlayer.new(
    battle.animPlayer,
    function() return mod.options:get("enabled") ~= false end,
    namespace.log,
    noLegacyCompanion,
    function() return mod.find("BATTLE_CINEMATICS") end,
    function()
      return stadiumOwns("camera")
        and mod.options:get("attack_camera") ~= false
        and not BattleArtCompat.active(battle)
    end,
    nil,
    function(subject, reason) FailureNotice.show(subject, reason) end,
    function()
      return (tonumber(mod.options:get("attack_speed")) or 100) / 100
    end)
end)

local function cacheRefreshRow()
  return {
    id = "STADIUM_BATTLE_FX:refreshCache",
    label = "REBUILD STADIUM CACHE",
    value = function()
      local states = {
        StadiumAssets.status().state,
        StadiumArenaAssets.status().state,
        StadiumTrainerPortraits.status().state,
        ModelInstall.status.state,
        Stadium2Importer.status().state,
        Announcer.cacheStatus().state,
      }
      for _, state in ipairs(states) do
        if state == "building" then return "BUILDING" end
      end
      return "REBUILD"
    end,
    activate = function(game)
      if not (game and game.stack and game.stack.push) then return false end
      game.stack:push(EffectCacheScreen.new(game, true))
      return true
    end,
  }
end

-- Rebuild only from ROMs already supplied to the mod manager. The sandbox
-- owns all real paths; this action never opens a picker or writes a host file.
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  out[#out + 1] = cacheRefreshRow()
  out[#out + 1] = StadiumLogExport.row()
  return out
end)

-- The context is recorded read-only for attachment/timing work. The adapter
-- still receives the actual move at AnimPlayer:start, which remains the
-- authoritative trigger for queue ownership.
mod.events:on("battle.move_used", function(payload)
  BattleHost.event("battle.move_used", payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.setMoveContext then player:setMoveContext(payload) end
  local move = payload and payload.move
  namespace.log:info("move used: id=%s called=%s", tostring(move and (move.index or move.id)), tostring(payload and payload.isCalled == true))
  if stadiumOwns("announcer") then Announcer.moveUsed(payload) end
end)

-- Damage is calculated while Gen1Recomp is building the queue. Retain its
-- target and effectiveness now, then ask the local Stadium model for the skeletal
-- reaction only when this move's authored impact frame is reached.
mod.events:on("battle.damage_dealt", function(payload)
  BattleHost.event("battle.damage_dealt", payload)
  local battle = payload and payload.battle
  local player = battle and battle.animPlayer
  if player and player.recordDamage then player:recordDamage(payload) end
  namespace.log:info("damage event: move=%s damage=%s multiplier=%s", tostring(payload and payload.move and (payload.move.index or payload.move.id)), tostring(payload and payload.damage), tostring(payload and payload.typeMult))
  if stadiumOwns("announcer") then Announcer.damageDealt(payload) end
end)

mod.events:on("battle.turn_started", function(payload)
  BattleHost.event("battle.turn_started", payload)
end)

mod.events:on("battle.turn_ended", function(payload)
  BattleHost.event("battle.turn_ended", payload)
end)

mod.events:on("battle.battler_switched", function(payload)
  BattleHost.event("battle.battler_switched", payload)
  if stadiumOwns("announcer") then Announcer.battlerSwitched(payload) end
end)
mod.events:on("battle.status_inflicted", function(payload)
  BattleHost.event("battle.status_inflicted", payload)
  if stadiumOwns("announcer") then Announcer.statusInflicted(payload) end
end)
-- StadiumBattleFX owns the model clip and waits for the engine's HP drain.
-- We only forward the authoritative faint event, so the player's Pokemon
-- reaches its Stadium faint animation without racing the battle queue.
mod.events:on("battle.fainted", function(payload)
  BattleHost.event("battle.fainted", payload)
  if stadiumOwns("announcer") then Announcer.fainted(payload) end

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
  local ok, err = DramaticShapeFaint.request(noLegacyCompanion, side, disposition)
  if ok then
    namespace.log:info("Stadium faint queued: side=%s disposition=%s", side, disposition)
  else
    namespace.log:info("Stadium faint unavailable: %s", tostring(err))
  end
end)

mod.events:on("mods.loaded", function()
  if type(BattleArtCompat.refresh) == "function" then BattleArtCompat.refresh() end
  -- UI mods may replace BattleState:draw after StadiumBattleFX first loads.
  -- Re-chain against the final method once the complete mod set is known so
  -- the battle world compositor remains the outer owner of the frame.
  local installed, installErr = pcall(BattleHost.install, true)
  if not installed then
    namespace.log:warn("battle presentation host finalization failed: %s",
      tostring(installErr))
  else
    namespace.log:info("battle presentation host finalized after mod loading")
  end
  -- Battle Cinematics wraps its supported renderer's shared BattleCam table.
  -- Once every mod has installed its hooks, advertise that untouched wrapped
  -- camera in the same player-facing catalog as native API-1 providers.
  local cinematicCamera = BattleCinematicsCompat.registerProvider(BattleProviders)
  if cinematicCamera then
    namespace.log:event("providers", "compatibility-registered", {
      slot = "camera", id = cinematicCamera,
    })
  end
  local removed = BattleProviders.pruneInactive()
  namespace.log:event("providers", "registry-finalized", { removed = removed })
  for _, slot in ipairs(BattleProviders.slots()) do
    namespace.log:event("providers", "slot", {
      id = slot.id,
      selected = BattleProviders.selectedId(slot.id),
      external = #BattleProviders.componentList(slot.id),
    })
  end
end)

mod.events:on("battle.ended", function(payload)
  namespace.log:info("battle ended")
  BattleHost.event("battle.ended", payload)
  if stadiumOwns("announcer") then Announcer.finishBattle(payload) end
  AttackCinematics.stop()
  StadiumScreenFx.clear()
  StadiumScreenFx.setBorderless(false)
  BattleHost.finish("battle.ended")
end)

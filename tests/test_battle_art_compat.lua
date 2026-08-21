local loader = love and love.filesystem and love.filesystem.load or loadfile

local activeBattle = {}
local shot = {
  player = { 34, 91 }, enemy = { 126, 51 },
  canvas = { getDimensions = function() return 1280, 720 end },
}
local overworldBattle = {
  ANCHOR = { player = { 26, 96 }, enemy = { 124, 56 } },
  enabled = function() return true end,
  battle = function() return activeBattle end,
  shot = function() return shot end,
  backPinned = function() return false end,
  animScale = function(got, px, py)
    assert(got == shot and type(px) == "number" and type(py) == "number")
    return 0.8
  end,
}
local stageReady = false
local legacyRequireCalls = 0
local battleStage = {
  apiVersion = 1,
  sourceModId = "BATTLE_ART_VOXEL_FORK",
  enabled = function() return true end,
  state = function(expected)
    if expected ~= nil and expected ~= activeBattle then return nil end
    local state = {
      apiVersion = 1,
      sourceModId = "BATTLE_ART_VOXEL_FORK",
      battle = activeBattle,
      staged = true,
      ready = false,
      ownership = {
        arena = true, battlers = true, trainers = true, camera = true,
        hud = true, transition = true, animationProjection = true,
      },
      surfaceOwned = true,
      externalCamera = true,
      layerOwnsProjection = true,
    }
    if not stageReady or not shot then return state end
    local player = overworldBattle.backPinned() and { 26, 96 }
      or { shot.player[1], shot.player[2] }
    local enemy = { shot.enemy[1], shot.enemy[2] }
    local scale = overworldBattle.animScale(shot, player[1], player[2])
    state.ready = true
    state.backPinned = overworldBattle.backPinned()
    state.animationScale = scale
    state.authoredAnchors = { player = { 26, 96 }, enemy = { 124, 56 } }
    state.projectedAnchors = { player = player, enemy = enemy }
    state.layerTransform = {
      authoredCenter = { 75, 76 },
      projectedCenter = {
        (player[1] + enemy[1]) / 2, (player[2] + enemy[2]) / 2,
      },
      scale = scale,
    }
    return state
  end,
}
local handle = {
  version = "1.8.8",
  exports = {
    version = "1.8.8",
    battlePresentation = { apiVersion = 1 },
    battleStage = battleStage,
    lib = { require = function(name)
      legacyRequireCalls = legacyRequireCalls + 1
      assert(name == "OverworldBattle")
      return overworldBattle
    end },
  },
}
local handles = { BATTLE_ART_VOXEL_FORK = handle }
local findCalls = 0
local Compat = assert(loader("lib/BattleArtCompat.lua"))({
  mod = { find = function(id)
    findCalls = findCalls + 1
    local found = handles[id]
    -- Match Gen1Recomp: every lookup returns a fresh handle wrapper.
    return found and { id=id, version=found.version, exports=found.exports } or nil
  end },
})

assert(Compat.installed() and Compat.enabled())
assert(Compat.ownsBattle(activeBattle),
  "staged battle was not claimed before its first projected shot")
assert(not Compat.active(activeBattle),
  "staged-but-not-ready public state became an active projection")
assert(not Compat.ownsBattle({}), "public API claimed a different battle")
assert(legacyRequireCalls == 0,
  "stable battleStage API did not prevent private module discovery")

stageReady = true
assert(Compat.active(activeBattle))
local resolvedCalls = findCalls
assert(Compat.owner(activeBattle) == "BATTLE_ART_VOXEL_FORK")
assert(Compat.presentationState(activeBattle))
assert(findCalls == resolvedCalls,
  "frame-time ownership queries repeated mod discovery")
assert(not Compat.ownsBattle({}) and not Compat.active({}))
local state = assert(Compat.presentationState())
assert(state.owner == "BATTLE_ART_VOXEL_FORK" and state.surfaceOwned)
assert(state.projectedAnchors.player[1] == 34)
assert(state.projectedAnchors.enemy[2] == 51)
assert(state.animationScale == 0.8)
assert(state.layerTransform.authoredCenter[1] == 75)
assert(state.layerTransform.authoredCenter[2] == 76)
assert(state.layerTransform.projectedCenter[1] == 80)
assert(state.layerTransform.projectedCenter[2] == 71)
assert(state.ownership.animationProjection,
  "public presentation ownership was not retained")
assert(Compat.status().backends[1].stageApiVersion == 1,
  "public staged-battle API version was not reported")
assert(legacyRequireCalls == 0,
  "public staged-battle reads fell back to the private module")

overworldBattle.backPinned = function() return true end
state = assert(Compat.presentationState())
assert(state.backPinned and state.projectedAnchors.player[1] == 26
    and state.projectedAnchors.player[2] == 96,
  "pinned player card did not retain its authored Game Boy anchor")
assert(state.layerTransform.projectedCenter[1] == 76)

shot = nil
assert(not Compat.active(activeBattle) and Compat.presentationState() == nil)
local status = Compat.status()
assert(status.installed and status.version == "1.8.8" and not status.active)

-- Older Battle Art versions remain supported through the original read-only
-- OverworldBattle lookup when no versioned battleStage export is present.
shot = {
  player = { 34, 91 }, enemy = { 126, 51 },
  canvas = { getDimensions = function() return 1280, 720 end },
}
handles.BATTLE_ART_VOXEL_FORK = {
  version = "1.8.7",
  exports = { version = "1.8.7", lib = handle.exports.lib },
}
Compat.refresh()
state = assert(Compat.presentationState(activeBattle))
assert(state.version == "1.8.7" and state.projectedAnchors.player[1] == 26,
  "older Battle Art did not use the legacy compatibility fallback")
assert(legacyRequireCalls == 1,
  "legacy fallback did not resolve OverworldBattle exactly once")

-- Dramatic Shape publishes the same presentation API. Prefer the loader's
-- manifest version because its exports.version remains a historical value.
shot = {
  player = { 30, 94 }, enemy = { 120, 54 },
  canvas = { getDimensions = function() return 1280, 720 end },
}
handles.BATTLE_ART_VOXEL_FORK = nil
handles.DRAMATIC_SHAPE = {
  version = "1.8.2",
  exports = { version = "1.5.5", lib = handle.exports.lib },
}
Compat.refresh()
state = assert(Compat.presentationState(activeBattle))
assert(state.owner == "DRAMATIC_SHAPE" and state.ownerLabel == "Dramatic Shape")
assert(state.version == "1.8.2", "stale Shape exports.version won over manifest version")
assert(Compat.owner(activeBattle) == "DRAMATIC_SHAPE")

handles.DRAMATIC_SHAPE = nil
handles.DRAMALESS_SHAPE = {
  version = "2.0.2",
  exports = { version = "2.0.2", lib = handle.exports.lib },
}
Compat.refresh()
state = assert(Compat.presentationState(activeBattle))
assert(state.owner == "DRAMALESS_SHAPE" and state.ownerLabel == "Dramaless Shape")
assert(state.version == "2.0.2")
assert(Compat.ownsBattle(activeBattle),
  "Dramaless fallback did not claim its staged battle before the first shot")

handles.DRAMALESS_SHAPE = nil
handles.potato_voxel = {
  version = "1.5.2",
  exports = { version = "1.6.2-brick.17", lib = handle.exports.lib },
}
Compat.refresh()
state = assert(Compat.presentationState(activeBattle))
assert(state.owner == "potato_voxel" and state.ownerLabel == "PotatoVoxel")
assert(Compat.status().version == "1.5.2")

print("ok Shape-family read-only presentation bridge")

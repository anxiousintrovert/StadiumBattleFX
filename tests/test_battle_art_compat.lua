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
    assert(got == shot and px == 34 and py == 91)
    return 0.8
  end,
}
local handle = {
  version = "1.8.7",
  exports = {
    version = "1.8.7",
    battlePresentation = { apiVersion = 1 },
    lib = { require = function(name)
      assert(name == "OverworldBattle")
      return overworldBattle
    end },
  },
}
local Compat = assert(loader("lib/BattleArtCompat.lua"))({
  mod = { find = function(id)
    assert(id == "BATTLE_ART_VOXEL_FORK")
    return handle
  end },
})

assert(Compat.installed() and Compat.enabled())
assert(Compat.ownsBattle(activeBattle) and Compat.active(activeBattle))
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

overworldBattle.backPinned = function() return true end
state = assert(Compat.presentationState())
assert(state.backPinned and state.projectedAnchors.player[1] == 26
    and state.projectedAnchors.player[2] == 96,
  "pinned player card did not retain its authored Game Boy anchor")
assert(state.layerTransform.projectedCenter[1] == 76)

shot = nil
assert(not Compat.active(activeBattle) and Compat.presentationState() == nil)
local status = Compat.status()
assert(status.installed and status.version == "1.8.7" and not status.active)
print("ok Battle Art read-only presentation bridge")

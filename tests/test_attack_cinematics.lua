local loader = love and love.filesystem and love.filesystem.load or loadfile
local stageMode = "B"
local cameraRow
local Stadium = {
  mode = function() return stageMode end,
  moveSync = function() return cameraRow end,
}
local Director = assert(loader("lib/AttackCinematics.lua"))({
  require = function(name) assert(name == "StadiumModels"); return Stadium end,
})

local BattleCam = {}
function BattleCam.rig(_, _, _)
  return {
    eye = { 0, 55, 95 },
    focus = { 0, 7, 0 },
    fov = math.rad(42),
    curve = 0,
  }, 0.8
end

local companion = function()
  return {
    exports = {
      lib = {
        require = function(name)
          if name == "BattleCam" then return BattleCam end
          if name == "Stadium" then return Stadium end
          error(name)
        end,
      },
    },
  }
end
local zoomOption = "25"
local cameraAvailable = true
local attackClaim = false
local ownershipMode = "valid"
local cameraCompanion = function()
  if not cameraAvailable then return nil end
  local query
  if ownershipMode == "valid" then
    query = function()
      return { protocol = 1, claims = { attack = attackClaim } }
    end
  elseif ownershipMode == "error" then
    query = function() error("ownership unavailable") end
  elseif ownershipMode == "future" then
    query = function()
      return { protocol = 2, claims = { attack = true } }
    end
  end
  return { exports = { version = "0.7.1", cameraOwnership = query } }
end

local arena = { player = { -24, 0 }, enemy = { 24, 0 } }
local function shot(canonical)
  local base = BattleCam.rig(arena, 0, canonical)
  if canonical then return base end
  return Director.camera(base, arena, 0)
end
local spec = {
  id = 15, key = "CUT", power = 50, impactAt = 38, duration = 72,
  cinematic = "melee", anchor = "target",
}

assert(Director.profileFor(spec) == "melee")
assert(Director.configure(companion, cameraCompanion, function() return zoomOption end),
  "Battle Cinematics compatibility did not install")
for _, percent in ipairs({ 10, 25, 35, 50 }) do
  zoomOption = tostring(percent)
  local widened = shot(false)
  local expectedFov = 2 * math.atan(
    math.tan(math.rad(42) / 2) * (1 + percent / 100))
  assert(math.abs(widened.fov - expectedFov) < 1e-9,
    tostring(percent) .. "% compatibility zoom did not widen the optical frame")
end
zoomOption = "25"
local widenedStatus = Director.status()
assert(widenedStatus.compatibilityZoom == 0.25,
  "compatibility zoom was not exposed for diagnostics")

assert(Director.start(spec, true, companion), "disc cinematic did not start")
Director.setTick(20)
local directed = shot(false)
local compatibilityFov = 2 * math.atan(
  math.tan(math.rad(42) / 2) * (1 + 0.25))
local safeAttackFov = compatibilityFov * 1.18
assert(directed.fov >= safeAttackFov - 1e-9,
  "attack shot did not retain its animation headroom")
assert(directed.focus[1] < 0, "windup shot did not favor the attacker")
assert(directed.focus[2] > 7,
  "windup shot did not aim high enough for hovering Pokemon")
assert(directed.eye[1] ~= 0 or directed.eye[3] ~= 95,
  "disc shot did not apply its safe orbit")

cameraRow = {
  species = 25, byte_0D = 3, byte_0E = 7, byte_0F = 9,
}
assert(Director.start(spec, true, companion), "native camera did not start")
assert(Director.status().nativeCamera == true
  and Director.status().selector == 3,
  "species/move camera row did not select its initial native shot")
local nativeShot = shot(false)
assert(math.abs(nativeShot.fov - math.rad(30)) < 1e-9,
  "native Stadium attack lens was not applied")
Director.setTick(8)
assert(Director.status().selector == 3,
  "native camera changed before its row delay")
Director.setTick(9)
assert(Director.status().selector == 7,
  "native camera did not change on the exact row delay")
cameraRow.byte_0E = 25
assert(Director.start(spec, true, companion), "preserve camera row did not start")
Director.setTick(60)
assert(Director.status().selector == 3,
  "native selector 25 did not preserve the current camera")
cameraRow = nil

Director.stop()
local aerial = {
  id = 19, key = "FLY", power = 90, impactAt = 38, duration = 72,
  cinematic = "aerial", anchor = "target",
}
assert(Director.start(aerial, true, companion), "aerial cinematic did not start")
Director.setTick(20)
local aerialShot = shot(false)
local safeAerialFov = compatibilityFov * 1.30
assert(aerialShot.fov >= safeAerialFov - 1e-9,
  "aerial shot did not retain its extra vertical headroom")

attackClaim = true
local yielded = shot(false)
assert(yielded.focus[1] == 0 and yielded.eye[1] == 0 and yielded.eye[3] == 95,
  "director did not release an active shot when BC acquired the attack claim")
assert(not Director.status().active
       and Director.status().externalAttackClaimed == true,
  "released ownership was not exposed for diagnostics")
assert(not Director.start(spec, true, companion),
  "director started while BC held the attack claim")

attackClaim = false
assert(Director.start(spec, true, companion),
  "director did not resume after BC released the attack claim")

ownershipMode = "future"
assert(Director.start(spec, true, companion),
  "unknown ownership protocols must fail open")
ownershipMode = "error"
assert(Director.start(spec, true, companion),
  "ownership query failures must fail open")
ownershipMode = "missing"
assert(Director.start(spec, true, companion),
  "a missing ownership export must retain legacy behavior")
ownershipMode = "valid"

local canonical = shot(true)
assert(canonical.fov == math.rad(42), "canonical rig must remain untouched")
assert(canonical.eye[1] == 0 and canonical.eye[3] == 95,
  "canonical eye must remain untouched")

stageMode = "A"
assert(Director.start(spec, false, companion), "map cinematic did not start")
Director.setTick(20)
local mapShot = shot(false)
assert(mapShot.eye[1] == 0 and mapShot.eye[3] == 95,
  "map shot must use optical movement instead of camera travel")
assert(mapShot.focus[1] > 0, "enemy windup did not mirror toward its attacker")

Director.stop()
zoomOption = "off"
local stopped = shot(false)
assert(stopped.fov == math.rad(42), "stopped director still changed the rig")

zoomOption = "50"
cameraAvailable = false
local withoutCompanion = shot(false)
assert(withoutCompanion.fov == math.rad(42),
  "compatibility zoom applied without Battle Cinematics")

print("ok attack cinematic profiles")

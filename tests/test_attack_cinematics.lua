local loader = love and love.filesystem and love.filesystem.load or loadfile
local Director = assert(loader("lib/AttackCinematics.lua"))()

local stageMode = "B"
local BattleCam = {}
function BattleCam.rig(_, _, _)
  return {
    eye = { 0, 55, 95 },
    focus = { 0, 7, 0 },
    fov = math.rad(42),
    curve = 0,
  }, 0.8
end

local Stadium = { mode = function() return stageMode end }
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
local cameraCompanion = function()
  return cameraAvailable and { exports = { version = "0.7.1" } } or nil
end

local arena = { player = { -24, 0 }, enemy = { 24, 0 } }
local spec = {
  id = 15, key = "CUT", power = 50, impactAt = 38, duration = 72,
  cinematic = "melee", anchor = "target",
}

assert(Director.profileFor(spec) == "melee")
assert(Director.configure(companion, cameraCompanion, function() return zoomOption end),
  "Battle Cinematics compatibility did not install")
for _, percent in ipairs({ 10, 25, 35, 50 }) do
  zoomOption = tostring(percent)
  local widened = BattleCam.rig(arena, 0, false)
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
local directed = BattleCam.rig(arena, 0, false)
assert(directed.fov < math.rad(42), "attack shot did not tighten its lens")
assert(directed.focus[1] < 0, "windup shot did not favor the attacker")
assert(directed.eye[1] ~= 0 or directed.eye[3] ~= 95,
  "disc shot did not apply its safe orbit")

local canonical = BattleCam.rig(arena, 0, true)
assert(canonical.fov == math.rad(42), "canonical rig must remain untouched")
assert(canonical.eye[1] == 0 and canonical.eye[3] == 95,
  "canonical eye must remain untouched")

stageMode = "A"
assert(Director.start(spec, false, companion), "map cinematic did not start")
Director.setTick(20)
local mapShot = BattleCam.rig(arena, 0, false)
assert(mapShot.eye[1] == 0 and mapShot.eye[3] == 95,
  "map shot must use optical movement instead of camera travel")
assert(mapShot.focus[1] > 0, "enemy windup did not mirror toward its attacker")

Director.stop()
zoomOption = "off"
local stopped = BattleCam.rig(arena, 0, false)
assert(stopped.fov == math.rad(42), "stopped director still changed the rig")

zoomOption = "50"
cameraAvailable = false
local withoutCompanion = BattleCam.rig(arena, 0, false)
assert(withoutCompanion.fov == math.rad(42),
  "compatibility zoom applied without Battle Cinematics")

print("ok attack cinematic profiles")

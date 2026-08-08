-- Move-time camera director for staged Dramaless Shape battles.
--
-- Stadium's move presentation is not a single animation blob.  Species body
-- motion, primary VFX, defender/impact VFX, and camera state run alongside
-- one another.  This module owns only the last layer.  It wraps the public
-- Dramaless Shape BattleCam rig lazily and leaves its canonical/clearance
-- queries untouched.

local Director = {}

local active
local installed = false
local cameraCompanion
local compatibilityZoomOption = function() return "off" end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function mix(a, b, amount)
  return a + (b - a) * amount
end

local function smooth(value)
  value = clamp(value, 0, 1)
  return value * value * (3 - 2 * value)
end

local function copy3(value)
  return { value[1], value[2], value[3] }
end

local function compatibilityZoom()
  if type(cameraCompanion) ~= "function" then return 0 end
  local foundOk, found = pcall(cameraCompanion)
  if not foundOk then return 0 end
  local exports = found and found.exports
  if not (exports and exports.version) then return 0 end
  local ok, value = pcall(compatibilityZoomOption)
  if not ok then return 0 end
  return clamp((tonumber(value) or 0) / 100, 0, 0.50)
end

local function widenBattleCinematics(base, pitch, canonical)
  local amount = compatibilityZoom()
  if canonical or amount <= 0 or type(base) ~= "table"
     or type(base.fov) ~= "number" then
    return base, pitch
  end

  -- Scale the visible frame rather than the angle itself. This is a true
  -- optical zoom-out and keeps Battle Cinematics' collision-safe eye path and
  -- focus point intact. A new table also avoids mutating its cached rig.
  local widened = {}
  for key, value in pairs(base) do widened[key] = value end
  widened.fov = clamp(
    2 * math.atan(math.tan(base.fov / 2) * (1 + amount)),
    math.rad(15), math.rad(90))
  return widened, pitch
end

local function cameraProfile(spec)
  return spec and spec.cinematic or "ranged"
end

-- Segments are expressed relative to the portable effect clock.  Their
-- boundaries intentionally line up with the primary/impact split already in
-- MoveSpecs; moves may share a camera timeline without sharing VFX or body
-- animation data.
local function segmentsFor(spec)
  local impact = math.max(12, tonumber(spec.impactAt) or 38)
  local duration = math.max(impact + 12, tonumber(spec.duration) or impact + 34)
  local profile = cameraProfile(spec)
  local segments

  if profile == "melee" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.72, orbit = -0.035 },
      { at = impact * 0.52, subject = "center", zoom = 0.88, orbit = 0.025 },
      { at = impact, subject = "target", zoom = 0.66, shake = 1 },
      { at = impact + 16, subject = "center", zoom = 0.90 },
    }
  elseif profile == "combo" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.76 },
      { at = impact * 0.55, subject = "center", zoom = 0.88 },
      { at = impact, subject = "target", zoom = 0.69, shake = 1 },
      { at = impact + 10, subject = "center", zoom = 0.82, shake = 0.6 },
      { at = impact + 20, subject = "target", zoom = 0.65, shake = 1 },
    }
  elseif profile == "sustained" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.68, orbit = -0.025 },
      { at = impact * 0.40, subject = "center", zoom = 0.80 },
      { at = impact, subject = "target", zoom = 0.67, shake = 0.45 },
      { at = impact + 22, subject = "center", zoom = 0.86 },
    }
  elseif profile == "aerial" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.70 },
      { at = impact * 0.42, subject = "wide", zoom = 1.08, orbit = 0.075 },
      { at = impact, subject = "target", zoom = 0.62, shake = 1 },
      { at = impact + 18, subject = "center", zoom = 0.92 },
    }
  elseif profile == "field" then
    segments = {
      { at = 0, subject = "wide", zoom = 1.10, orbit = 0.04 },
      { at = impact * 0.62, subject = "center", zoom = 0.92 },
      { at = impact, subject = "target", zoom = 0.76, shake = 0.8 },
      { at = impact + 20, subject = "wide", zoom = 1.04 },
    }
  elseif profile == "status" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.74, orbit = -0.02 },
      { at = impact, subject = spec.anchor == "attacker" and "attacker" or "target", zoom = 0.68 },
      { at = impact + 22, subject = "center", zoom = 0.90 },
    }
  elseif profile == "self" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.66, orbit = -0.035 },
      { at = impact + 16, subject = "attacker", zoom = 0.72, orbit = 0.025 },
      { at = duration - 14, subject = "center", zoom = 0.90 },
    }
  elseif profile == "explosion" then
    segments = {
      { at = 0, subject = "attacker", zoom = 0.68 },
      { at = impact * 0.72, subject = "wide", zoom = 1.24, shake = 1 },
      { at = impact + 18, subject = "target", zoom = 0.73, shake = 0.7 },
      { at = duration - 18, subject = "center", zoom = 0.96 },
    }
  else -- ranged
    segments = {
      { at = 0, subject = "attacker", zoom = 0.72, orbit = -0.025 },
      { at = impact * 0.44, subject = "center", zoom = 0.88, orbit = 0.02 },
      { at = impact, subject = "target", zoom = 0.68, shake = 0.55 },
      { at = impact + 18, subject = "center", zoom = 0.90 },
    }
  end

  return segments, duration
end

local function subjectPoint(subject, attacker, target, center, baseFocus)
  if subject == "attacker" then
    return { attacker[1], baseFocus[2] + 1.5, attacker[2] }
  end
  if subject == "target" then
    return { target[1], baseFocus[2] + 1.0, target[2] }
  end
  -- "wide" and "center" share their aim point.  Wide changes the lens,
  -- keeping both combatants safely inside the same established camera rig.
  return { center[1], baseFocus[2], center[2] }
end

local function segmentAt(state)
  local segments = state.segments
  local index = 1
  for i = 2, #segments do
    if state.tick < segments[i].at then break end
    index = i
  end
  local current = segments[index]
  if index == 1 then return current, current, 1 end
  local previous = segments[index - 1]
  -- Stadium uses real shot changes, but a four-tick optical blend avoids a
  -- one-frame projection jump in Gen1Recomp's transformed animation layer.
  local blend = smooth((state.tick - current.at) / 4)
  return previous, current, blend
end

local function apply(base, pitch, arena, groundY, canonical)
  local state = active
  if canonical or not state or type(base) ~= "table" then return base, pitch end
  if not (arena and arena.player and arena.enemy and base.eye and base.focus and base.fov) then
    return base, pitch
  end
  if state.tick >= state.duration then return base, pitch end

  local player, enemy = arena.player, arena.enemy
  local attacker = state.attackerIsPlayer and player or enemy
  local target = state.attackerIsPlayer and enemy or player
  local center = { (player[1] + enemy[1]) / 2, (player[2] + enemy[2]) / 2 }
  local previous, current, cut = segmentAt(state)
  local previousFocus = subjectPoint(previous.subject, attacker, target, center, base.focus)
  local currentFocus = subjectPoint(current.subject, attacker, target, center, base.focus)
  local desiredFocus = {
    mix(previousFocus[1], currentFocus[1], cut),
    mix(previousFocus[2], currentFocus[2], cut),
    mix(previousFocus[3], currentFocus[3], cut),
  }
  -- Never crop more tightly than Dramaless Shape's idle composition. The
  -- original 0.62-0.76 profile values magnified the staged map by roughly
  -- 32-61 percent, which made scenery and large models fill the screen.
  -- Values above 1 remain legitimate wide establishing shots.
  local zoom = math.max(1, mix(previous.zoom or 1, current.zoom or 1, cut))
  local orbit = mix(previous.orbit or 0, current.orbit or 0, cut)

  local enter = smooth(state.tick / 6)
  local leave = smooth((state.duration - state.tick) / 14)
  local weight = math.min(enter, leave)
  local eye = copy3(base.eye)

  -- On Stadium's empty-disc stage a small orbit is safe and gives projectile
  -- travel a readable axis.  Map-staged battles retain the proven base eye
  -- and create their close-ups optically, avoiding travel through scenery.
  if state.stageMode == "B" and math.abs(orbit) > 0.0001 then
    local dx, dz = eye[1] - center[1], eye[3] - center[2]
    local angle = orbit * weight
    local c, s = math.cos(angle), math.sin(angle)
    eye[1] = center[1] + dx * c - dz * s
    eye[3] = center[2] + dx * s + dz * c
  end

  local focus = {
    mix(base.focus[1], desiredFocus[1], weight),
    mix(base.focus[2], desiredFocus[2], weight),
    mix(base.focus[3], desiredFocus[3], weight),
  }
  local fov = mix(base.fov, clamp(base.fov * zoom, math.rad(15), math.rad(75)), weight)

  local impact = tonumber(state.spec.impactAt) or 38
  local distance = math.abs(state.tick - impact)
  local shake = mix(previous.shake or 0, current.shake or 0, cut)
  if distance < 9 and shake > 0 then
    local power = clamp((tonumber(state.spec.power) or 40) / 120, 0.25, 1)
    local spacingX, spacingZ = enemy[1] - player[1], enemy[2] - player[2]
    local spacing = math.max(1, math.sqrt(spacingX * spacingX + spacingZ * spacingZ))
    local amount = (1 - distance / 9) * shake * power * spacing * 0.012
    local jitterX = math.sin(state.tick * 2.41 + state.spec.id) * amount
    local jitterY = math.sin(state.tick * 3.17 + state.spec.id * 0.5) * amount * 0.65
    eye[1], eye[2] = eye[1] + jitterX, eye[2] + jitterY
    focus[1], focus[2] = focus[1] + jitterX, focus[2] + jitterY
  end

  local horizontal = math.sqrt((eye[1] - focus[1]) ^ 2 + (eye[3] - focus[3]) ^ 2)
  local directed = { eye = eye, focus = focus, fov = fov, curve = 0 }
  return directed, math.atan2(horizontal, math.max(1e-3, eye[2] - focus[2]))
end

local function safeCall(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
  return nil
end

local function install(companion)
  if installed then return true end
  local found = companion and companion()
  local exports = found and found.exports
  local lib = exports and exports.lib
  if not (lib and type(lib.require) == "function") then return false end
  local ok, BattleCam = pcall(lib.require, "BattleCam")
  if not ok or type(BattleCam) ~= "table" or type(BattleCam.rig) ~= "function" then
    return false
  end

  if not BattleCam.__stadiumAttackCinematicsWrapped then
    local originalRig = BattleCam.rig
    BattleCam.rig = function(arena, groundY, canonical)
      local base, pitch = originalRig(arena, groundY, canonical)
      base, pitch = widenBattleCinematics(base, pitch, canonical)
      return apply(base, pitch, arena, groundY, canonical)
    end
    BattleCam.__stadiumAttackCinematicsWrapped = true
  end
  installed = true
  return true
end

function Director.configure(companion, externalCamera, zoomOption)
  cameraCompanion = externalCamera
  compatibilityZoomOption = type(zoomOption) == "function"
    and zoomOption or function() return "off" end
  return install(companion)
end

function Director.start(spec, attackerIsPlayer, companion)
  active = nil
  if not (spec and install(companion)) then return false end
  local found = companion and companion()
  local exports = found and found.exports
  local lib = exports and exports.lib
  local Stadium
  if lib and type(lib.require) == "function" then
    local ok, value = pcall(lib.require, "Stadium")
    if ok then Stadium = value end
  end
  local mode = safeCall(Stadium, "mode")
  if not mode then return false end
  local segments, duration = segmentsFor(spec)
  active = {
    spec = spec,
    attackerIsPlayer = attackerIsPlayer and true or false,
    segments = segments,
    duration = duration,
    tick = 0,
    stageMode = mode,
  }
  return true
end

function Director.setTick(tick)
  if active then active.tick = tonumber(tick) or active.tick end
end

function Director.stop()
  active = nil
end

function Director.profileFor(spec)
  return cameraProfile(spec)
end

function Director.status()
  if not active then
    return {
      active = false,
      installed = installed,
      compatibilityZoom = compatibilityZoom(),
    }
  end
  return {
    active = true,
    installed = installed,
    move = active.spec.id,
    profile = cameraProfile(active.spec),
    tick = active.tick,
    compatibilityZoom = compatibilityZoom(),
  }
end

return Director

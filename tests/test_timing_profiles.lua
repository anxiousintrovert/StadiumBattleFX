local loader = love and love.filesystem and love.filesystem.load or loadfile
local profiles = assert(loader("lib/effects/StadiumTimingProfiles.lua"))()

local count, evidence = 0, {}
for id = 1, 165 do
  local profile = assert(profiles[id], "missing timing profile " .. id)
  count = count + 1
  assert(profile.impactAt >= 12, "impact occurs before the attack starts")
  assert(profile.duration >= profile.impactAt + 18, "missing post-impact tail")
  assert(profile.controllerMarker >= 0 and profile.controllerPhase >= 0,
         "invalid controller timing evidence")
  evidence[profile.timingEvidence] = true
end
assert(count == 165, "timing registry must cover all Gen 1 moves")
assert(evidence["controller-completion"], "no explicit completion markers retained")
assert(evidence["controller-envelope"], "no primary controller envelopes retained")
assert(evidence["impact-envelope"], "no defender effect envelopes retained")
assert(evidence["dispatch-archetype"], "missing honest fallback evidence tier")

-- Thunder Shock's source controller advances 35 ticks, schedules its later
-- phase at +8, and explicitly completes at tick 100.
local thunderShock = profiles[84]
assert(thunderShock.controllerPhase == 35 and thunderShock.controllerMarker == 100,
       "Thunder Shock controller schedule changed")
assert(thunderShock.duration == 104,
       "Thunder Shock completion padding changed")

print("ok complete-roster Stadium controller timing")
return true

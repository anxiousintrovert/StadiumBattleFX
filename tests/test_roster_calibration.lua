local loader = love and love.filesystem and love.filesystem.load or loadfile
local calibration = assert(loader("lib/effects/StadiumRosterCalibration.lua"))()

local trace = {
  primary = { 0x66, 0x2F }, alternate = {}, impact = { 0x43 },
  primaryResources = { 0x29, 0x03 }, impactResources = {},
}
local spec = { visual = "beam", assets = {} }
calibration.apply(spec, trace)
assert(spec.primaryAsset == "spectrum_cycle", "beam did not prefer spectrum resource")
assert(spec.assetFootprint.width == 32 and spec.assetFootprint.height == 32,
  "canonical resource footprint was not retained")
assert(spec.stadiumDispatch.primary == "66+2F" and spec.stadiumDispatch.impact == "43",
  "dispatch signature was not retained")
assert(spec.calibration == "stadium-dispatch-profiled-v1",
  "wrong calibration tier")

local large = { visual = "status", assets = {} }
calibration.apply(large, {
  primary = { 0x26 }, alternate = {}, impact = { 0x11 },
  primaryResources = { 0x1C }, impactResources = {},
})
assert(large.primaryAsset == "thunder_wave", "status resource selection failed")
assert(large.assetFootprint.width == 64 and large.particleScale > 1,
  "large canonical quad class was not preserved")

print("ok complete-roster Stadium dispatch calibration")

-- Complete-roster calibration derived from Stadium's fragment-62 move
-- dispatch table and the resource members loaded by each effect program.
--
-- This layer intentionally contains no model attachment logic. It only
-- describes VFX geometry, texture selection, delivery, and source identity;
-- Dramaless Shape continues to own combatant staging.

local Calibration = {}

local MEMBER = {
  [0x03] = { asset = "beam_core", width = 32, height = 32 },
  [0x0A] = { asset = "leaf_green", width = 32, height = 32 },
  [0x0B] = { asset = "scratch_claw", width = 32, height = 32 },
  [0x0E] = { asset = "poison_field", width = 64, height = 64 },
  [0x0F] = { asset = "electric", width = 32, height = 96 },
  [0x11] = { asset = "energy_orb", width = 32, height = 32 },
  [0x15] = { asset = "heal_star_a", width = 32, height = 32 },
  [0x16] = { asset = "sand", width = 32, height = 32 },
  [0x18] = { asset = "screen_pulse", width = 64, height = 64,
    impact = true },
  [0x1A] = { asset = "water_cycle", width = 32, height = 32 },
  [0x1C] = { asset = "thunder_wave", width = 64, height = 64 },
  [0x29] = { asset = "spectrum_cycle", width = 32, height = 32 },
}

local PREFERRED = {
  slash = { [0x0B] = "scratch_claw" },
  leaf = { [0x0A] = "leaf_green" },
  electric = { [0x0F] = "electric", [0x1C] = "thunder_wave" },
  stream = { [0x03] = "beam_core", [0x11] = "energy_orb",
    [0x1A] = "water_cycle", [0x29] = "spectrum_cycle" },
  beam = { [0x03] = "beam_core", [0x11] = "energy_core",
    [0x29] = "spectrum_cycle" },
  storm = { [0x03] = "beam_spark", [0x18] = "screen_pulse",
    [0x29] = "spectrum_cycle" },
  orb = { [0x03] = "beam_orb", [0x11] = "energy_orb" },
  drain = { [0x11] = "energy_core", [0x15] = "heal_star_a" },
  heal = { [0x15] = "heal_star_a", [0x11] = "energy_orb" },
  status = { [0x0E] = "poison_field", [0x0F] = "thunder_orb",
    [0x15] = "heal_star_a", [0x16] = "sand", [0x1C] = "thunder_wave",
    [0x29] = "spectrum_cycle" },
}

local function contains(list, wanted)
  for _, value in ipairs(list or {}) do
    if value == wanted then return true end
  end
  return false
end

local function sequence(list)
  local out = {}
  for _, value in ipairs(list or {}) do out[#out + 1] = ("%02X"):format(value) end
  return #out > 0 and table.concat(out, "+") or "none"
end

local function addAsset(spec, name)
  if not name then return end
  spec.assets = spec.assets or {}
  for _, existing in ipairs(spec.assets) do
    if existing == name then return end
  end
  spec.assets[#spec.assets + 1] = name
end

function Calibration.apply(spec, trace)
  if not (spec and trace) then return spec end
  local resources, seen = {}, {}
  for _, list in ipairs({ trace.primaryResources, trace.impactResources }) do
    for _, member in ipairs(list or {}) do
      if not seen[member] then
        seen[member], resources[#resources + 1] = true, member
      end
    end
  end

  local maxWidth, maxHeight, primaryAsset, preferredAsset = 24, 24, nil, nil
  local preferred = PREFERRED[spec.visual] or {}
  for _, member in ipairs(resources) do
    local profile = MEMBER[member]
    if profile then
      maxWidth = math.max(maxWidth, profile.width)
      maxHeight = math.max(maxHeight, profile.height)
      addAsset(spec, profile.asset)
      if not profile.impact then
        primaryAsset = primaryAsset or profile.asset
        preferredAsset = preferredAsset or preferred[member]
      end
    end
  end

  -- Prefer the resource whose actual Stadium role matches this renderer,
  -- rather than whichever archive member happened to appear first.
  primaryAsset = preferredAsset or primaryAsset

  spec.primaryAsset = primaryAsset
  spec.assetFootprint = { width = maxWidth, height = maxHeight }
  -- Canonical Stadium quads are 24/32/64 wide. Perspective projection keeps
  -- the 64-wide class from becoming a literal 2x sprite in the Gen I layer.
  spec.particleScale = maxWidth >= 64 and 1.22
    or maxWidth <= 24 and 0.82 or 1.0
  spec.impactScale = contains(trace.impactResources, 0x18) and 1.0 or 0.82
  spec.stadiumDispatch = {
    primary = sequence(trace.primary),
    alternate = sequence(trace.alternate),
    impact = sequence(trace.impact),
  }
  spec.geometrySource = "stadium-fragment62-resources"
  spec.timingSource = spec.timingSource or "portable-family-60hz"
  spec.calibration = "stadium-dispatch-profiled-v1"
  return spec
end

return Calibration

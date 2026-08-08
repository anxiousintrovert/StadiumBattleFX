-- Party move registry. Dispatch opcodes and resource members are traced from
-- fragment 62. Portable stage offsets remain first-pass synchronization
-- values until native Stadium captures can resolve the battle controller.

local V = ...
local allMoves = V.require("effects/AllMoveSpecs")
local stadiumMoves = V.require("effects/StadiumMoveRoster")
local fidelityProfiles = V.require("effects/StadiumFidelityProfiles")

local specs = {
  -- First post-0.2 roster family: Stadium impact opcode 0x2C with no
  -- independent primary VFX. Dramaless Shape supplies the body motion.
  { id = 1, key = "POUND", name = "Pound", kind = "tackle",
    primaryOpcode = nil, impactOpcode = 0x2C, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 30, duration = 62 },
  { id = 2, key = "KARATE_CHOP", name = "Karate Chop", kind = "tackle",
    primaryOpcode = nil, impactOpcode = 0x2C, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 30, duration = 62 },
  { id = 10, key = "SCRATCH", name = "Scratch", kind = "scratch",
    primaryOpcode = 0x0D, impactOpcode = 0x05, resources = { 0x0B },
    assets = { "scratch_claw", "scratch_spark", "scratch_swipe", "impact_i" },
    impactAt = 35, duration = 72 },
  { id = 16, key = "GUST", name = "Gust", kind = "gust",
    primaryOpcode = 0x0A, impactOpcode = 0x2F, resources = { 0x09, 0x18 },
    assets = { "impact_i" }, impactAt = 55, duration = 92 },
  { id = 24, key = "DOUBLE_KICK", name = "Double Kick", kind = "double_kick",
    primaryOpcode = nil, impactOpcode = 0x23, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 24, duration = 66 },
  { id = 26, key = "JUMP_KICK", name = "Jump Kick", kind = "single_kick",
    primaryOpcode = nil, impactOpcode = 0x2C, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 31, duration = 64 },
  { id = 27, key = "ROLLING_KICK", name = "Rolling Kick", kind = "single_kick",
    primaryOpcode = nil, impactOpcode = 0x2C, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 31, duration = 64 },
  { id = 28, key = "SAND_ATTACK", name = "Sand Attack", kind = "sand",
    primaryOpcode = 0x1F, impactOpcode = 0x37, resources = { 0x16, 0x18 },
    assets = { "sand", "impact_i" }, impactAt = 46, duration = 90 },
  { id = 30, key = "HORN_ATTACK", name = "Horn Attack", kind = "horn",
    primaryOpcode = 0x77, impactOpcode = 0x25, resources = { 0x06, 0x18 },
    assets = { "impact_ia" }, impactAt = 34, duration = 68 },
  { id = 33, key = "TACKLE", name = "Tackle", kind = "tackle",
    primaryOpcode = nil, impactOpcode = 0x2C, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 30, duration = 62 },
  { id = 43, key = "LEER", name = "Leer", kind = "leer",
    primaryOpcode = 0x53, impactOpcode = nil, resources = { 0x30 },
    assets = {}, duration = 58 },
  { id = 45, key = "GROWL", name = "Growl", kind = "body_only",
    primaryOpcode = nil, impactOpcode = nil, resources = {}, assets = {},
    bodyOnly = true },
  { id = 68, key = "COUNTER", name = "Counter", kind = "tackle",
    primaryOpcode = nil, impactOpcode = 0x2C, resources = { 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 30, duration = 62 },
  { id = 81, key = "STRING_SHOT", name = "String Shot", kind = "string",
    primaryOpcode = 0x21, impactOpcode = 0x20, resources = {}, assets = {},
    duration = 181 },
  { id = 84, key = "THUNDERSHOCK", name = "Thunder Shock", kind = "thundershock",
    primaryOpcode = 0x3B, impactOpcode = 0x08, resources = { 0x0F },
    assets = { "electric" }, impactAt = 44, duration = 100 },
  { id = 86, key = "THUNDER_WAVE", name = "Thunder Wave", kind = "thunder_wave",
    primaryOpcode = 0x26, impactOpcode = 0x11, resources = { 0x1C },
    assets = { "thunder_wave" }, impactAt = 50, duration = 104 },
  { id = 93, key = "CONFUSION", name = "Confusion", kind = "confusion",
    primaryOpcode = 0x6B, impactOpcode = 0x49, resources = { 0x26, 0x11, 0x18 },
    assets = { "impact_ia" }, impactAt = 48, duration = 92 },
  { id = 98, key = "QUICK_ATTACK", name = "Quick Attack", kind = "quick",
    primaryOpcode = 0x5A, impactOpcode = 0x2C, resources = { 0x32, 0x18 },
    assets = { "impact_ia", "impact_i" }, impactAt = 38, duration = 72 },
  { id = 150, key = "SPLASH", name = "Splash", kind = "body_only",
    primaryOpcode = nil, impactOpcode = nil, resources = {}, assets = {},
    bodyOnly = true },
}

local byId, byKey = {}, {}
for _, spec in ipairs(specs) do
  byId[spec.id], byId[tostring(spec.id)] = spec, spec
  byKey[spec.key] = spec
end

-- Exact traced implementations above win. Generated entries fill their
-- metadata and provide a Stadium-style renderer for every remaining move.
for _, generated in ipairs(allMoves) do
  local trace = stadiumMoves[generated.id]
  if trace then
    generated.primaryOpcodes = trace.primary
    generated.alternateOpcodes = trace.alternate
    generated.impactOpcodes = trace.impact
    generated.primaryOpcode = trace.primary[1]
    generated.impactOpcode = trace.impact[1]
    local resources, used = {}, {}
    for _, list in ipairs({ trace.primaryResources, trace.impactResources }) do
      for _, resource in ipairs(list) do
        if not used[resource] then
          used[resource] = true
          resources[#resources + 1] = resource
        end
      end
    end
    generated.resources = resources
    -- Stadium has no standalone primary, alternate, or defender VFX program
    -- for these entries. Their presentation is the species-specific body
    -- animation (and its camera), not a fabricated portable particle layer.
    if #trace.primary == 0 and #trace.alternate == 0 and #trace.impact == 0 then
      generated.bodyOnly = true
      generated.kind = "body_only"
    end
  end
  local spec = byId[generated.id]
  if spec then
    for key, value in pairs(generated) do
      if spec[key] == nil then spec[key] = value end
    end
  else
    spec = generated
    specs[#specs + 1] = spec
    byId[spec.id], byId[tostring(spec.id)] = spec, spec
    byKey[spec.key] = spec
  end
end

-- Curated Stadium 1 fidelity profiles override the portable generated timing
-- and renderer selection after the complete registry has been assembled.
for id, profile in pairs(fidelityProfiles) do
  local spec = byId[id]
  if spec then
    for key, value in pairs(profile) do spec[key] = value end
    spec.kind = "generic"
    spec.fidelity = "stadium1-source-calibrated"
  end
end

table.sort(specs, function(a, b) return a.id < b.id end)

return {
  list = specs,
  get = function(move) return byId[move] or byKey[move] end,
}

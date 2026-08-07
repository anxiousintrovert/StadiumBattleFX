-- Party move registry. Dispatch opcodes and resource members are traced from
-- fragment 62. Portable stage offsets remain first-pass synchronization
-- values until native Stadium captures can resolve the battle controller.

local specs = {
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

return {
  list = specs,
  get = function(move) return byId[move] or byKey[move] end,
}

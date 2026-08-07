-- Verified source-level specification for Pokemon Stadium move 84.
--
-- This is intentionally data-only. It records the two procedural schedules
-- proven by pret/pokestadium fragment 62 without pretending the unnamed N64
-- particle helpers have already been reproduced in LÖVE.

return {
  formatVersion = 1,
  moveId = 84,
  name = "Thunder Shock",
  stadiumTickRate = 60,
  -- Median of Stadium's 50-degree base battle camera distances after
  -- converting the 240-line N64 viewport to Gen1Recomp's 144-line canvas.
  portableWorldToPixel = 0.10,

  dispatch = {
    moveTableIndex = 84,
    primaryOpcode = 0x3B,
    impactOpcode = 0x08,
  },

  texture = {
    runtimeAssetSlot = 0x13,
    frameWidth = 0x20,
    frameHeight = 0x60,
    frameStride = 0x600,
    frameCount = 8,
    sourceFormat = "N64 I4",
    archiveOffset = 0x8CC000,
    archiveMember = 0x0F,
    fragmentOffset = 0x4860,
  },

  quads = {
    wide = { width = 32, height = 96, sourcePreset = 0x14 },
    medium = { width = 16, height = 96, sourcePreset = 0x13 },
    narrow = { width = 8, height = 96, sourcePreset = 0x0F },
    impact = { width = 32, height = 96, sourcePreset = 0x12 },
  },

  -- Exact world-scale envelopes from the five particle callbacks used by
  -- this move. Random targets are deterministic in the portable renderer.
  scaleProfiles = {
    func_8433D6EC = { initial = 0.1, target = 1.4, step = 0.1 },
    func_8433D560 = { initial = 0.5, targetMin = 1.0, targetMax = 6.0, step = 0.2 },
    func_8433D3B0 = { initial = 0.5, target = 2.0, step = 0.2 },
    func_8433D070 = { initial = 0.1, target = 3.0, step = 0.1 },
    func_8433D224 = { initial = 0.1, target = 3.5, step = 0.1 },
  },

  primary = {
    anchor = { combatant = "attacker", stadiumTag = 0x64 },
    completionMarkerTick = 100,
    schedules = {
      {
        at = 0, interval = 8, bursts = 3,
        callback = "func_8433D6EC", preset = 0x14,
        sourceArgs = { 2, 1, 2, 0, 0x25, 0 },
      },
      {
        at = 0, interval = 5, bursts = 5,
        callback = "func_8433D6EC", preset = 0x13,
        sourceArgs = { 2, 1, 2, 0, 0x25, 0 },
      },
      {
        at = 35, interval = 4, bursts = 2,
        callback = "func_8433D560", preset = 0x13,
        sourceArgs = { 0x14, 4, 2, 0, 0x25, 0 },
      },
      {
        at = 35, interval = 5, bursts = 2,
        callback = "func_8433D3B0", preset = 0x13,
        sourceArgs = { 0x14, 4, 2, 0, 0x25, 0 },
      },
      {
        at = 35, interval = 6, bursts = 2,
        callback = "func_8433D070", preset = 0x0F,
        sourceArgs = { 0x14, 2, 1, 0, 0x25, 0 },
      },
      {
        at = 35, interval = 4, bursts = 2,
        callback = "func_8433D224", preset = 0x0F,
        sourceArgs = { 0x14, 2, 1, 0, 0x25, 0 },
      },
    },
    controllers = {
      { at = 0, callback = "func_84331DC8", sourceArgs = { 0x10, 3 } },
      { at = 43, callback = "func_84332DB0", sourceArgs = { 4, 8, 0x0A } },
    },
  },

  impact = {
    anchor = {
      combatant = "target",
      stadiumTag = 0x64,
      groundLocked = true,
    },
    schedules = {
      {
        at = 0, interval = 8, bursts = 5,
        callback = "func_8433D3B0", preset = 0x12,
        sourceArgs = { 8, 3, 3, 0, 0x25, 0 },
      },
      {
        at = 0, interval = 4, bursts = 2,
        callback = "func_8433D070", preset = 0x0F,
        sourceArgs = { 0x14, 4, 3, 0, 0x25, 0 },
      },
      {
        at = 0, interval = 4, bursts = 2,
        callback = "func_8433D224", preset = 0x0F,
        sourceArgs = { 0x14, 4, 3, 0, 0x25, 0 },
      },
    },
    controllers = {
      { at = 44, callback = "func_84332DB0", sourceArgs = { 4, 0x10, 0x0A, 0xFF } },
      { at = 48, callback = "func_84331DC8", sourceArgs = { 0x20, 0x0A } },
    },
  },
}

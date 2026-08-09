-- Source-calibrated Stadium 1 presentation overrides.
--
-- These moves were selected because together they exercise the major
-- fragment-62 systems: shared particles, beams, scrolling full-screen
-- textures, status fields, recovery, quakes, and explosions. Timings are
-- expressed in Gen1Recomp's 60 Hz animation clock while preserving the
-- relative emitter starts and primary/defender ordering in Stadium's
-- 30 Hz controller.

return {
  [52] = { stadiumProgram = "fire", variant = "ember",
    impactAt = 44, duration = 82,
    assets = { "energy_orb", "beam_spark", "beam_impact" } },
  [53] = { stadiumProgram = "fire", variant = "stream",
    impactAt = 54, duration = 104,
    assets = { "energy_orb", "energy_core", "energy_column", "large_burst" } },
  [55] = { stadiumProgram = "water", variant = "gun",
    impactAt = 40, duration = 78,
    assets = { "beam_core", "beam_spark", "screen_dual" } },
  [56] = { stadiumProgram = "water", variant = "pump",
    impactAt = 52, duration = 104,
    assets = { "beam_core", "beam_ring", "water_cycle", "large_burst" } },
  [57] = { stadiumProgram = "water", variant = "surf",
    impactAt = 58, duration = 118,
    assets = { "water_cycle", "screen_grain", "screen_pulse" },
    -- Surf's wave texture is a screen presentation layer, not an emitter.
    -- Do not let a missing/stale copy of it select the generic, canvas-only
    -- fallback; the authentic program still supplies the rising water wash.
    optionalAssets = { "water_cycle" } },
  [58] = { stadiumProgram = "ice", variant = "beam",
    impactAt = 56, duration = 110,
    assets = { "spectrum_cycle", "spectrum_glint", "beam_impact" } },
  [59] = { stadiumProgram = "ice", variant = "storm",
    impactAt = 58, duration = 120,
    assets = { "spectrum_cycle", "beam_star", "screen_grain", "large_burst" },
    optionalAssets = { "spectrum_cycle", "beam_star", "screen_grain",
      "large_burst" } },
  [60] = { stadiumProgram = "beam", variant = "psybeam",
    impactAt = 54, duration = 108,
    assets = { "spectrum_cycle", "spectrum_glint", "screen_pulse" } },
  [63] = { stadiumProgram = "beam", variant = "hyper",
    impactAt = 62, duration = 122,
    assets = { "spectrum_cycle", "spectrum_star", "beam_core", "large_burst" } },
  [71] = { stadiumProgram = "drain", variant = "absorb",
    impactAt = 50, duration = 104,
    assets = { "energy_core", "energy_orb", "heal_star_a" } },
  [72] = { stadiumProgram = "drain", variant = "mega",
    impactAt = 50, duration = 112,
    assets = { "energy_core", "energy_column", "heal_ring", "heal_star_b" } },
  [75] = { stadiumProgram = "leaf", variant = "razor",
    impactAt = 48, duration = 94,
    assets = { "leaf_green", "leaf_glint", "leaf_spin", "leaf_gold" } },
  [76] = { stadiumProgram = "beam", variant = "solar",
    impactAt = 68, duration = 132,
    assets = { "heal_ring", "heal_star_a", "spectrum_cycle", "beam_core" } },
  [85] = { stadiumProgram = "electric", variant = "bolt",
    impactAt = 50, duration = 104,
    assets = { "electric", "thunder_orb", "beam_impact" } },
  [87] = { stadiumProgram = "electric", variant = "thunder",
    impactAt = 58, duration = 116,
    assets = { "electric", "thunder_orb", "large_burst" } },
  [89] = { stadiumProgram = "ground", variant = "quake",
    impactAt = 44, duration = 104,
    assets = { "screen_grain", "large_burst", "impact_i" } },
  [92] = { stadiumProgram = "poison", variant = "toxic",
    impactAt = 48, duration = 100,
    assets = { "poison_field", "beam_core", "screen_pulse" },
    -- The tiled poison field is optional presentation polish; the target
    -- bubbles remain a valid Toxic effect without it.
    optionalAssets = { "poison_field" } },
  [94] = { stadiumProgram = "psychic", variant = "psychic",
    impactAt = 54, duration = 108,
    assets = { "screen_pulse", "energy_core", "large_burst" } },
  [105] = { stadiumProgram = "heal", variant = "recover",
    impactAt = 46, duration = 96,
    assets = { "heal_ring", "heal_star_a", "heal_star_b" } },
  [109] = { stadiumProgram = "psychic", variant = "confuse",
    impactAt = 48, duration = 96,
    assets = { "screen_pulse", "spectrum_cycle", "beam_ring" },
    -- beam_ring belongs to the source resource bundle but is not consumed by
    -- this program, so it must not make Confusion lose its screen treatment.
    optionalAssets = { "beam_ring" } },
  [113] = { stadiumProgram = "barrier", variant = "light",
    impactAt = 36, duration = 92,
    assets = { "screen_dual", "screen_pulse", "beam_ring" },
    -- Barrier uses the two screen textures above; beam_ring is not drawn.
    optionalAssets = { "beam_ring" } },
  [115] = { stadiumProgram = "barrier", variant = "reflect",
    impactAt = 36, duration = 92,
    assets = { "screen_dual", "screen_pulse", "beam_ring" },
    optionalAssets = { "beam_ring" } },
  [126] = { stadiumProgram = "fire", variant = "blast",
    impactAt = 60, duration = 116,
    assets = { "energy_orb", "energy_column", "large_burst", "screen_grain" } },
  [153] = { stadiumProgram = "explosion", variant = "explosion",
    impactAt = 50, duration = 120,
    assets = { "large_burst", "screen_grain", "energy_core", "screen_pulse" } },
}

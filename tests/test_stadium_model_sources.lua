local source = assert(io.open("lib/StadiumModelSources.lua", "rb"))
local chunk = assert(load(source:read("*a"), "@lib/StadiumModelSources.lua"))
source:close()

local selected
local optionReads = 0
local active = { STADIUM2_IMPORTER = true }
local namespace = {
  mod = {
    options = { get = function() optionReads = optionReads + 1 return selected end },
    find = function(id) return active[id] and { id=id } or nil end,
  },
  log = { info=function() end, warn=function() end },
}
local Sources = chunk(namespace)
assert(Sources.VERSION == 1)
assert(Sources.optionRow().choices[1][2] == Sources.DEFAULT)
assert(Sources.selectionToken() == Sources.DEFAULT)

local invalidated, availabilityChecks, keeps = 0, 0, 0
local definition = {
  label = "STADIUM 2 (GEN 1 RIG)",
  available = function() availabilityChecks = availabilityChecks + 1 return true end,
  load = function(species, variant, base)
    return { species=species, variant=variant, base=base }
  end,
  keep = function(species, variant)
    assert(species == 25 and variant == "shiny")
    keeps = keeps + 1
  end,
  invalidate = function() invalidated = invalidated + 1 end,
}
local id = Sources.register("STADIUM2_IMPORTER", "gen1-model-pack", definition)
assert(id == "STADIUM2_IMPORTER:gen1-model-pack")
assert(#Sources.list() == 1)
assert(Sources.decorate(25, "shiny", "stadium1") == "stadium1")

selected = id
assert(Sources.selectionToken() == id)
local hybrid = Sources.decorate(25, "shiny", "stadium1")
assert(hybrid.species == 25 and hybrid.variant == "shiny")
assert(hybrid.base == "stadium1")
assert(availabilityChecks == 1)
local readsAfterAcquire = optionReads
Sources.keep(25, "shiny")
Sources.keep(25, "shiny")
assert(keeps == 2 and availabilityChecks == 1,
  "per-frame model cache touches must not run source availability scans")
assert(optionReads == readsAfterAcquire,
  "per-frame model cache touches repeated the option-schema lookup")

active.STADIUM2_IMPORTER = nil
assert(Sources.decorate(25, "shiny", "stadium1") == "stadium1")
Sources.invalidate()
assert(invalidated == 1)
return true

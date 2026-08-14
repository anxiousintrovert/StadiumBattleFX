-- Player-selected appearance sources for the built-in Stadium model runtime.
-- Sources replace geometry/textures only; StadiumBattleFX retains its Stadium 1
-- skeleton, animations, move routing, attachments and battle state machine.

local V = ...

local Sources = {}
Sources.VERSION = 1
Sources.DEFAULT = "stadium:default"

local catalog = {}
local warned = {}
local keepers = {}
local row = {
  key = "model_source",
  label = "BTL MODEL PACK",
  type = "choice",
  default = Sources.DEFAULT,
  choices = {},
}

local function logOnce(key, message, ...)
  if warned[key] then return end
  warned[key] = true
  if V.log and V.log.warn then V.log:warn(message, ...) end
end

local function ownerActive(owner)
  if not (V.mod and type(V.mod.find) == "function") then return true end
  local ok, found = pcall(V.mod.find, owner)
  if not ok or found == nil then
    ok, found = pcall(V.mod.find, V.mod, owner)
  end
  return ok and found ~= nil
end

local function refreshRow()
  local choices = { { "POKEMON STADIUM", Sources.DEFAULT } }
  local entries = {}
  for _, entry in pairs(catalog) do entries[#entries + 1] = entry end
  table.sort(entries, function(a, b)
    local al, bl = a.label:lower(), b.label:lower()
    if al ~= bl then return al < bl end
    return a.id < b.id
  end)
  for _, entry in ipairs(entries) do
    choices[#choices + 1] = { entry.label, entry.id }
  end
  row.choices = choices
end
refreshRow()

function Sources.optionRow() return row end

function Sources.register(owner, localId, definition)
  assert(type(owner) == "string" and owner ~= "", "model source owner is required")
  assert(type(localId) == "string" and localId:match("^[%w_.-]+$"),
    "model source id must contain only letters, numbers, dot, dash or underscore")
  assert(type(definition) == "table", "model source definition is required")
  assert(type(definition.label) == "string" and definition.label ~= "",
    "model source label is required")
  assert(type(definition.load) == "function", "model source load function is required")
  local id = owner .. ":" .. localId
  local prior = catalog[id]
  if prior then
    assert(prior.definition == definition,
      "model source already registered with a different definition: " .. id)
    return id
  end
  catalog[id] = { id=id, owner=owner, label=definition.label, definition=definition }
  refreshRow()
  if V.log and V.log.info then
    V.log:info("Stadium model source registered: id=%s label=%s", id, definition.label)
  end
  return id
end

function Sources.list()
  local out = {}
  for _, entry in pairs(catalog) do
    out[#out + 1] = { id=entry.id, owner=entry.owner, label=entry.label }
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

function Sources.selectedId()
  local value = V.mod and V.mod.options and V.mod.options:get(row.key)
  if type(value) ~= "string" or value == "" then return Sources.DEFAULT end
  return value
end

local function selectedEntry()
  local id = Sources.selectedId()
  if id == Sources.DEFAULT then return nil end
  local entry = catalog[id]
  if not entry or (entry.definition.embedded ~= true and not ownerActive(entry.owner)) then
    logOnce("missing:" .. id, "Stadium model source unavailable; using Stadium 1: id=%s", id)
    return nil
  end
  local available = entry.definition.available
  if type(available) == "function" then
    local ok, answer = pcall(available)
    if not ok or not answer then
      if not ok then
        logOnce("available:" .. id,
          "Stadium model source availability failed; using Stadium 1: id=%s error=%s",
          id, tostring(answer))
      end
      return nil
    end
  end
  return entry
end

function Sources.decorate(species, variant, base)
  local keepKey = tostring(species) .. ":" .. tostring(variant)
  local entry = selectedEntry()
  if not entry then
    keepers[keepKey] = nil
    return base
  end
  local ok, model, err = pcall(entry.definition.load, species, variant, base)
  if ok and model then
    keepers[keepKey] = type(entry.definition.keep) == "function"
      and entry.definition.keep or nil
    return model
  end
  keepers[keepKey] = nil
  logOnce(("load:%s:%s:%s"):format(entry.id, tostring(species), tostring(variant)),
    "Stadium model source failed; using Stadium 1: id=%s species=%s variant=%s error=%s",
    entry.id, tostring(species), tostring(variant), tostring(err or model))
  return base
end

function Sources.keep(species, variant)
  -- Decoration records the exact callback for this acquired species/variant.
  -- Avoid both source availability and the option-schema lookup in this
  -- per-side, per-frame path.
  local keep = keepers[tostring(species) .. ":" .. tostring(variant)]
  if type(keep) == "function" then pcall(keep, species, variant) end
end

function Sources.invalidate()
  keepers = {}
  for _, entry in pairs(catalog) do
    local invalidate = entry.definition.invalidate
    if type(invalidate) == "function" then pcall(invalidate) end
  end
end

return Sources

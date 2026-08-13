-- Versioned, player-selected battle presentation provider registry.
--
-- This module owns catalog and selection policy only. Runtime dispatch remains
-- in the subsystem that understands each slot's contract. There is no provider
-- priority: the saved player choice wins, with Stadium's built-in as the safe
-- fallback for an absent, stale, unavailable, or failed external provider.

local V = ...

local Registry = {}
Registry.VERSION = 1
Registry.FALLBACK = {}
Registry.DEFAULT = "stadium:default"
Registry.OFF = "off"

local SLOT_DEFS = {
  { id = "arena", label = "BTL ARENA", help = "Battlefield or stage provider" },
  { id = "models", label = "BTL MODELS", help = "Pokemon model provider" },
  { id = "animations", label = "BTL ANIM", help = "Move animation provider" },
  { id = "camera", label = "BTL CAMERA", help = "Battle camera provider" },
  { id = "effects", label = "BTL EFFECTS", help = "Particles and post-processing provider" },
  { id = "announcer", label = "BTL VOICE", help = "Spoken callout provider" },
  { id = "hud", label = "BTL HUD", help = "Battle HUD provider" },
  { id = "overlay", label = "BTL OVERLAY", help = "Screen overlay provider" },
  { id = "transitions", label = "BTL TRANS", help = "Battle transition provider" },
}

local slots, catalog, builtins, rows = {}, {}, {}, {}
local warned = {}
for _, def in ipairs(SLOT_DEFS) do
  slots[def.id] = def
  catalog[def.id] = {}
end

local function logOnce(key, message, ...)
  if warned[key] then return end
  warned[key] = true
  if V.log and V.log.warn then V.log:warn(message, ...) end
end

local function copyEntry(entry)
  if not entry then return nil end
  return {
    id = entry.id,
    owner = entry.owner,
    slot = entry.slot,
    label = entry.label,
    description = entry.description,
    provider = entry.provider,
  }
end

local function ownerActive(owner)
  if not (V.mod and type(V.mod.find) == "function") then return true end
  local ok, found = pcall(V.mod.find, owner)
  if not ok or found == nil then
    local methodOk, methodFound = pcall(V.mod.find, V.mod, owner)
    if methodOk and methodFound ~= nil then ok, found = methodOk, methodFound end
  end
  return ok and found ~= nil
end

local function available(entry, context)
  if not entry then return false end
  if entry.owner and not entry.builtin and not ownerActive(entry.owner) then return false end
  local fn = entry.available
  if not fn and type(entry.provider) == "table" then fn = entry.provider.available end
  if type(fn) ~= "function" then return true end
  local ok, answer = pcall(fn, context, entry)
  if not ok then
    logOnce("available:" .. entry.id,
      "battle provider availability failed: slot=%s id=%s error=%s",
      entry.slot, entry.id, tostring(answer))
    return false
  end
  return answer and true or false
end

local function sortedEntries(slot)
  local out = {}
  for _, entry in pairs(catalog[slot]) do out[#out + 1] = entry end
  table.sort(out, function(a, b)
    local al, bl = a.label:lower(), b.label:lower()
    if al ~= bl then return al < bl end
    return a.id < b.id
  end)
  return out
end

local function refreshRow(slot)
  local row = rows[slot]
  if not row then return end
  local choices = { { "STADIUM DEFAULT", Registry.DEFAULT } }
  for _, entry in ipairs(sortedEntries(slot)) do
    choices[#choices + 1] = { entry.label, entry.id }
  end
  choices[#choices + 1] = { "OFF", Registry.OFF }
  row.choices = choices
end

function Registry.slots()
  local out = {}
  for i, def in ipairs(SLOT_DEFS) do
    out[i] = { id = def.id, label = def.label, help = def.help }
  end
  return out
end

function Registry.optionRows()
  local out = {}
  for _, def in ipairs(SLOT_DEFS) do
    if not rows[def.id] then
      rows[def.id] = {
        key = "provider_" .. def.id,
        label = def.label,
        type = "choice",
        default = Registry.DEFAULT,
        choices = {},
      }
      refreshRow(def.id)
    end
    out[#out + 1] = rows[def.id]
  end
  return out
end

function Registry.setBuiltin(slot, provider, metadata)
  assert(slots[slot], "unknown battle provider slot: " .. tostring(slot))
  builtins[slot] = {
    id = Registry.DEFAULT,
    owner = V.mod and V.mod.id or "STADIUM_BATTLE_FX",
    slot = slot,
    label = "STADIUM DEFAULT",
    description = metadata and metadata.description,
    provider = provider,
    builtin = true,
    available = metadata and metadata.available,
  }
end

function Registry.registerComponent(owner, slot, localId, definition)
  assert(type(owner) == "string" and owner ~= "", "battle provider owner is required")
  assert(slots[slot], "unknown battle provider slot: " .. tostring(slot))
  assert(type(localId) == "string" and localId:match("^[%w_.-]+$"),
    "battle provider id must contain only letters, numbers, dot, dash or underscore")
  assert(type(definition) == "table", "battle provider definition is required")
  assert(definition.priority == nil,
    "battle providers have equal priority; the player selects the provider")
  assert(type(definition.label) == "string" and definition.label ~= "",
    "battle provider label is required")
  assert(type(definition.provider) == "table", "battle provider table is required")

  local id = owner .. ":" .. localId
  local prior = catalog[slot][id]
  if prior then
    assert(prior.provider == definition.provider,
      "battle provider already registered with different provider: " .. id)
    return id
  end

  catalog[slot][id] = {
    id = id,
    owner = owner,
    slot = slot,
    label = definition.label,
    description = definition.description,
    provider = definition.provider,
    available = definition.available,
  }
  refreshRow(slot)
  if V.log and V.log.info then
    V.log:info("battle provider registered: slot=%s id=%s label=%s",
      slot, id, definition.label)
  end
  return id
end

function Registry.componentList(slot)
  assert(slots[slot], "unknown battle provider slot: " .. tostring(slot))
  local out = {}
  for i, entry in ipairs(sortedEntries(slot)) do out[i] = copyEntry(entry) end
  return out
end

function Registry.selectedId(slot)
  assert(slots[slot], "unknown battle provider slot: " .. tostring(slot))
  local value = V.mod and V.mod.options and V.mod.options:get("provider_" .. slot)
  if type(value) ~= "string" or value == "" then return Registry.DEFAULT end
  return value
end

function Registry.resolve(slot, context)
  assert(slots[slot], "unknown battle provider slot: " .. tostring(slot))
  local selected = Registry.selectedId(slot)
  if selected == Registry.OFF then return nil, nil end

  local entry = selected == Registry.DEFAULT and builtins[slot] or catalog[slot][selected]
  if selected == Registry.DEFAULT and entry and type(entry.provider) == "table"
      and type(entry.provider.preferredExternal) == "function" then
    local ok, preferredId = pcall(entry.provider.preferredExternal,
      entry.provider, context)
    local preferred = ok and preferredId and catalog[slot][preferredId]
    if preferred and available(preferred, context) then
      return preferred.provider, copyEntry(preferred)
    end
  end
  if entry and available(entry, context) then return entry.provider, copyEntry(entry) end

  if selected ~= Registry.DEFAULT then
    logOnce("fallback:" .. slot .. ":" .. selected,
      "battle provider selection fell back: slot=%s selected=%s", slot, selected)
  end
  local builtin = builtins[slot]
  if builtin and available(builtin, context) then
    return builtin.provider, copyEntry(builtin)
  end
  return nil, nil
end

-- Host-only fallback access. External consumers should use resolve(); this is
-- how the dispatcher honors FALLBACK without exposing mutable registry state.
function Registry.builtin(slot, context)
  assert(slots[slot], "unknown battle provider slot: " .. tostring(slot))
  local entry = builtins[slot]
  if entry and available(entry, context) then return entry.provider, copyEntry(entry) end
  return nil, nil
end

function Registry.isSelected(slot, id)
  return Registry.selectedId(slot) == id
end

function Registry.pruneInactive()
  local removed = 0
  for slot, entries in pairs(catalog) do
    for id, entry in pairs(entries) do
      if not ownerActive(entry.owner) then
        entries[id] = nil
        removed = removed + 1
        if V.log and V.log.info then
          V.log:info("battle provider pruned: slot=%s id=%s", slot, id)
        end
      end
    end
    refreshRow(slot)
  end
  return removed
end

return Registry

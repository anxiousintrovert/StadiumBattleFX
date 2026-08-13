local savedLove = love
local source = assert(io.open("lib/BattleProviders.lua", "rb"))
local chunk = assert(load(source:read("*a"), "@lib/BattleProviders.lua"))
source:close()

local selected = {}
local active = { OTHER_MOD = true }
local messages = {}
local namespace = {
  mod = {
    id = "STADIUM_BATTLE_FX",
    options = { get = function(_, key) return selected[key] end },
    find = function(_, id) return active[id] and { id = id } or nil end,
  },
  log = {
    info = function(_, fmt, ...) messages[#messages + 1] = fmt:format(...) end,
    warn = function(_, fmt, ...) messages[#messages + 1] = fmt:format(...) end,
  },
}

local Registry = chunk(namespace)
assert(Registry.VERSION == 1)
assert(#Registry.slots() == 9)

local builtin = { name = "builtin" }
Registry.setBuiltin("arena", builtin)
assert(Registry.resolve("arena") == builtin)

local external = { name = "external" }
local id = Registry.registerComponent("OTHER_MOD", "arena", "voxel-map", {
  label = "VOXEL MAP",
  provider = external,
})
assert(id == "OTHER_MOD:voxel-map")
assert(#Registry.componentList("arena") == 1)

active.DRAMALESS_SHAPE = true
local voxel = { name = "voxel" }
local voxelId = Registry.registerComponent("DRAMALESS_SHAPE", "arena", "voxel-map", {
  label = "VOXEL MAP", provider = voxel,
})
assert(voxelId == "DRAMALESS_SHAPE:voxel-map")

local rows = Registry.optionRows()
assert(rows[1].key == "provider_arena")
assert(rows[1].choices[1][2] == Registry.DEFAULT)
local listed = {}
for _, choice in ipairs(rows[1].choices) do listed[choice[2]] = true end
assert(listed[id] and listed[voxelId])
assert(rows[1].choices[4][2] == Registry.OFF)

builtin.preferredExternal = function(_, context)
  if not (context and context.boss) then return voxelId end
end
selected.provider_arena = Registry.DEFAULT
assert(Registry.resolve("arena", { boss = false }) == voxel,
  "default ordinary arena did not prefer the registered voxel map")
assert(Registry.resolve("arena", { boss = true }) == builtin,
  "default boss arena did not retain the built-in venue")

selected.provider_arena = id
assert(Registry.resolve("arena") == external)
selected.provider_arena = Registry.OFF
assert(Registry.resolve("arena") == nil)
selected.provider_arena = "MISSING:old-id"
assert(Registry.resolve("arena") == builtin)

selected.provider_arena = id
active.OTHER_MOD = nil
assert(Registry.resolve("arena") == builtin)
assert(Registry.pruneInactive() == 1)

local ok = pcall(Registry.registerComponent, "OTHER_MOD", "arena", "bad id", {
  label = "BAD", provider = {},
})
assert(not ok, "invalid IDs must be rejected")

love = savedLove
return true

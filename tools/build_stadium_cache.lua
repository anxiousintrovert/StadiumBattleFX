-- External, trusted cache builder invoked through an embedded LuaJIT runtime.
-- It runs outside Gen1Recomp's mod sandbox, reads the player's selected ROMs,
-- and writes only into CACHE_ROOT. The resulting cache/ tree is injected into
-- the player's personalized mod ZIP and becomes read-only at runtime.

assert(type(MOD_ROOT) == "string" and MOD_ROOT ~= "", "MOD_ROOT is required")
assert(type(CACHE_ROOT) == "string" and CACHE_ROOT ~= "", "CACHE_ROOT is required")
assert(type(STADIUM1_ROM) == "string" and STADIUM1_ROM ~= "", "STADIUM1_ROM is required")

local function join(a, b)
  return (a:gsub("/+$", "")) .. "/" .. (b:gsub("^/+", ""))
end

local function readFile(path)
  local file, err = io.open(path, "rb")
  if not file then return nil, err end
  local bytes = file:read("*a")
  file:close()
  return bytes
end

local function writeFile(path, bytes)
  PY_MKDIR((path:match("^(.*)/[^/]+$") or CACHE_ROOT))
  local file, err = io.open(path, "wb")
  if not file then return false, err end
  local ok, writeErr = file:write(bytes)
  file:close()
  return ok and true or false, writeErr
end

local function sortedKeys(value)
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) < type(b)
  end)
  return keys
end

local function serialize(value, seen)
  local kind = type(value)
  if kind == "nil" or kind == "boolean" or kind == "number" then
    return tostring(value)
  end
  if kind == "string" then return string.format("%q", value) end
  assert(kind == "table", "cache record contains unsupported " .. kind)
  seen = seen or {}
  assert(not seen[value], "cache record contains a cycle")
  seen[value] = true
  local parts = { "{" }
  for _, key in ipairs(sortedKeys(value)) do
    parts[#parts + 1] = "[" .. serialize(key, seen) .. "]="
      .. serialize(value[key], seen) .. ","
  end
  parts[#parts + 1] = "}"
  seen[value] = nil
  return table.concat(parts)
end

local storageRoot = join(CACHE_ROOT, "storage")
local function storagePath(key, suffix)
  return join(storageRoot, key .. suffix)
end

local storageApi = {}
function storageApi:write(_, key, value)
  assert(type(value) == "table", "storage cache value must be a table")
  local record = {}
  for field, item in pairs(value) do record[field] = item end
  if type(record.bytes) == "string" then
    local ok, err = writeFile(storagePath(key, ".bin"), record.bytes)
    if not ok then return false, "write_failed", tostring(err) end
    record.bytes = nil
  end
  local ok, err = writeFile(storagePath(key, ".lua"),
    "return " .. serialize(record) .. "\n")
  if not ok then return false, "write_failed", tostring(err) end
  return true
end
function storageApi:read(_, key)
  local source = readFile(storagePath(key, ".lua"))
  if not source then return nil, "not_found", "cache record is absent" end
  local chunk, err = loadstring(source, "@cache/storage/" .. key .. ".lua")
  if not chunk then return nil, "decode_failed", tostring(err) end
  local ok, record = pcall(chunk)
  if not ok or type(record) ~= "table" then
    return nil, "decode_failed", tostring(record)
  end
  local bytes = readFile(storagePath(key, ".bin"))
  if bytes then record.bytes = bytes end
  return record
end
function storageApi:delete(_, key)
  PY_REMOVE(storagePath(key, ".lua"))
  PY_REMOVE(storagePath(key, ".bin"))
  return true
end

local stadium1Bytes = assert(readFile(STADIUM1_ROM))
local stadium2Bytes = type(STADIUM2_ROM) == "string" and STADIUM2_ROM ~= ""
  and assert(readFile(STADIUM2_ROM)) or nil
local fakeGame = { save = { version = "yellow", meta = { playthroughId = "builder" } } }
local optionValues = { stadium2_models = true, stadium2_shader = "stadium" }
local mod = {
  id = "STADIUM_BATTLE_FX", path = MOD_ROOT, exports = {}, game = fakeGame,
  storage = storageApi,
  options = { get = function(_, key) return optionValues[key] end },
  log = {
    info = function(_, fmt, ...) PY_PROGRESS(string.format(fmt, ...)) end,
    warn = function(_, fmt, ...) PY_PROGRESS("warning: " .. string.format(fmt, ...)) end,
    error = function(_, fmt, ...) PY_PROGRESS("error: " .. string.format(fmt, ...)) end,
  },
}
function mod:read(relative)
  if relative:match("^baseroms/") then return stadium1Bytes end
  return readFile(join(MOD_ROOT, relative))
end
function mod.find() return nil end

love = {
  data = {
    hash = function(_, data) return #data end,
    encode = function(_, _, digest)
      if digest == 32 * 1024 * 1024 then return "ed1378bc12115f71209a77844965ba50" end
      if digest == 64 * 1024 * 1024 then return "1561c75d11cedf356a8ddb1a4a5f9d5d" end
      error("unexpected ROM length for builder MD5")
    end,
  },
  image = { newImageData = function(...) return { args = { ... } } end },
  graphics = {
    newImage = function()
      return { setFilter = function() end, setWrap = function() end }
    end,
    newQuad = function(...) return { ... } end,
  },
  system = { getOS = function() return "ExternalBuilder" end },
}

local cacheWriter = {}
function cacheWriter.read(path) return readFile(join(CACHE_ROOT, path)) end
function cacheWriter.write(path, bytes) return writeFile(join(CACHE_ROOT, path), bytes) end
function cacheWriter.ensure(paths)
  for _, path in ipairs(paths) do PY_MKDIR(join(CACHE_ROOT, path)) end
  return true
end
function cacheWriter.clear(root)
  PY_CLEAR(join(CACHE_ROOT, root))
  PY_MKDIR(join(CACHE_ROOT, root))
  return true
end

local namespace = {
  mod = mod, path = MOD_ROOT, engineRequire = require,
  cacheWriter = cacheWriter,
}
local modules = {}
function namespace.require(name)
  if modules[name] ~= nil then return modules[name] end
  local relative = "lib/" .. name .. ".lua"
  local source = assert(readFile(join(MOD_ROOT, relative)), "missing " .. relative)
  if name:match("^stadium2/") then
    source = [[
local __sbfxNamespace = ...
local function require(name)
  local embedded = type(name) == "string" and
    name:match("^mods%.STADIUM_BATTLE_FX%.lib%.stadium2%.(.+)$")
  if embedded then
    return __sbfxNamespace.require("stadium2/" .. embedded:gsub("%.", "/"))
  end
  return __sbfxNamespace.engineRequire(name)
end
]] .. source
  end
  local chunk = assert(loadstring(source, "@" .. relative))
  local value = chunk(namespace)
  modules[name] = value
  return value
end

local Storage = namespace.require("ModStorage")
namespace.storage = Storage
Storage.setGame(fakeGame)
namespace.log = mod.log

local function runStage(label, begin, step, status, limit)
  PY_PROGRESS(label)
  local ok, err = begin()
  assert(ok, label .. " could not start: " .. tostring(err))
  local count = 0
  while status().state == "building" do
    step()
    count = count + 1
    assert(count <= limit, label .. " exceeded its step limit")
  end
  local final = status()
  assert(final.state == "done" or final.state == "ready",
    label .. " failed: " .. tostring(final.error or final.state))
end

local Assets = namespace.require("StadiumAssets")
runStage("Building attack-effect cache...",
  function() return Assets.begin(true) end, Assets.step, Assets.status, 2048)

local ArenaAssets = namespace.require("StadiumArenaAssets")
runStage("Building arena cache...",
  function() return ArenaAssets.begin(true) end, ArenaAssets.step,
  ArenaAssets.status, 256)

local Portraits = namespace.require("StadiumTrainerPortraits")
runStage("Building trainer-portrait cache...", Portraits.begin, Portraits.step,
  Portraits.status, 128)

local StadiumInstall = namespace.require("StadiumInstall")
runStage("Building Stadium 1 model cache...",
  function() return StadiumInstall.beginFrom(stadium1Bytes, "external builder") end,
  StadiumInstall.step, function() return StadiumInstall.status end, 256)

PY_PROGRESS("Building Thunder Shock texture cache...")
local texture, textureErr = namespace.require("StadiumTexture").get()
assert(texture ~= nil, "Thunder Shock texture cache failed: " .. tostring(textureErr))

if stadium2Bytes then
  local Importer = namespace.require("stadium2/importer")
  Importer.bind(mod)
  Importer.configure({ count = 151, meshOnly = true, includeUnownForms = false })
  runStage("Building Stadium 2 appearance cache...",
    function() return Importer.beginFrom(stadium2Bytes, "external builder") end,
    Importer.step, Importer.status, 4096)
end

assert(writeFile(join(storageRoot, "_catalog.lua"),
  "return {format=\"SBFX-PACKAGED-CACHE-1\",stadium1=true,stadium2="
    .. tostring(stadium2Bytes ~= nil) .. "}\n"))
PY_PROGRESS("All packaged caches are ready.")

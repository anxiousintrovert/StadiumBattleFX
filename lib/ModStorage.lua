-- Sandbox-safe access to this mod's bundled files and playthrough storage.
-- Runtime modules use logical keys only; the engine owns every real path.

local V = ...
local Storage = {}
local currentGame
local fallback = {}
local PACKAGED_ROOT = "cache/storage/"

local function packaged(relative)
  local ok, bytes = pcall(V.mod.read, V.mod, PACKAGED_ROOT .. relative)
  if ok and type(bytes) == "string" then return bytes end
end

local function packagedRecord(key)
  local source = packaged(key .. ".lua")
  if type(source) ~= "string" then return nil end
  local chunk, compileErr = load(source, "@" .. PACKAGED_ROOT .. key .. ".lua")
  if not chunk then return nil, "invalid_packaged_cache", tostring(compileErr) end
  local ok, record = pcall(chunk)
  if not ok or type(record) ~= "table" then
    return nil, "invalid_packaged_cache", tostring(record)
  end
  local bytes = packaged(key .. ".bin")
  if bytes then record.bytes = bytes end
  return record
end

function Storage.setGame(game)
  if game then currentGame = game end
  return currentGame
end

function Storage.game()
  if currentGame then return currentGame end
  local ok, game = pcall(function() return V.mod.game end)
  if ok then return game end
end

function Storage.active()
  if V.mod and V.mod.storage ~= nil and Storage.game() ~= nil then return true end
  return packaged("_catalog.lua") ~= nil
end

function Storage.read(key)
  local api, game = V.mod and V.mod.storage, Storage.game()
  if api and api.read and game then
    local value, code, message = api:read(game, key)
    if value ~= nil then return value end
    local bundled, bundledCode, bundledMessage = packagedRecord(key)
    if bundled ~= nil then return bundled end
    return nil, bundledCode or code, bundledMessage or message
  end
  local bundled, code, message = packagedRecord(key)
  if bundled ~= nil then return bundled end
  local value = fallback[key]
  if value ~= nil then return value end
  return nil, code or "storage_unavailable",
    message or "Mod storage needs an active playthrough."
end

function Storage.write(key, value)
  local api, game = V.mod and V.mod.storage, Storage.game()
  if api and api.write and game then return api:write(game, key, value) end
  -- In-memory fallback is used only by headless developer tests.
  fallback[key] = value
  return true
end

function Storage.delete(key)
  local api, game = V.mod and V.mod.storage, Storage.game()
  if api and api.delete and game then return api:delete(game, key) end
  fallback[key] = nil
  return true
end

function Storage.bytes(key)
  local record, code, message = Storage.read(key)
  if type(record) ~= "table" or type(record.bytes) ~= "string" then
    return nil, code or "not_found", message or "Stored bytes are unavailable."
  end
  return record.bytes, record
end

function Storage.writeBytes(key, bytes, fields)
  local record = fields or {}
  record.bytes = bytes
  return Storage.write(key, record)
end

function Storage.bundled(relative)
  local ok, bytes = pcall(V.mod.read, V.mod, relative)
  if ok and type(bytes) == "string" then return bytes end
end

local ROM_NAMES = {
  "baseroms/baserom.z64", "baseroms/baserom.n64", "baseroms/baserom.v64",
  "baseroms/Pokemon Stadium (USA).z64",
  "baseroms/Pokemon Stadium (USA).n64",
  "baseroms/Pokemon Stadium (USA).v64",
}

function Storage.bundledRom()
  for _, relative in ipairs(ROM_NAMES) do
    local bytes = Storage.bundled(relative)
    if bytes then return relative, bytes end
  end
end

return Storage

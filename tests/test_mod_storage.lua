local calls = {}
local records = {}
local packaged = {
  ["cache/storage/_catalog.lua"] = "return {format='SBFX-PACKAGED-CACHE-1'}",
  ["cache/storage/models/packs/026.lua"] = "return {format=6}",
  ["cache/storage/models/packs/026.bin"] = "PACKAGED",
}
local game = { save = { version = "red" } }
local mod = {
  storage = {
    read = function(_, seenGame, key)
      calls[#calls + 1] = { "read", seenGame, key }
      return records[key]
    end,
    write = function(_, seenGame, key, value)
      calls[#calls + 1] = { "write", seenGame, key }
      records[key] = value
      return true
    end,
    delete = function(_, seenGame, key)
      calls[#calls + 1] = { "delete", seenGame, key }
      records[key] = nil
      return true
    end,
  },
  read = function(_, path)
    if path == "baseroms/baserom.z64" then return "ROM" end
    return packaged[path]
  end,
}

local Storage = assert(loadfile("lib/ModStorage.lua"))({ mod = mod })
Storage.setGame(game)
assert(Storage.writeBytes("models/packs/025", "\0\1\2", { format = 5 }))
local bytes, record = Storage.bytes("models/packs/025")
assert(bytes == "\0\1\2" and record.format == 5)
assert(calls[1][2] == game and calls[1][3] == "models/packs/025")
local path, rom = Storage.bundledRom()
assert(path == "baseroms/baserom.z64" and rom == "ROM")
assert(Storage.delete("models/packs/025"))
assert(Storage.bytes("models/packs/025") == nil)
local packagedBytes, packagedRecord = Storage.bytes("models/packs/026")
assert(packagedBytes == "PACKAGED" and packagedRecord.format == 6)

-- A restricted runtime may offer mod:read for an optional ROM without also
-- offering persistent mod storage.  Once the importer writes its first pack,
-- the process-local sandbox backend must become available so Cache.available
-- can expose the freshly built models in the same session.
local volatileMod = {
  read = function() return nil end,
}
local VolatileStorage = assert(loadfile("lib/ModStorage.lua"))({ mod = volatileMod })
assert(not VolatileStorage.active(), "empty volatile storage should not look cached")
assert(VolatileStorage.writeBytes("stadium2/normal/001.dsm", "MODEL", { format = 1 }))
assert(VolatileStorage.active(),
  "writing a sandbox-local pack did not activate the runtime cache backend")
local volatileBytes, volatileRecord = VolatileStorage.bytes("stadium2/normal/001.dsm")
assert(volatileBytes == "MODEL" and volatileRecord.format == 1,
  "sandbox-local pack could not be read back")

local BuildStorage = assert(loadfile("lib/ModStorage.lua"))({ mod = volatileMod })
assert(not BuildStorage.active(), "new sandbox cache should start inactive")
local SandboxCache = assert(loadfile("lib/stadium2/cache.lua"))({
  require = function(name)
    assert(name == "ModStorage")
    return BuildStorage
  end,
  cacheWriter = {
    active = BuildStorage.active,
    read = function(path) return BuildStorage.bytes("stadium2/" .. path) end,
    write = function(path, bytes)
      return BuildStorage.writeBytes("stadium2/" .. path, bytes)
    end,
    ensure = function() return true end,
    clear = function() return true end,
  },
})
assert(SandboxCache.writePair(1, "NORMAL", "SHINY"))
assert(SandboxCache.writeSpecial("substitute", "SUBSTITUTE"))
assert(SandboxCache.finish({ md5 = "test", title = "test", byteOrder = "z64" }, 1))
assert(SandboxCache.available(1),
  "Stadium 2 packs written through sandbox-local storage were not available")
return true

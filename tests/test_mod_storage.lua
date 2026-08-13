local calls = {}
local records = {}
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
return true

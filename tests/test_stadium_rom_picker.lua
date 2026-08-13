local hostLove = love
local picked, written, removed, madeDir = nil, {}, {}, {}
local romPresent, pushed = false, 0

love = {
  system = {
    getOS = function() return "Android" end,
    pickFile = function(kind) picked = kind return true end,
  },
  filesystem = {
    getInfo = function(path, kind)
      if path == "picked_stadium.z64" and kind == "file" then
        return { type = "file" }
      end
    end,
    read = function(path)
      if path == "picked_stadium.z64" then return "verified stadium bytes" end
    end,
    createDirectory = function(path) madeDir[#madeDir + 1] = path return true end,
    write = function(path, bytes)
      written[path] = bytes
      romPresent = true
      return true
    end,
    remove = function(path) removed[#removed + 1] = path return true end,
  },
}

local modules = {
  StadiumAssets = {
    findRom = function()
      return romPresent and "baseroms/baserom.z64" or nil
    end,
    validateRom = function(bytes)
      return bytes == "verified stadium bytes" and {} or nil, "wrong ROM"
    end,
    status = function() return { state = "idle" } end,
  },
  StadiumArenaAssets = { status = function() return { state = "idle" } end },
  StadiumTrainerPortraits = { status = function() return { state = "idle" } end },
  EffectCacheScreen = { new = function(_, refresh) return { refresh = refresh } end },
}
local Picker = assert(loadfile("lib/StadiumRomPicker.lua"))({
  mod = { path = "mods/STADIUM_BATTLE_FX" },
  require = function(name) return assert(modules[name], name) end,
  log = { info = function() end, warn = function() end },
})
local game = { stack = { push = function(_, screen)
  assert(screen.refresh == true)
  pushed = pushed + 1
end } }

assert(Picker.available(), "Android native Stadium picker must be available")
assert(Picker.import(game), "Android Stadium picker did not open")
assert(picked == "stadium", "wrong Android picker kind")
assert(Picker.importRow().value() == "IMPORT")

assert(Picker.poll(game), "staged Android Stadium ROM was not consumed")
local target = "mods/STADIUM_BATTLE_FX/baseroms/baserom.z64"
assert(madeDir[1] == "mods/STADIUM_BATTLE_FX/baseroms",
  "import did not create the installed mod's baseroms folder")
assert(written[target] == "verified stadium bytes",
  "import did not copy the ROM into the installed mod folder")
assert(removed[1] == "picked_stadium.z64",
  "successful Android pick was not retired")
assert(pushed == 1, "successful import did not open the cache builder")
assert(Picker.importRow().value() == "REPLACE")

local bad, badErr = Picker._store("bad bytes", "bad.z64")
assert(not bad and badErr == "wrong ROM", "invalid ROM was accepted")
local escaped, escapedErr = Picker._installedPath("baseroms/baserom.z64")
assert(escaped == target and escapedErr == nil)
local unsafePicker = assert(loadfile("lib/StadiumRomPicker.lua"))({
  mod = { path = "mods/STADIUM_BATTLE_FX/nested" },
  require = function(name) return assert(modules[name], name) end,
  log = { info = function() end, warn = function() end },
})
assert(not unsafePicker._installedPath("baseroms/baserom.z64"),
  "nested mod path escaped the installed mod root")

romPresent = false
love.filesystem.read = function(path)
  if path == "picked_stadium.z64" then return "bad bytes" end
end
assert(not Picker.poll(game), "invalid staged ROM reported success")
assert(removed[2] == "picked_stadium.z64",
  "invalid Android pick was not retired")
assert(written[target] == "verified stadium bytes",
  "invalid staged ROM replaced the verified baserom")

-- Older Android hosts stage an unknown picker kind under the Game Boy name.
-- It is accepted only while the Stadium action is pending and only after the
-- same Stadium cartridge validation.
love.filesystem.getInfo = function(path, kind)
  if path == "picked_rom.gb" and kind == "file" then return { type = "file" } end
end
love.filesystem.read = function(path)
  if path == "picked_rom.gb" then return "verified stadium bytes" end
end
romPresent = false
assert(Picker.import(game), "legacy-host Stadium picker did not open")
assert(Picker.poll(game), "legacy Android picker destination was not consumed")
assert(removed[3] == "picked_rom.gb",
  "legacy Android picker result was not retired")
assert(written[target] == "verified stadium bytes",
  "legacy Android picker did not install the verified Stadium ROM")

assert(Picker.refreshRow().step(game))
assert(pushed == 3, "refresh still opens the cache builder")

love = hostLove
print("ok Stadium ROM import into installed mod folder")
return true

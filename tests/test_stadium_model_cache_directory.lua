local loader = love and love.filesystem and love.filesystem.load or loadfile
local hostLove = love
local directories, calls = {}, {}
love = { filesystem = {
  getInfo = function(path)
    if directories[path] then return { type = "directory" } end
  end,
  createDirectory = function(path)
    calls[#calls + 1] = path
    local parent = path:match("^(.*)/[^/]+$")
    if parent and not directories[parent] then return false, "missing parent" end
    directories[path] = true
    return true
  end,
} }
local V = { require = function(name)
  if name == "StadiumPack" then
    return { CACHE_DIR = "stadium_battle_fx/models/v6" }
  end
  assert(name == "ModStorage")
  return {}
end }
local Install = assert(loader("lib/StadiumInstall.lua"))(V)
local ok, err = Install._ensureCacheDirectory()
assert(ok, "fresh model cache tree was not created: " .. tostring(err))
assert(#calls == 0, "mod.storage cache unexpectedly wrote a filesystem path")
love = hostLove
print("ok fresh standalone model cache directory tree")

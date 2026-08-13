local loader = love and love.filesystem and love.filesystem.load or loadfile
local hostLove = love

-- Match the Gen1Recomp behavior that exposed the bug: one call may create a
-- child only when its parent already exists.
local directories, calls = {}, {}
love = {
  filesystem = {
    getInfo = function(path)
      if directories[path] then return { type = "directory" } end
      return nil
    end,
    createDirectory = function(path)
      calls[#calls + 1] = path
      local parent = path:match("^(.*)/[^/]+$")
      if parent and not directories[parent] then
        return false, "parent directory is missing"
      end
      directories[path] = true
      return true
    end,
  },
}

local Assets = assert(loader("lib/StadiumAssets.lua"))({
  require = function(name)
    assert(name == "ModStorage")
    return { bundledRom = function() return nil end }
  end,
})
assert(type(Assets.refresh) == "function", "effect cache has no forced refresh")
local ok, err = Assets._ensureCacheDirectory()
assert(ok, "fresh cache tree was not created: " .. tostring(err))
assert(#calls == 0, "mod.storage cache unexpectedly wrote a filesystem path")

love = hostLove
print("ok fresh effect cache directory tree")

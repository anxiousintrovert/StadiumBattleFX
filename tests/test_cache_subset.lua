local loader = love and love.filesystem and love.filesystem.load or loadfile
local hostLove = love

local cacheDir = "stadium_battle_fx/effects/v3/"
local markerPath = cacheDir .. "cache.info"
local assetPath = cacheDir .. "beam_core.ia8"
local bytes = string.rep("\0", 8192)
-- Adler-style checksum used by StadiumAssets: a remains 1 for zero bytes and
-- b accumulates that 1 once per byte.
local marker = "SFXC3 3\nbeam_core 8192 "
  .. tostring(8192 * 65536 + 1) .. "\n"

local files = {
  [markerPath] = marker,
  [assetPath] = bytes,
}

love = {
  filesystem = {
    getInfo = function(path)
      if files[path] then return { type = "file" } end
      return nil
    end,
    read = function(path) return files[path] end,
    getDirectoryItems = function() return {} end,
  },
  image = {
    newImageData = function() return {} end,
  },
  graphics = {
    newImage = function()
      return { setFilter = function() end }
    end,
    newQuad = function() return {} end,
  },
}

local Assets = assert(loader("lib/StadiumAssets.lua"))()
local ok, err = Assets.has({ "beam_core" })
assert(ok, "valid required cache subset was rejected: " .. tostring(err))
assert(Assets.get("beam_core"), "required subset was not uploaded")
local status = Assets.status()
assert(status.assets == 1 and not status.ready,
  "subset recovery must not claim the complete cache is ready")

local missing, missingErr = Assets.has({ "screen_grain" })
assert(not missing and type(missingErr) == "string",
  "missing cache entry did not retain a clean fallback")
assert(missingErr:find("no .z64", 1, true),
  "subset recovery masked the actionable missing-ROM diagnosis")

love = hostLove
print("ok required cache subsets survive missing cosmetic entries")

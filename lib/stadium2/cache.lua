local V = ...
local Storage = V.require("ModStorage")
local Writer = V.cacheWriter
local Cache = {}
local availability = {}

-- M03 adds decoded Stadium 2 pose and auxiliary-animation streams.  Older
-- appearance-only packs must not be selected for the native-pose experiment.
Cache.FORMAT = "S2G1M03"
Cache.ROOT = "stadium2_gen1_model_pack"
Cache.NORMAL = Cache.ROOT .. "/normal"
Cache.SHINY = Cache.ROOT .. "/shiny"
Cache.BATTLE = Cache.ROOT .. "/battle"
Cache.MARKER = Cache.ROOT .. "/pack.info"
Cache.ERROR = Cache.ROOT .. "/import_error.log"
Cache.UNOWN_FORMS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function packaged(path)
  if Writer and Writer.read then return Writer.read(path) end
  return Storage.bundled("cache/" .. path)
end

local function file(path)
  return packaged(path) ~= nil
end

local function invalidateAvailability()
  availability = {}
end

function Cache.path(species, variant)
  local dir = variant == "shiny" and Cache.SHINY or Cache.NORMAL
  return ("%s/%03d.dsm"):format(dir, species)
end

function Cache.specialPath(name)
  return ("%s/%s.dsm"):format(Cache.BATTLE,tostring(name))
end

function Cache.unownPath(letter,variant)
  letter=tostring(letter or "a"):lower()
  local suffix=variant=="shiny" and "_shiny" or ""
  return Cache.specialPath("unown_"..letter..suffix)
end

function Cache.ensureDirectories()
  if Writer and Writer.ensure then
    return Writer.ensure({ Cache.ROOT, Cache.NORMAL, Cache.SHINY, Cache.BATTLE })
  end
  return false, "Stadium 2 caches are created by the external personalized-pack builder"
end

function Cache.clear(count)
  invalidateAvailability()
  if Writer and Writer.clear then
    return Writer.clear(Cache.ROOT, math.min(151, math.max(1, tonumber(count) or 151)))
  end
  return Cache.ensureDirectories()
end

function Cache.writeSpecial(name,bytes)
  invalidateAvailability()
  if Writer and Writer.write then return Writer.write(Cache.specialPath(name), bytes) end
  return false, "Stadium 2 caches are read-only inside the mod"
end

function Cache.writePair(species, normalBytes, shinyBytes)
  invalidateAvailability()
  if Writer and Writer.write then
    local ok, err = Writer.write(Cache.path(species, "normal"), normalBytes)
    if not ok then return false, err end
    return Writer.write(Cache.path(species, "shiny"), shinyBytes)
  end
  return false, "Stadium 2 caches are read-only inside the mod"
end

local function parseMarker(text)
  if type(text) ~= "string" then return nil end
  local row = {}
  for line in text:gmatch("[^\r\n]+") do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key then row[key] = value end
  end
  row.count = tonumber(row.count)
  return row
end

function Cache.marker()
  local text = packaged(Cache.MARKER)
  return type(text) == "string" and parseMarker(text) or nil
end

function Cache.available(count)
  count = tonumber(count) or 151
  -- The mod entry loads before a playthrough is attached. A false result at
  -- that point must not be memoized or a completed runtime cache would look
  -- absent for the rest of the process.
  if Writer and Writer.active and not Writer.active() then return false end
  if availability[count] ~= nil then return availability[count] end
  local marker = Cache.marker()
  if not marker or marker.format ~= Cache.FORMAT or (marker.count or 0) < count then
    availability[count] = false
    return false
  end
  for species = 1, count do
    if not file(Cache.path(species, "normal"))
        or not file(Cache.path(species, "shiny")) then
      availability[count] = false
      return false
    end
  end
  if not file(Cache.specialPath("substitute")) then
    availability[count] = false
    return false
  end
  availability[count] = true
  return true
end

function Cache.finish(meta, count)
  invalidateAvailability()
  if Writer and Writer.write then
    local text = table.concat({
      "format=" .. Cache.FORMAT,
      "count=" .. tostring(count),
      "md5=" .. tostring(meta and meta.md5 or "unknown"),
      "title=" .. tostring(meta and meta.title or "unknown"),
      "byte_order=" .. tostring(meta and meta.byteOrder or "unknown"),
    }, "\n") .. "\n"
    return Writer.write(Cache.MARKER, text)
  end
  return false, "Stadium 2 caches are finalized by the external builder"
end

Cache.invalidateAvailability = invalidateAvailability

function Cache.writeError(text)
  if Writer and Writer.write then
    return Writer.write(Cache.ERROR, tostring(text or "unknown error") .. "\n")
  end
  return false
end

function Cache.read(species, variant)
  local path = Cache.path(species, variant)
  return packaged(path)
end

function Cache.readSpecial(name)
  local path=Cache.specialPath(name)
  return packaged(path)
end

return Cache

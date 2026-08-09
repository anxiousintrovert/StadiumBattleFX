-- Private, ROM-derived cache for the shared Stadium primitives used by the
-- first party-sized move set. Nothing here reads or writes another mod.

local Assets = {}

local ROM_SIZE = 32 * 1024 * 1024
local ARCHIVE = 0x8CC000
local VRAM_BASE = 0x8FF00000
local CRC1, CRC2 = 0x90F5D9B3, 0x9D0EDCF0
local CACHE_DIR = "stadium_battle_fx/effects/v3"
local CACHE_MARKER = CACHE_DIR .. "/cache.info"
local CACHE_FORMAT, CACHE_REV = "SFXC3", 3

-- Each range is tied to a fragment asset-table entry and a renderer format
-- in pret/pokestadium. Only these texture bytes are retained.
local SPECS = {
  { name = "impact_ia", member = 0x00, slot = 0x52, offset = 0x1120,
    format = "ia8", width = 32, height = 32, frames = 4, bytes = 0x1000 },
  { name = "impact_i", member = 0x00, slot = 0x53, offset = 0x2120,
    format = "i4", width = 32, height = 32, frames = 8, bytes = 0x1000 },
  { name = "scratch_claw", member = 0x0B, slot = 0x1A, offset = 0x0050,
    format = "i4", width = 32, height = 32, frames = 8, bytes = 0x1000 },
  { name = "scratch_spark", member = 0x0B, slot = 0x08, offset = 0x1050,
    format = "i4", width = 24, height = 24, frames = 8, bytes = 0x0900 },
  { name = "scratch_swipe", member = 0x0B, slot = 0x19, offset = 0x1950,
    format = "i4", width = 64, height = 64, frames = 1, bytes = 0x0800 },
  { name = "electric", member = 0x0F, slot = 0x13, offset = 0x4860,
    format = "i4", width = 32, height = 96, frames = 8, bytes = 0x3000 },
  { name = "sand", member = 0x16, slot = 0x65, offset = 0x0030,
    format = "i4", width = 32, height = 32, frames = 8, bytes = 0x1000 },
  { name = "thunder_wave", member = 0x1C, slot = 0x0B, offset = 0x0030,
    format = "i4", width = 64, height = 64, frames = 1, bytes = 0x0800 },

  -- Shared beam/projectile bundle. The formats, dimensions, and frame
  -- strides come directly from fragment 34's loader functions selected by
  -- fragment 62's D_84385E40 descriptor table.
  { name = "beam_spark", member = 0x03, slot = 0x08, offset = 0x0060,
    format = "i4", width = 24, height = 24, frames = 8, bytes = 0x0900 },
  { name = "beam_core", member = 0x03, slot = 0x11, offset = 0x0960,
    format = "ia8", width = 32, height = 32, frames = 8, bytes = 0x2000 },
  { name = "beam_ring", member = 0x03, slot = 0x17, offset = 0x2960,
    format = "i4", width = 32, height = 32, frames = 4, bytes = 0x0800 },
  { name = "beam_orb", member = 0x03, slot = 0x05, offset = 0x3160,
    format = "i4", width = 32, height = 32, frames = 8, bytes = 0x1000 },
  { name = "beam_flare", member = 0x03, slot = 0x0E, offset = 0x4160,
    format = "i4", width = 32, height = 32, frames = 4, bytes = 0x0800 },
  { name = "beam_impact", member = 0x03, slot = 0x02, offset = 0x4960,
    format = "ia8", width = 32, height = 32, frames = 4, bytes = 0x1000 },
  { name = "beam_star", member = 0x03, slot = 0x03, offset = 0x5960,
    format = "i4", width = 32, height = 32, frames = 1, bytes = 0x0200 },

  -- Razor Leaf's resource member mixes colored RGBA16 leaves with animated
  -- I4 masks. Keeping those formats distinct preserves the cartridge color
  -- rather than tinting every primitive white.
  { name = "leaf_green", member = 0x0A, slot = 0x1C, offset = 0x0050,
    format = "rgba16", width = 32, height = 32, frames = 1, bytes = 0x0800 },
  { name = "leaf_glint", member = 0x0A, slot = 0x1D, offset = 0x0850,
    format = "i4", width = 32, height = 32, frames = 1, bytes = 0x0200 },
  { name = "leaf_spin", member = 0x0A, slot = 0x1A, offset = 0x0A50,
    format = "i4", width = 32, height = 32, frames = 8, bytes = 0x1000 },
  { name = "leaf_red", member = 0x0A, slot = 0xC3, offset = 0x1A50,
    format = "rgba16", width = 32, height = 32, frames = 1, bytes = 0x0800 },
  { name = "leaf_gold", member = 0x0A, slot = 0x1E, offset = 0x2250,
    format = "rgba16", width = 32, height = 32, frames = 1, bytes = 0x0800 },

  { name = "poison_field", member = 0x0E, slot = 0x70, offset = 0x0050,
    format = "ia8", width = 64, height = 64, frames = 1, bytes = 0x1000 },
  { name = "thunder_orb", member = 0x0F, slot = 0x12, offset = 0x0860,
    format = "i4", width = 64, height = 64, frames = 8, bytes = 0x4000 },

  -- Member 0x11 is reused by fire, drain, psychic, and explosion programs;
  -- Stadium supplies neutral masks and selects their colors in code.
  { name = "energy_orb", member = 0x11, slot = 0x05, offset = 0x0050,
    format = "i4", width = 32, height = 32, frames = 8, bytes = 0x1000 },
  { name = "energy_core", member = 0x11, slot = 0x64, offset = 0x1050,
    format = "ia8", width = 32, height = 32, frames = 8, bytes = 0x2000 },
  { name = "energy_column", member = 0x11, slot = 0x76, offset = 0x3050,
    format = "ia8", width = 32, height = 64, frames = 8, bytes = 0x4000 },

  { name = "heal_star_a", member = 0x15, slot = 0xA6, offset = 0x1810,
    format = "i4", width = 32, height = 32, frames = 1, bytes = 0x0200 },
  { name = "heal_star_b", member = 0x15, slot = 0xA7, offset = 0x1A10,
    format = "i4", width = 32, height = 32, frames = 1, bytes = 0x0200 },
  { name = "heal_ring", member = 0x15, slot = 0x18, offset = 0x1C10,
    format = "i4", width = 32, height = 32, frames = 16, bytes = 0x2000 },

  { name = "screen_grain", member = 0x18, slot = 0x3F, offset = 0x0060,
    format = "i4", width = 64, height = 64, frames = 1, bytes = 0x0800 },
  { name = "large_burst", member = 0x18, slot = 0x59, offset = 0x0860,
    format = "i4", width = 64, height = 64, frames = 6, bytes = 0x3000 },
  { name = "screen_pulse", member = 0x18, slot = 0x7A, offset = 0x3860,
    format = "ia8", width = 32, height = 32, frames = 9, bytes = 0x2400 },

  -- These are consecutive per-frame slots in their resource fragments.
  { name = "screen_dual", member = 0x02, slot = 0x43, offset = 0x0040,
    format = "i4", width = 32, height = 32, frames = 2, bytes = 0x0400 },
  { name = "water_cycle", member = 0x1A, slot = 0xB8, offset = 0x0050,
    format = "i4", width = 32, height = 32, frames = 5, bytes = 0x0A00 },
  { name = "spectrum_cycle", member = 0x29, slot = 0x8F, offset = 0x0090,
    format = "i4", width = 32, height = 32, frames = 10, bytes = 0x1400 },
  { name = "spectrum_glint", member = 0x29, slot = 0xAC, offset = 0x4490,
    format = "i4", width = 32, height = 32, frames = 1, bytes = 0x0200 },
  { name = "spectrum_star", member = 0x29, slot = 0x99, offset = 0x4690,
    format = "i4", width = 32, height = 32, frames = 1, bytes = 0x0200 },
}

local byName = {}
for _, spec in ipairs(SPECS) do
  spec.path = CACHE_DIR .. "/" .. spec.name .. "." .. spec.format
  byName[spec.name] = spec
end

local loaded, attempted = {}, false
local lastError, lastSource, cacheError
local cacheReady, cachedRaw, job
local MEMBERS, memberSeen = {}, {}
for _, spec in ipairs(SPECS) do
  if not memberSeen[spec.member] then
    memberSeen[spec.member] = true
    MEMBERS[#MEMBERS + 1] = spec.member
  end
end
local progress = {
  state = "idle", done = 0, total = #MEMBERS + #SPECS + #SPECS + 1,
  current = nil, error = nil,
}

local function allLoaded()
  for _, spec in ipairs(SPECS) do
    if not loaded[spec.name] then return false end
  end
  return true
end

local function isFile(path)
  local f = love and love.filesystem
  if not (f and f.getInfo) then return false end
  local ok, info = pcall(f.getInfo, path, "file")
  return ok and info and true or false
end

local function checksum(bytes)
  local a, b = 1, 0
  for i = 1, #bytes do
    a = (a + bytes:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

function Assets.findRom()
  local f = love and love.filesystem
  if not f then return nil end
  for _, ext in ipairs({ "z64", "n64", "v64" }) do
    local path = "baseroms/baserom." .. ext
    if isFile(path) then return path end
  end
  local ok, items = pcall(f.getDirectoryItems, "baseroms")
  if not (ok and items) then return nil end
  table.sort(items)
  for _, name in ipairs(items) do
    if name:lower():match("%.[nvz]64$") then
      local path = "baseroms/" .. name
      if isFile(path) then return path end
    end
  end
end

local Reader = {}
Reader.__index = Reader

function Reader.new(bytes)
  if type(bytes) ~= "string" or #bytes ~= ROM_SIZE then
    return nil, "Pokemon Stadium ROM must be exactly 32 MiB"
  end
  local magic = bytes:sub(1, 4)
  local order
  if magic == "\x80\x37\x12\x40" then order = "z64"
  elseif magic == "\x37\x80\x40\x12" then order = "v64"
  elseif magic == "\x40\x12\x37\x80" then order = "n64"
  else return nil, "file is not a recognized N64 ROM byte order" end
  local self = setmetatable({ bytes = bytes, order = order }, Reader)
  if self:u32(0x10) ~= CRC1 or self:u32(0x14) ~= CRC2 then
    return nil, "needs Pokemon Stadium (USA) v1.0"
  end
  return self
end

function Reader:sourceOffset(offset)
  if self.order == "v64" then
    local word = offset - offset % 2
    return word + (1 - offset % 2)
  elseif self.order == "n64" then
    local word = offset - offset % 4
    return word + (3 - offset % 4)
  end
  return offset
end

function Reader:u8(offset)
  if offset < 0 or offset >= #self.bytes then error("ROM read out of bounds") end
  return self.bytes:byte(self:sourceOffset(offset) + 1)
end

function Reader:u32(offset)
  return ((self:u8(offset) * 256 + self:u8(offset + 1)) * 256
          + self:u8(offset + 2)) * 256 + self:u8(offset + 3)
end

function Reader:read(offset, count)
  if offset < 0 or count < 0 or offset + count > #self.bytes then
    error("ROM read out of bounds")
  end
  if self.order == "z64" then return self.bytes:sub(offset + 1, offset + count) end
  local chunks = {}
  for base = 0, count - 1, 4096 do
    local chars = {}
    local last = math.min(count - 1, base + 4095)
    for i = base, last do chars[#chars + 1] = string.char(self:u8(offset + i)) end
    chunks[#chunks + 1] = table.concat(chars)
  end
  return table.concat(chunks)
end

local function be32(data, offset)
  if offset < 0 or offset + 4 > #data then error("truncated Stadium data") end
  local a, b, c, d = data:byte(offset + 1, offset + 4)
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function be16(data, offset)
  if offset < 0 or offset + 2 > #data then error("truncated Stadium data") end
  local a, b = data:byte(offset + 1, offset + 2)
  return a * 256 + b
end

local function archiveMember(reader, member)
  if reader:u32(ARCHIVE + 4) ~= 0 then error("invalid Stadium effect archive") end
  local count = reader:u32(ARCHIVE + 12)
  if member < 0 or member >= count or count > 4096 then
    error(("Stadium effect bundle %d is missing"):format(member))
  end
  local record = ARCHIVE + 0x10 + member * 0x10
  return reader:read(ARCHIVE + reader:u32(record), reader:u32(record + 4))
end

local function yay0(data, base)
  base = base or 0
  if data:sub(base + 1, base + 4) ~= "Yay0" then error("effect bundle is not Yay0") end
  local size = be32(data, base + 4)
  if size <= 0 or size > 16 * 1024 * 1024 then error("invalid Yay0 size") end
  local maskPos = base + 0x10
  local linkPos = base + be32(data, base + 8)
  local chunkPos = base + be32(data, base + 12)
  local out, mask, bits = {}, 0, 0
  while #out < size do
    if bits == 0 then
      mask = be32(data, maskPos)
      maskPos, bits = maskPos + 4, 32
    end
    if mask >= 0x80000000 then
      local value = data:byte(chunkPos + 1)
      if not value then error("truncated Yay0 literal stream") end
      out[#out + 1], chunkPos = value, chunkPos + 1
    else
      local link = be16(data, linkPos)
      linkPos = linkPos + 2
      local distance = link % 0x1000 + 1
      local count = math.floor(link / 0x1000)
      if count == 0 then
        local extra = data:byte(chunkPos + 1)
        if not extra then error("truncated Yay0 count stream") end
        count, chunkPos = extra + 0x12, chunkPos + 1
      else
        count = count + 2
      end
      local copyPos = #out - distance + 1
      if copyPos < 1 then error("invalid Yay0 back-reference") end
      for _ = 1, count do
        if #out >= size then break end
        out[#out + 1] = out[copyPos]
        copyPos = copyPos + 1
      end
    end
    mask = (mask * 2) % 0x100000000
    bits = bits - 1
  end
  local chunks = {}
  for i = 1, #out, 4096 do
    local chars, last = {}, math.min(#out, i + 4095)
    for j = i, last do chars[#chars + 1] = string.char(out[j]) end
    chunks[#chunks + 1] = table.concat(chars)
  end
  return table.concat(chunks)
end

local function decompress(blob)
  if blob:sub(1, 8) == "PERS-SZP" then return yay0(blob, be32(blob, 8)) end
  if blob:sub(1, 4) == "Yay0" then return yay0(blob, 0) end
  return blob
end

local function assetOffset(fragment, wantedSlot)
  if fragment:sub(9, 16) ~= "FRAGMENT" then error("effect bundle is not a fragment") end
  local tableOffset = be32(fragment, 0x10)
  for pos = tableOffset, math.min(#fragment - 8, tableOffset + 0x1000), 8 do
    local kind = fragment:byte(pos + 1)
    if not kind or kind == 0 then break end
    local slot = be16(fragment, pos + 2)
    local pointer = be32(fragment, pos + 4)
    if slot == wantedSlot then
      local offset = pointer - VRAM_BASE
      if offset < 0 or offset >= #fragment then error("invalid effect asset pointer") end
      return offset
    end
  end
  error(("effect asset slot 0x%X is missing"):format(wantedSlot))
end

local function cacheSpecs(names)
  if names == nil then return SPECS end
  local selected, seen = {}, {}
  for _, name in ipairs(names) do
    local spec = byName[name]
    if not spec then return nil, "unknown Stadium asset " .. tostring(name) end
    if not seen[name] then
      seen[name] = true
      selected[#selected + 1] = spec
    end
  end
  return selected
end

local function readCache(names)
  local f = love and love.filesystem
  if not (f and isFile(CACHE_MARKER)) then return nil end
  local ok, marker = pcall(f.read, CACHE_MARKER)
  if not (ok and type(marker) == "string") then return nil, "could not read effect cache marker" end
  local lines = {}
  for line in marker:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
  if lines[1] ~= CACHE_FORMAT .. " " .. CACHE_REV then
    return nil, "effect cache is from an older format"
  end
  local records = {}
  for i = 2, #lines do
    local name, size, sum = lines[i]:match("^(%S+)%s+(%d+)%s+(%d+)$")
    if name then records[name] = { size = tonumber(size), sum = tonumber(sum) } end
  end
  local specs, selectErr = cacheSpecs(names)
  if not specs then return nil, selectErr end
  local raw = {}
  for _, spec in ipairs(specs) do
    local rec = records[spec.name]
    if not (rec and isFile(spec.path)) then return nil, "effect cache is incomplete" end
    local okRead, bytes = pcall(f.read, spec.path)
    if not (okRead and type(bytes) == "string" and #bytes == spec.bytes
        and rec.size == spec.bytes and rec.sum == checksum(bytes)) then
      return nil, "effect cache failed its integrity check"
    end
    raw[spec.name] = bytes
  end
  return raw
end

local function writeCache(raw)
  local f = love and love.filesystem
  if not (f and f.write) then return false, "filesystem cache is unavailable" end
  if f.createDirectory then pcall(f.createDirectory, CACHE_DIR) end
  local lines = { CACHE_FORMAT .. " " .. CACHE_REV }
  for _, spec in ipairs(SPECS) do
    local bytes = raw[spec.name]
    local ok, wrote, err = pcall(f.write, spec.path, bytes)
    if not (ok and wrote) then return false, tostring(err or wrote or "asset write failed") end
    lines[#lines + 1] = ("%s %d %d"):format(spec.name, #bytes, checksum(bytes))
  end
  local ok, wrote, err = pcall(f.write, CACHE_MARKER, table.concat(lines, "\n") .. "\n")
  if not (ok and wrote) then return false, tostring(err or wrote or "marker write failed") end
  return true
end

local function cacheMarker(raw)
  local lines = { CACHE_FORMAT .. " " .. CACHE_REV }
  for _, spec in ipairs(SPECS) do
    local bytes = raw[spec.name]
    lines[#lines + 1] = ("%s %d %d"):format(
      spec.name, #bytes, checksum(bytes))
  end
  return table.concat(lines, "\n") .. "\n"
end

local function extractAll(path)
  local okRead, bytes = pcall(love.filesystem.read, path)
  if not (okRead and type(bytes) == "string") then return nil, "could not read " .. path end
  local reader, err = Reader.new(bytes)
  if not reader then return nil, err end
  local raw = {}
  local ok, extractErr = pcall(function()
    for _, member in ipairs(MEMBERS) do
      local fragment = decompress(archiveMember(reader, member))
      for _, spec in ipairs(SPECS) do
        if spec.member == member then
          local offset = assetOffset(fragment, spec.slot)
          if offset ~= spec.offset then
            error(("%s moved to 0x%X; expected 0x%X"):format(spec.name, offset, spec.offset))
          end
          local value = fragment:sub(offset + 1, offset + spec.bytes)
          if #value ~= spec.bytes then error(spec.name .. " texture is truncated") end
          raw[spec.name] = value
        end
      end
      fragment = nil
      collectgarbage("collect")
    end
  end)
  reader, bytes = nil, nil
  collectgarbage("collect")
  if not ok then return nil, tostring(extractErr) end
  return raw
end

local function rgbaAtlas(spec, bytes)
  local framePixels = spec.width * spec.height
  local rows = {}
  for y = 0, spec.height - 1 do
    for frame = 0, spec.frames - 1 do
      local pixelBase = frame * framePixels + y * spec.width
      for x = 0, spec.width - 1 do
        local pixel = pixelBase + x
        if spec.format == "i4" then
          local packed = bytes:byte(math.floor(pixel / 2) + 1)
          local value = (pixel % 2 == 0) and math.floor(packed / 16) or packed % 16
          rows[#rows + 1] = string.char(255, 255, 255, value * 17)
        elseif spec.format == "ia8" then
          local packed = bytes:byte(pixel + 1)
          local intensity, alpha = math.floor(packed / 16) * 17, (packed % 16) * 17
          rows[#rows + 1] = string.char(intensity, intensity, intensity, alpha)
        elseif spec.format == "rgba16" then
          local hi, lo = bytes:byte(pixel * 2 + 1, pixel * 2 + 2)
          local packed = hi * 256 + lo
          local red = math.floor(packed / 0x800) % 0x20
          local green = math.floor(packed / 0x40) % 0x20
          local blue = math.floor(packed / 0x2) % 0x20
          rows[#rows + 1] = string.char(
            math.floor(red * 255 / 31), math.floor(green * 255 / 31),
            math.floor(blue * 255 / 31), packed % 2 == 1 and 255 or 0)
        else
          error("unsupported cached Stadium texture format " .. tostring(spec.format))
        end
      end
    end
  end
  return table.concat(rows)
end

function Assets.specs()
  local out = {}
  for i, spec in ipairs(SPECS) do
    out[i] = { name = spec.name, member = spec.member, slot = spec.slot,
      offset = spec.offset, format = spec.format, width = spec.width,
      height = spec.height, frames = spec.frames, bytes = spec.bytes }
  end
  return out
end

local function makeAsset(spec, bytes, source)
  local ok, value = pcall(function()
    local atlasWidth = spec.width * spec.frames
    local data = love.image.newImageData(atlasWidth, spec.height, "rgba8", rgbaAtlas(spec, bytes))
    local image = love.graphics.newImage(data)
    image:setFilter("linear", "linear")
    local quads = {}
    for frame = 0, spec.frames - 1 do
      quads[frame + 1] = love.graphics.newQuad(frame * spec.width, 0,
        spec.width, spec.height, atlasWidth, spec.height)
    end
    return { name = spec.name, image = image, quads = quads,
      frameWidth = spec.width, frameHeight = spec.height, frames = spec.frames,
      format = spec.format, source = source, cachePath = spec.path }
  end)
  if not ok then return nil, tostring(value) end
  return value
end

local function build()
  local raw, err = readCache()
  if raw then
    lastSource = "cache"
  else
    cacheError = err
    local path = Assets.findRom()
    if not path then return nil, "no .z64/.n64/.v64 file in baseroms/" end
    raw, err = extractAll(path)
    if not raw then return nil, err end
    local wrote, writeErr = writeCache(raw)
    if not wrote then cacheError = "could not write effect cache: " .. tostring(writeErr) end
    if wrote then
      cacheReady, cachedRaw = true, raw
    end
    lastSource = "rom"
  end
  local result = {}
  for _, spec in ipairs(SPECS) do
    local asset, makeErr = makeAsset(spec, raw[spec.name], lastSource)
    if not asset then return nil, makeErr end
    result[spec.name] = asset
  end
  return result
end

-- A damaged cosmetic entry must not make otherwise valid cached primitives
-- unusable. The normal preload remains strict and builds the complete set;
-- this path validates and uploads only the assets a particular move requires.
local function loadCachedSubset(names)
  local missing = {}
  for _, name in ipairs(names or {}) do
    if not loaded[name] then missing[#missing + 1] = name end
  end
  if #missing == 0 then return true end

  local raw, err = readCache(missing)
  if not raw then return nil, err or "effect cache is unavailable" end
  for _, name in ipairs(missing) do
    local spec = byName[name]
    local asset, makeErr = makeAsset(spec, raw[name], "cache")
    if not asset then return nil, makeErr end
    loaded[name] = asset
  end
  lastSource = lastSource or "cache"
  return true
end

-- A marker is accepted only after every cached primitive passes its size and
-- checksum. Keep the validated bytes around: the whole party set is small,
-- and this avoids reading it a second time when the first battle starts.
function Assets.ready()
  if progress.state == "building" then return false end
  if allLoaded() then return true end
  if cacheReady ~= nil then return cacheReady end
  local raw, err = readCache()
  cacheReady = raw and true or false
  if raw then
    cachedRaw = raw
    cacheError = nil
  else
    cacheError = err
  end
  return cacheReady
end

function Assets.pending()
  if Assets.ready() then return false end
  return Assets.findRom() ~= nil
end

-- Start a first-run extraction job. ROM loading and validation happen once;
-- subsequent step() calls decompress one archive member, write one primitive,
-- or upload one texture. That makes progress visible and keeps a long burst
-- of work out of the first attack animation.
function Assets.begin()
  if job and progress.state == "building" then return true end
  if Assets.ready() then
    progress.state, progress.done = "done", progress.total
    progress.current, progress.error = "READY", nil
    return true
  end
  local path = Assets.findRom()
  if not path then return false, "no .z64/.n64/.v64 file in baseroms/" end
  local okRead, bytes = pcall(love.filesystem.read, path)
  if not (okRead and type(bytes) == "string") then
    return false, "could not read " .. path
  end
  local reader, err = Reader.new(bytes)
  if not reader then return false, err end
  if love.filesystem.createDirectory then
    pcall(love.filesystem.createDirectory, CACHE_DIR)
  end
  job = {
    reader = reader, bytes = bytes, raw = {}, member = 1, write = 1,
    make = 1, phase = "extract", marker = nil, path = path,
  }
  progress.state, progress.done = "building", 0
  progress.current, progress.error = "READING STADIUM ROM", nil
  attempted, lastError, lastSource = false, nil, nil
  return true
end

local function failJob(err)
  lastError = tostring(err or "unknown cache error")
  progress.state, progress.error = "failed", lastError
  progress.current = "CACHE FAILED"
  job = nil
  collectgarbage("collect")
  return false
end

function Assets.step()
  if not job or progress.state ~= "building" then return false end
  local ok, err = pcall(function()
    if job.phase == "extract" then
      local member = MEMBERS[job.member]
      progress.current = ("EXTRACTING BUNDLE %02X"):format(member)
      local fragment = decompress(archiveMember(job.reader, member))
      for _, spec in ipairs(SPECS) do
        if spec.member == member then
          local offset = assetOffset(fragment, spec.slot)
          if offset ~= spec.offset then
            error(("%s moved to 0x%X; expected 0x%X")
              :format(spec.name, offset, spec.offset))
          end
          local value = fragment:sub(offset + 1, offset + spec.bytes)
          if #value ~= spec.bytes then error(spec.name .. " texture is truncated") end
          job.raw[spec.name] = value
        end
      end
      fragment = nil
      job.member = job.member + 1
      progress.done = progress.done + 1
      if job.member > #MEMBERS then
        job.reader, job.bytes = nil, nil
        job.phase = "write"
        collectgarbage("collect")
      end
      return
    end

    if job.phase == "write" then
      local spec = SPECS[job.write]
      progress.current = "CACHING " .. spec.name:upper()
      local wrote, writeErr = love.filesystem.write(spec.path, job.raw[spec.name])
      if not wrote then error(writeErr or ("could not write " .. spec.path)) end
      job.write = job.write + 1
      progress.done = progress.done + 1
      if job.write > #SPECS then
        job.marker = cacheMarker(job.raw)
        job.phase = "upload"
      end
      return
    end

    if job.phase == "upload" then
      local spec = SPECS[job.make]
      progress.current = "LOADING " .. spec.name:upper()
      local asset, makeErr = makeAsset(spec, job.raw[spec.name], "rom")
      if not asset then error(makeErr) end
      loaded[spec.name] = asset
      job.make = job.make + 1
      progress.done = progress.done + 1
      if job.make > #SPECS then job.phase = "finish" end
      return
    end

    progress.current = "FINALIZING CACHE"
    local wrote, writeErr = love.filesystem.write(CACHE_MARKER, job.marker)
    if not wrote then error(writeErr or "could not write effect cache marker") end
    progress.done = progress.total
    progress.state, progress.current = "done", "READY"
    cacheReady, cachedRaw = true, job.raw
    attempted, lastSource, lastError, cacheError = true, "rom", nil, nil
    job = nil
    collectgarbage("collect")
  end)
  if not ok then return failJob(err) end
  return progress.state == "building"
end

function Assets.cancel()
  job = nil
  if progress.state == "building" then
    progress.state, progress.current = "idle", nil
    progress.done = 0
  end
  collectgarbage("collect")
end

function Assets.preload()
  if progress.state == "building" then return nil, "effect cache build is in progress" end
  if allLoaded() then return true end
  if attempted then return nil, lastError end
  attempted = true
  local result
  if cachedRaw then
    result = {}
    lastSource = lastSource or "cache"
    for _, spec in ipairs(SPECS) do
      local asset, makeErr = makeAsset(spec, cachedRaw[spec.name], lastSource)
      if not asset then lastError = makeErr break end
      result[spec.name] = asset
    end
    if lastError then result = nil end
  else
    result, lastError = build()
  end
  if result then loaded = result end
  return result and true or nil, lastError
end

function Assets.get(name)
  Assets.preload()
  local asset = loaded[name]
  if asset then return asset end
  return nil, lastError or ("Stadium asset %s is unavailable"):format(tostring(name))
end

function Assets.has(names)
  names = names or {}
  if #names == 0 then return true end
  local present = true
  for _, name in ipairs(names) do
    if not loaded[name] then present = false break end
  end
  if present then return true end

  local ok, err = Assets.preload()
  if not ok then
    local subsetOk, subsetErr = loadCachedSubset(names)
    if not subsetOk then return nil, subsetErr or err end
  end
  for _, name in ipairs(names) do
    if not loaded[name] then
      return nil, "missing Stadium asset " .. tostring(name)
    end
  end
  return true
end

function Assets.status()
  local count = 0
  for _ in pairs(loaded) do count = count + 1 end
  return { ready = count == #SPECS, assets = count, expected = #SPECS,
    attempted = attempted, source = lastSource, path = Assets.findRom(),
    cachePath = CACHE_MARKER, cacheError = cacheError,
    state = progress.state, done = progress.done, total = progress.total,
    current = progress.current, error = progress.error or lastError }
end

return Assets

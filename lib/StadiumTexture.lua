-- Runtime extraction of the one verified Thunder Shock texture.
--
-- This mirrors DramaticShapeVoxelMod's public baseroms convention but is
-- otherwise independent: flat `baseroms/`, preferred baserom.* names, then
-- any .z64/.n64/.v64 in lexical order. Nothing is written to that mod or to
-- its private cache.

local V = ...
local StadiumTexture = {}

local ROM_SIZE = 32 * 1024 * 1024
local ARCHIVE = 0x8CC000
local MEMBER = 0x0F
local SLOT = 0x13
local VRAM_BASE = 0x8FF00000
local ASSET_OFFSET = 0x4860
local FRAME_W, FRAME_H, FRAMES = 32, 96, 8
local FRAME_BYTES = FRAME_W * FRAME_H / 2
local TEXTURE_BYTES = FRAME_BYTES * FRAMES
local CRC1, CRC2 = 0x90F5D9B3, 0x9D0EDCF0
local CACHE_DIR = "stadium_battle_fx/effects"
local CACHE_FILE = CACHE_DIR .. "/084_thundershock.i4"
local CACHE_MARKER = CACHE_DIR .. "/084_thundershock.info"
local CACHE_FORMAT, CACHE_REV = "SFXC1", 1

local cached
local attempted = false
local lastError
local lastSource
local cacheError

local function isFile(path)
  local f = love and love.filesystem
  if not (f and f.getInfo) then return false end
  local ok, info = pcall(f.getInfo, path, "file")
  return ok and info and true or false
end

-- Adler-32 is only an integrity check here. The source ROM is validated
-- separately before extraction; this catches truncated or half-written cache
-- data without paying to load the 32 MiB cartridge again on every boot.
local function checksum(bytes)
  local a, b = 1, 0
  for i = 1, #bytes do
    a = (a + bytes:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

local function readCache()
  local f = love and love.filesystem
  if not f or not isFile(CACHE_MARKER) or not isFile(CACHE_FILE) then return nil end
  local okMarker, marker = pcall(f.read, CACHE_MARKER)
  local okData, bytes = pcall(f.read, CACHE_FILE)
  if not (okMarker and type(marker) == "string"
      and okData and type(bytes) == "string") then
    return nil, "could not read cached Thunder Shock texture"
  end
  local format, rev, size, sum = marker:match("^(%S+)%s+(%d+)%s+(%d+)%s+(%d+)")
  if format ~= CACHE_FORMAT or tonumber(rev) ~= CACHE_REV then
    return nil, "cached Thunder Shock texture is from an older format"
  end
  if tonumber(size) ~= TEXTURE_BYTES or #bytes ~= TEXTURE_BYTES
      or tonumber(sum) ~= checksum(bytes) then
    return nil, "cached Thunder Shock texture failed its integrity check"
  end
  return bytes
end

-- The marker is written last, so an interrupted first build never makes a
-- partial texture count as usable. love.filesystem writes only to the game's
-- save directory; this cannot touch Dramaless Shape or either mod folder.
local function writeCache(bytes)
  local f = love and love.filesystem
  if not (f and f.write) then return false, "filesystem cache is unavailable" end
  if f.createDirectory then pcall(f.createDirectory, CACHE_DIR) end
  local okData, wroteData, dataErr = pcall(f.write, CACHE_FILE, bytes)
  if not (okData and wroteData) then
    return false, tostring(dataErr or wroteData or "texture write failed")
  end
  local marker = ("%s %d %d %d\n"):format(
    CACHE_FORMAT, CACHE_REV, #bytes, checksum(bytes))
  local okMarker, wroteMarker, markerErr = pcall(f.write, CACHE_MARKER, marker)
  if not (okMarker and wroteMarker) then
    return false, tostring(markerErr or wroteMarker or "marker write failed")
  end
  return true
end

function StadiumTexture.findRom()
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
  return nil
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
    return nil, "needs Pokemon Stadium (US) 1.0"
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
  local out = {}
  for i = 0, count - 1 do out[i + 1] = string.char(self:u8(offset + i)) end
  return table.concat(out)
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

local function archiveMember(reader)
  if reader:u32(ARCHIVE + 4) ~= 0 then error("invalid Stadium effect archive") end
  local count = reader:u32(ARCHIVE + 12)
  if MEMBER >= count or count > 4096 then error("Stadium effect bundle is missing") end
  local record = ARCHIVE + 0x10 + MEMBER * 0x10
  local relative, size = reader:u32(record), reader:u32(record + 4)
  return reader:read(ARCHIVE + relative, size)
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
    local last = math.min(i + 4095, #out)
    local chars = {}
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

local function assetOffset(fragment)
  if fragment:sub(9, 16) ~= "FRAGMENT" then error("effect bundle is not a fragment") end
  local tableOffset = be32(fragment, 0x10)
  for pos = tableOffset, math.min(#fragment - 8, tableOffset + 0x1000), 8 do
    local kind = fragment:byte(pos + 1)
    if not kind or kind == 0 then break end
    local slot = be16(fragment, pos + 2)
    local pointer = be32(fragment, pos + 4)
    if slot == SLOT then
      local offset = pointer - VRAM_BASE
      if offset < 0 or offset >= #fragment then error("invalid effect asset pointer") end
      return offset
    end
  end
  error("Thunder Shock texture slot is missing")
end

local function rgbaAtlas(texture)
  if #texture ~= TEXTURE_BYTES then error("Thunder Shock texture is truncated") end
  local rows = {}
  for y = 0, FRAME_H - 1 do
    for frame = 0, FRAMES - 1 do
      local row = frame * FRAME_BYTES + y * (FRAME_W / 2)
      for x = 0, FRAME_W / 2 - 1 do
        local packed = texture:byte(row + x + 1)
        local hi, lo = math.floor(packed / 16) * 17, (packed % 16) * 17
        rows[#rows + 1] = string.char(255, 255, 255, hi, 255, 255, 255, lo)
      end
    end
  end
  return table.concat(rows)
end

local function extractFromRom(path)
  local okRead, bytes = pcall(love.filesystem.read, path)
  if not (okRead and type(bytes) == "string") then return nil, "could not read " .. path end
  local reader, err = Reader.new(bytes)
  if not reader then return nil, err end
  local ok, texture = pcall(function()
    local fragment = decompress(archiveMember(reader))
    local offset = assetOffset(fragment)
    if offset ~= ASSET_OFFSET then error("unexpected Thunder Shock texture offset") end
    return fragment:sub(offset + 1, offset + TEXTURE_BYTES)
  end)
  bytes = nil
  reader = nil
  collectgarbage("collect")
  if not ok then return nil, tostring(texture) end
  if #texture ~= TEXTURE_BYTES then return nil, "Thunder Shock texture is truncated" end
  return texture
end

local function makeAsset(texture, path, source)
  local ok, result = pcall(function()
    local data = love.image.newImageData(FRAME_W * FRAMES, FRAME_H,
                                         "rgba8", rgbaAtlas(texture))
    local image = love.graphics.newImage(data)
    image:setFilter("linear", "linear")
    local quads = {}
    for frame = 0, FRAMES - 1 do
      quads[frame + 1] = love.graphics.newQuad(frame * FRAME_W, 0,
        FRAME_W, FRAME_H, FRAME_W * FRAMES, FRAME_H)
    end
    return { image = image, quads = quads, path = path,
             source = source, cachePath = CACHE_FILE,
             frameWidth = FRAME_W, frameHeight = FRAME_H, frames = FRAMES }
  end)
  if not ok then return nil, tostring(result) end
  return result
end

local function build()
  local texture, cachedErr = readCache()
  if texture then
    lastSource = "cache"
    return makeAsset(texture, CACHE_FILE, lastSource)
  end
  cacheError = cachedErr

  local path = StadiumTexture.findRom()
  if not path then return nil, "no .z64/.n64/.v64 file in baseroms/" end
  local err
  texture, err = extractFromRom(path)
  if not texture then return nil, err end
  local wrote, writeErr = writeCache(texture)
  if not wrote then cacheError = "could not cache Thunder Shock: " .. tostring(writeErr) end
  lastSource = "rom"
  return makeAsset(texture, path, lastSource)
end

function StadiumTexture.get()
  if cached then return cached end
  if attempted then return nil, lastError end
  attempted = true
  cached, lastError = build()
  return cached, lastError
end

function StadiumTexture.status()
  return { ready = cached ~= nil, attempted = attempted,
           path = cached and cached.path or StadiumTexture.findRom(),
           source = lastSource, cachePath = CACHE_FILE,
           cacheError = cacheError, error = lastError }
end

return StadiumTexture

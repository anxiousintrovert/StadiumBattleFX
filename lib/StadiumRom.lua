-- Safe, extraction-agnostic access to Pokemon Stadium ROM data.
--
-- Offsets are zero-based. Every read is bounds checked. This module knows how
-- to identify and normalize an N64 dump, but deliberately knows nothing about
-- battle effects yet.

local StadiumRom = {}

StadiumRom.EXPECTED_SIZE = 32 * 1024 * 1024
StadiumRom.EXPECTED_MD5 = "ed1378bc12115f71209a77844965ba50"

local MAGIC = {
  z64 = string.char(0x80, 0x37, 0x12, 0x40),
  v64 = string.char(0x37, 0x80, 0x40, 0x12),
  n64 = string.char(0x40, 0x12, 0x37, 0x80),
}

local function failure(code, message)
  return nil, { code = code, message = message }
end

function StadiumRom.detectByteOrder(bytes)
  if type(bytes) ~= "string" then
    return failure("not_string", "ROM data must be a byte string")
  end
  if #bytes < 4 then
    return failure("truncated", "ROM is too small to contain an N64 header")
  end
  local magic = bytes:sub(1, 4)
  for order, expected in pairs(MAGIC) do
    if magic == expected then return order end
  end
  return failure("bad_magic", "file does not have a recognized N64 ROM byte order")
end

function StadiumRom.normalize(bytes)
  local order, err = StadiumRom.detectByteOrder(bytes)
  if not order then return nil, err end
  if order == "z64" then return bytes, order end

  if order == "v64" then
    if #bytes % 2 ~= 0 then
      return failure("truncated", "v64 ROM length is not divisible by two")
    end
    return (bytes:gsub("(.)(.)", "%2%1")), order
  end

  if #bytes % 4 ~= 0 then
    return failure("truncated", "n64 ROM length is not divisible by four")
  end
  return (bytes:gsub("(.)(.)(.)(.)", "%4%3%2%1")), order
end

local function lowercaseHex(value)
  if type(value) ~= "string" then return nil end
  return value:gsub("%s", ""):lower()
end

-- hashFn is injectable for headless tests. In LÖVE it may be omitted.
function StadiumRom.md5(bytes, hashFn)
  if hashFn then
    local ok, digest = pcall(hashFn, bytes)
    if not ok then
      return failure("hash_failed", "MD5 provider failed: " .. tostring(digest))
    end
    digest = lowercaseHex(digest)
    if digest and #digest == 32 then return digest end
    return failure("hash_failed", "MD5 provider did not return 32 hexadecimal characters")
  end

  if not (love and love.data and love.data.hash and love.data.encode) then
    return failure("hash_unavailable", "LÖVE MD5 support is unavailable")
  end

  local ok, digest = pcall(love.data.hash, "md5", bytes)
  if not ok then
    return failure("hash_failed", "LÖVE could not hash the ROM: " .. tostring(digest))
  end
  if type(digest) == "userdata" and digest.getString then
    digest = digest:getString()
  end
  local encodedOk, encoded = pcall(love.data.encode, "string", "hex", digest)
  if not encodedOk then
    return failure("hash_failed", "LÖVE could not encode the MD5 digest")
  end
  return lowercaseHex(encoded)
end

function StadiumRom.inspect(bytes, hashFn)
  local normalized, orderOrError = StadiumRom.normalize(bytes)
  if not normalized then return nil, orderOrError end

  if #normalized ~= StadiumRom.EXPECTED_SIZE then
    return failure("wrong_size", ("unsupported Stadium ROM size: %d bytes; expected %d")
      :format(#normalized, StadiumRom.EXPECTED_SIZE))
  end

  local digest, hashError = StadiumRom.md5(normalized, hashFn)
  if not digest then return nil, hashError end
  if digest ~= StadiumRom.EXPECTED_MD5 then
    return failure("unsupported_revision",
      "unsupported Pokemon Stadium ROM; expected USA v1.0")
  end

  return {
    normalized = normalized,
    sourceOrder = orderOrError,
    size = #normalized,
    md5 = digest,
    revision = "Pokemon Stadium (USA) v1.0",
  }
end

local Reader = {}
Reader.__index = Reader

local function integer(value)
  return type(value) == "number" and value == math.floor(value)
end

function Reader:_range(offset, width)
  if not integer(offset) or not integer(width) then
    return failure("bad_range", "ROM offset and width must be integers")
  end
  if offset < 0 or width < 0 then
    return failure("bad_range", "ROM offset and width cannot be negative")
  end
  if offset > self.size or width > self.size - offset then
    return failure("out_of_bounds", ("ROM read 0x%X..0x%X exceeds size 0x%X")
      :format(offset, offset + width, self.size))
  end
  return offset + 1, offset + width
end

function Reader:slice(offset, width)
  local first, lastOrError = self:_range(offset, width)
  if not first then return nil, lastOrError end
  return self.data:sub(first, lastOrError)
end

function Reader:u8(offset)
  local first, err = self:_range(offset, 1)
  if not first then return nil, err end
  return self.data:byte(first)
end

function Reader:u16be(offset)
  local first, err = self:_range(offset, 2)
  if not first then return nil, err end
  local a, b = self.data:byte(first, first + 1)
  return a * 0x100 + b
end

function Reader:u32be(offset)
  local first, err = self:_range(offset, 4)
  if not first then return nil, err end
  local a, b, c, d = self.data:byte(first, first + 3)
  return ((a * 0x100 + b) * 0x100 + c) * 0x100 + d
end

function Reader:release()
  self.data = nil
  self.size = 0
end

function StadiumRom.reader(normalizedBytes)
  if type(normalizedBytes) ~= "string" then
    return failure("not_string", "normalized ROM data must be a byte string")
  end
  if normalizedBytes:sub(1, 4) ~= MAGIC.z64 then
    return failure("not_normalized", "ROM reader requires normalized z64 byte order")
  end
  return setmetatable({ data = normalizedBytes, size = #normalizedBytes }, Reader)
end

return StadiumRom

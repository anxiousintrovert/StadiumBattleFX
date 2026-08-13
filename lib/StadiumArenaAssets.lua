-- ROM-local converter for Pokemon Stadium's native Gym Leader Castle stages.
-- Battle mode loads members 7..16 from stadium_models. Each member is a
-- relocatable N64 fragment containing geometry layouts, F3DEX display lists,
-- vertices and textures. We convert only those bounded members into a small,
-- checksummed cache; the ROM and executable MIPS code are never retained.

local V = ...
local ArenaAssets = {}
local Storage = V.require("ModStorage")

local ARCHIVE = 0x56E7D0
local CACHE_DIR = "stadium_battle_fx/arenas/v1"
local MARKER = CACHE_DIR .. "/cache.info"
local FORMAT = "SAC1 4"
local NATIVE_MAGIC = "SNA2"

local MEMBERS = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
local VENUE_MEMBER = {
  brock = 7, misty = 8, surge = 9, erika = 10, koga = 11,
  sabrina = 12, blaine = 13, giovanni = 14,
  elite4 = 15, champion = 16,
}

local GEO_SIZE = {
  [0]=8,4,8,8,4,4,4,8,12,4,8,24,4,4,4,4,4,4,4,8,
  12,12,4,20,8,8,4,16,16,28,8,24,20,16,8,16,4,4,20,
}

local stages = {}
local job
local validated
local progress = { state = "idle", done = 0, total = #MEMBERS + 1 }

local function pathFor(member)
  return ("%s/member_%02d.native"):format(CACHE_DIR, member)
end

local function checksum(bytes)
  local a, b = 1, 0
  for i = 1, #bytes do
    a = (a + bytes:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

local function u8(data, offset)
  local value = data:byte(offset + 1)
  if not value then error("truncated native Stadium stage") end
  return value
end

local function u16(data, offset)
  local a, b = data:byte(offset + 1, offset + 2)
  if not b then error("truncated native Stadium stage") end
  return a * 256 + b
end

local function s16(data, offset)
  local value = u16(data, offset)
  return value >= 0x8000 and value - 0x10000 or value
end

local function u32(data, offset)
  local a, b, c, d = data:byte(offset + 1, offset + 4)
  if not d then error("truncated native Stadium stage") end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function be16(value)
  value = value % 0x10000
  return string.char(math.floor(value / 256), value % 256)
end

local function be32(value)
  value = value % 0x100000000
  return string.char(math.floor(value / 0x1000000) % 256,
    math.floor(value / 0x10000) % 256,
    math.floor(value / 0x100) % 256, value % 256)
end

local function fragmentOffset(address, limit)
  if address < 0x8FF00000 or address >= 0x90000000 then return nil end
  local offset = address % 0x100000
  if offset >= limit then return nil end
  return offset
end

local function archiveMember(rom, member)
  if u32(rom, ARCHIVE + 4) ~= 0 then error("invalid stadium_models archive") end
  local count = u32(rom, ARCHIVE + 12)
  if member < 0 or member >= count then error("native Stadium stage is missing") end
  local record = ARCHIVE + 0x10 + member * 0x10
  local offset, size = u32(rom, record), u32(rom, record + 4)
  return rom:sub(ARCHIVE + offset + 1, ARCHIVE + offset + size)
end

local function yay0(data, base)
  base = base or 0
  if data:sub(base + 1, base + 4) ~= "Yay0" then
    error("native Stadium stage is not Yay0")
  end
  local size = u32(data, base + 4)
  if size <= 0 or size > 0x100000 then error("invalid native stage size") end
  local maskPos = base + 0x10
  local linkPos = base + u32(data, base + 8)
  local chunkPos = base + u32(data, base + 12)
  local out, mask, bits = {}, 0, 0
  while #out < size do
    if bits == 0 then
      mask = u32(data, maskPos)
      maskPos, bits = maskPos + 4, 32
    end
    if mask >= 0x80000000 then
      out[#out + 1] = u8(data, chunkPos)
      chunkPos = chunkPos + 1
    else
      local link = u16(data, linkPos)
      linkPos = linkPos + 2
      local distance = link % 0x1000 + 1
      local count = math.floor(link / 0x1000)
      if count == 0 then
        count, chunkPos = u8(data, chunkPos) + 0x12, chunkPos + 1
      else count = count + 2 end
      local copy = #out - distance + 1
      if copy < 1 then error("invalid native stage back-reference") end
      for _ = 1, count do
        if #out >= size then break end
        out[#out + 1] = out[copy]
        copy = copy + 1
      end
    end
    mask = (mask * 2) % 0x100000000
    bits = bits - 1
  end
  local chunks = {}
  for start = 1, #out, 4096 do
    local row = {}
    for i = start, math.min(#out, start + 4095) do
      row[#row + 1] = string.char(out[i])
    end
    chunks[#chunks + 1] = table.concat(row)
  end
  return table.concat(chunks)
end

local function decompress(blob)
  if blob:sub(1, 8) == "PERS-SZP" then return yay0(blob, u32(blob, 8)) end
  if blob:sub(1, 4) == "Yay0" then return yay0(blob) end
  error("native Stadium stage has an unknown container")
end

local function findRom()
  return (Storage.bundledRom())
end

local function rootLayouts(fragment, relocOffset)
  local roots, textureTable = {}, nil
  for offset = 0x20, relocOffset - 20, 4 do
    if u8(fragment, offset) == 0x17 then
      local tableAddress, vertexAddress = u32(fragment, offset + 8),
        u32(fragment, offset + 16)
      if fragmentOffset(tableAddress, relocOffset)
          and fragmentOffset(vertexAddress, relocOffset) then
        textureTable = textureTable or fragmentOffset(tableAddress, relocOffset)
        local cursor = offset
        while cursor < math.min(relocOffset, offset + 64) do
          local command = u8(fragment, cursor)
          local size = GEO_SIZE[command]
          if not size then break end
          if command == 3 then
            local target = fragmentOffset(u32(fragment, cursor + 4), relocOffset)
            if target then roots[#roots + 1] = target end
            break
          end
          cursor = cursor + size
        end
      end
    end
  end
  if not textureTable or #roots == 0 then
    error("native Stadium stage has no convertible scene roots")
  end
  return roots, textureTable
end

local function geometryGroups(fragment, relocOffset, roots)
  local groups, used, active = {}, {}, { texture = -1, rgba = "\255\255\255\255" }
  local walking = {}
  local function walk(cursor, layer)
    if walking[cursor] then return end
    walking[cursor] = true
    for _ = 1, 2048 do
      if cursor < 0 or cursor >= relocOffset then error("native geo layout escaped fragment") end
      local command = u8(fragment, cursor)
      local size = GEO_SIZE[command]
      if not size then error("unsupported native geo command " .. command) end
      if command == 35 then
        active.texture = s16(fragment, cursor + 8)
        active.rgba = fragment:sub(cursor + 13, cursor + 16)
      elseif command == 34 then
        local address = u32(fragment, cursor + 4)
        local gfx = fragmentOffset(address, relocOffset)
        if address ~= 0 and not gfx then error("native display list escaped fragment") end
        if gfx and not used[gfx] then
          used[gfx] = true
          groups[#groups + 1] = {
            texture = active.texture, rgba = active.rgba, gfx = gfx,
            layer = layer,
          }
        end
      elseif command == 0 or command == 3 then
        local target = fragmentOffset(u32(fragment, cursor + 4), relocOffset)
        if target then walk(target, layer) end
      elseif command == 2 then
        local target = fragmentOffset(u32(fragment, cursor + 4), relocOffset)
        if target then walk(target, layer) end
        break
      end
      cursor = cursor + size
      if command == 1 or command == 4 then break end
    end
  end
  for layer, root in ipairs(roots) do walk(root, layer) end
  if #groups < 8 or #groups > 128 then error("implausible native material group count") end
  return groups
end

local function convertGfx(fragment, relocOffset, gfx)
  local slots, vertices, vertexMap, indices = {}, {}, {}, {}
  local function vertex(source)
    local found = vertexMap[source]
    if found then return found end
    if source < 0 or source + 16 > relocOffset then error("native vertex escaped fragment") end
    found = #vertices + 1
    vertices[found], vertexMap[source] = fragment:sub(source + 1, source + 16), found
    return found
  end
  local cursor = gfx
  for _ = 1, 8192 do
    if cursor + 8 > relocOffset then error("native display list escaped fragment") end
    local word0, word1 = u32(fragment, cursor), u32(fragment, cursor + 4)
    local opcode = math.floor(word0 / 0x1000000)
    cursor = cursor + 8
    if opcode == 0x01 then
      local count = math.floor(word0 / 0x1000) % 256
      local v0 = math.floor(word0 / 2) % 128 - count
      local source = fragmentOffset(word1, relocOffset)
      if not source or count < 1 or count > 32 or v0 < 0 then
        error("invalid native vertex load")
      end
      for i = 0, count - 1 do slots[v0 + i] = source + i * 16 end
    elseif opcode == 0x05 or opcode == 0x06 then
      local list = {
        math.floor(word0 / 0x10000) % 256,
        math.floor(word0 / 0x100) % 256, word0 % 256,
      }
      if opcode == 0x06 then
        list[#list + 1] = math.floor(word1 / 0x10000) % 256
        list[#list + 1] = math.floor(word1 / 0x100) % 256
        list[#list + 1] = word1 % 256
      end
      for i = 1, #list do
        local source = slots[math.floor(list[i] / 2)]
        if not source then error("native triangle references an unloaded vertex") end
        indices[#indices + 1] = vertex(source)
      end
    elseif opcode == 0xDF then
      break
    elseif opcode ~= 0xD9 and opcode ~= 0xFB and opcode ~= 0xFC then
      error(("unsupported native display-list opcode %02X"):format(opcode))
    end
  end
  if #indices < 3 or #indices % 3 ~= 0 then error("native geometry has no triangles") end
  return vertices, indices
end

local function textureFor(fragment, relocOffset, tableOffset, material)
  if material < 0 then return 0, 2, 1, 1, "" end
  local descriptor = tableOffset + material * 12
  if descriptor + 12 > relocOffset then error("native texture descriptor escaped fragment") end
  local fmt, size = u8(fragment, descriptor), u8(fragment, descriptor + 1)
  local width, height = s16(fragment, descriptor + 2), s16(fragment, descriptor + 4)
  local source = fragmentOffset(u32(fragment, descriptor + 8), relocOffset)
  if fmt > 4 or size > 3 or width < 1 or height < 1
      or width > 512 or height > 512 or not source then
    error("invalid native texture descriptor")
  end
  local bytes = math.ceil(width * height * (4 * 2 ^ size) / 8)
  if source + bytes > relocOffset then error("native texture escaped fragment") end
  return fmt, size, width, height, fragment:sub(source + 1, source + bytes)
end

local function convert(fragment)
  if fragment:sub(9, 16) ~= "FRAGMENT" then error("invalid native Stadium fragment") end
  local relocOffset = u32(fragment, 0x14)
  if relocOffset < 0x40 or relocOffset > #fragment then error("invalid native relocation boundary") end
  local roots, textureTable = rootLayouts(fragment, relocOffset)
  local groups = geometryGroups(fragment, relocOffset, roots)
  local out = { NATIVE_MAGIC, be16(#groups) }
  for _, group in ipairs(groups) do
    local vertices, indices = convertGfx(fragment, relocOffset, group.gfx)
    local fmt, size, width, height, texture =
      textureFor(fragment, relocOffset, textureTable, group.texture)
    out[#out + 1] = be16(group.texture) .. string.char(fmt, size)
      .. be16(width) .. be16(height) .. be32(#texture)
      .. be32(#vertices) .. be32(#indices) .. group.rgba
      .. string.char(group.layer or 0, 0, 0, 0)
    out[#out + 1] = texture
    out[#out + 1] = table.concat(vertices)
    local map = {}
    for _, index in ipairs(indices) do map[#map + 1] = be16(index) end
    out[#out + 1] = table.concat(map)
  end
  return table.concat(out)
end

local function readMarker()
  local marker = Storage.read("arenas/cache")
  if type(marker) ~= "table" then return nil, "native arena cache marker is missing" end
  if marker.format ~= FORMAT then
    return nil, "arena cache is from the non-native format"
  end
  local records = marker.records or {}
  for _, member in ipairs(MEMBERS) do
    local record = records[tostring(member)]
    local bytes = Storage.bytes(("arenas/stages/member_%02d"):format(member))
    if not (record and record.size > 128 and record.size < 0x200000
        and type(bytes) == "string") then
      return nil, "native arena cache is incomplete"
    end
    if #bytes ~= record.size or bytes:sub(1, 4) ~= NATIVE_MAGIC
        or checksum(bytes) ~= record.sum then
      return nil, "native arena cache failed its integrity check"
    end
  end
  return true
end

function ArenaAssets.ready()
  if validated ~= nil then return validated end
  if not Storage.active() then return false end
  local ok = readMarker()
  validated = ok and true or false
  return validated
end

function ArenaAssets.pending()
  return not ArenaAssets.ready() and findRom() ~= nil
end

function ArenaAssets.begin(force)
  if job then return true end
  if not force and ArenaAssets.ready() then
    progress.state, progress.done, progress.current = "done", progress.total, "READY"
    return true
  end
  local path = findRom()
  if not path then return false, "no Stadium ROM in baseroms/" end
  local source = Storage.bundled(path)
  local StadiumRom = V.require("StadiumRom")
  local inspected = StadiumRom.inspect(source)
  if not inspected then return false, "arena cache failed incorrect version or rom" end
  job = { rom = inspected.normalized, index = 1, records = {} }
  validated = nil
  progress.state, progress.done, progress.current, progress.error =
    "building", 0, "READING NATIVE STADIUM STAGES", nil
  return true
end

function ArenaAssets.step()
  if not job or progress.state ~= "building" then return false end
  local ok, err = pcall(function()
    local member = MEMBERS[job.index]
    if member then
      progress.current = ("CONVERTING NATIVE STAGE %02d"):format(member)
      local native = convert(decompress(archiveMember(job.rom, member)))
      local wrote, writeCode, writeErr = Storage.writeBytes(
        ("arenas/stages/member_%02d"):format(member), native)
      if not wrote then error(writeErr or "could not cache native Stadium stage") end
      job.records[tostring(member)] = { size = #native, sum = checksum(native) }
      job.index = job.index + 1
      progress.done = progress.done + 1
      return
    end
    local wrote, writeCode, writeErr = Storage.write("arenas/cache", {
      format = FORMAT, records = job.records,
    })
    if not wrote then error(writeErr or "could not finalize native arena cache") end
    job, validated = nil, true
    progress.state, progress.done, progress.current = "done", progress.total, "READY"
    collectgarbage("collect")
  end)
  if not ok then
    job = nil
    progress.state, progress.error, progress.current = "failed", tostring(err), "CACHE FAILED"
    return false
  end
  return progress.state == "building"
end

local function rgbaTexture(fmt, size, width, height, bytes)
  if #bytes == 0 then return "\255\255\255\255" end
  local out, pixel = {}, 0
  local function push(i, a) out[#out + 1] = string.char(i, i, i, a or 255) end
  while pixel < width * height do
    if fmt == 0 and size == 2 then
      local packed = u16(bytes, pixel * 2)
      out[#out + 1] = string.char(math.floor(packed / 0x800) % 32 * 255 / 31,
        math.floor(packed / 0x40) % 32 * 255 / 31,
        math.floor(packed / 2) % 32 * 255 / 31, packed % 2 == 1 and 255 or 0)
    elseif fmt == 0 and size == 3 then
      out[#out + 1] = bytes:sub(pixel * 4 + 1, pixel * 4 + 4)
    elseif fmt == 3 and size == 0 then
      local nibble = u8(bytes, math.floor(pixel / 2))
      nibble = pixel % 2 == 0 and math.floor(nibble / 16) or nibble % 16
      push(math.floor(nibble / 2) * 255 / 7, nibble % 2 == 1 and 255 or 0)
    elseif fmt == 3 and size == 1 then
      local packed = u8(bytes, pixel)
      push(math.floor(packed / 16) * 17, packed % 16 * 17)
    elseif fmt == 3 and size == 2 then
      local intensity, alpha = bytes:byte(pixel * 2 + 1, pixel * 2 + 2)
      push(intensity, alpha)
    elseif fmt == 4 and size == 0 then
      local nibble = u8(bytes, math.floor(pixel / 2))
      nibble = pixel % 2 == 0 and math.floor(nibble / 16) or nibble % 16
      push(nibble * 17)
    elseif fmt == 4 and size == 1 then
      push(u8(bytes, pixel))
    else
      error(("unsupported native texture format %d/%d"):format(fmt, size))
    end
    pixel = pixel + 1
  end
  return table.concat(out)
end

local function signedByte(value) return value >= 128 and value - 256 or value end

local function vertexShade(raw, offset)
  local nx, ny, nz = signedByte(u8(raw, offset + 12)),
    signedByte(u8(raw, offset + 13)), signedByte(u8(raw, offset + 14))
  local length = math.sqrt(nx * nx + ny * ny + nz * nz)
  if length > 32 and length < 190 then
    local dot = (nx * .36 + ny * .82 + nz * .44) / length
    return math.max(.48, math.min(1, .58 + math.max(0, dot) * .42))
  end
  return math.max(.48, math.min(1, (u8(raw, offset + 12)
    + u8(raw, offset + 13) + u8(raw, offset + 14)) / 765))
end

local function imageFor(fmt, size, width, height, bytes)
  local rgba = rgbaTexture(fmt, size, width, height, bytes)
  local data = love.image.newImageData(width, height, "rgba8", rgba)
  local image = love.graphics.newImage(data)
  image:setFilter("nearest", "nearest")
  image:setWrap("repeat", "repeat")
  return image
end

local function appendBossCourt(stage, voxel)
  local solid, stageTexture
  for _, group in ipairs(stage.groups) do
    if group.material == -1 then solid = group.texture break end
  end
  local widestFloor = 0
  for _, group in ipairs(stage.groups) do
    local bounds = group.bounds
    if bounds and bounds.maxXZ > widestFloor and bounds.minY > -200
        and bounds.maxY < 300 then
      widestFloor, stageTexture = bounds.maxXZ, group.texture
    end
  end
  if not solid then
    solid = imageFor(0, 2, 1, 1, "")
    stage.resources[#stage.resources + 1] = solid
  end

  local function vertex(x, y, z, u, v)
    return { x, y, z, u or 0, v or 0, 1 }
  end
  local function disc(radius, y, segments)
    local vertices, indices = { vertex(0, y, 0) }, {}
    for index = 0, segments - 1 do
      local angle = index * math.pi * 2 / segments
      vertices[#vertices + 1] = vertex(math.cos(angle) * radius, y,
        math.sin(angle) * radius)
    end
    for index = 0, segments - 1 do
      indices[#indices + 1] = 1
      indices[#indices + 1] = index + 2
      indices[#indices + 1] = ((index + 1) % segments) + 2
    end
    return voxel.newMesh(vertices, indices)
  end
  local function ring(inner, outer, y, segments)
    local vertices, indices = {}, {}
    for index = 0, segments - 1 do
      local angle = index * math.pi * 2 / segments
      local c, s = math.cos(angle), math.sin(angle)
      vertices[#vertices + 1] = vertex(c * inner, y, s * inner)
      vertices[#vertices + 1] = vertex(c * outer, y, s * outer)
    end
    for index = 0, segments - 1 do
      local a, b = index * 2 + 1, index * 2 + 2
      local c, d = ((index + 1) % segments) * 2 + 1,
        ((index + 1) % segments) * 2 + 2
      indices[#indices + 1] = a
      indices[#indices + 1] = b
      indices[#indices + 1] = d
      indices[#indices + 1] = a
      indices[#indices + 1] = d
      indices[#indices + 1] = c
    end
    return voxel.newMesh(vertices, indices)
  end
  local function bar(halfWidth, halfDepth, y)
    return voxel.newMesh({
      vertex(-halfWidth, y, -halfDepth), vertex(halfWidth, y, -halfDepth),
      vertex(halfWidth, y, halfDepth), vertex(-halfWidth, y, halfDepth),
    }, { 1, 2, 3, 1, 3, 4 })
  end
  local function platform(halfWidth, halfDepth, y)
    return voxel.newMesh({
      vertex(-halfWidth, y, -halfDepth, 0, 0),
      vertex(halfWidth, y, -halfDepth, 12, 0),
      vertex(halfWidth, y, halfDepth, 12, 8),
      vertex(-halfWidth, y, halfDepth, 0, 8),
    }, { 1, 2, 3, 1, 3, 4 })
  end
  local function rectangularRim(outerX, outerZ, innerX, innerZ, y)
    local vertices = {
      vertex(-outerX, y, -outerZ), vertex(outerX, y, -outerZ),
      vertex(outerX, y, outerZ), vertex(-outerX, y, outerZ),
      vertex(-innerX, y, -innerZ), vertex(innerX, y, -innerZ),
      vertex(innerX, y, innerZ), vertex(-innerX, y, innerZ),
    }
    return voxel.newMesh(vertices, {
      1, 2, 6, 1, 6, 5,
      2, 3, 7, 2, 7, 6,
      3, 4, 8, 3, 8, 7,
      4, 1, 5, 4, 5, 8,
    })
  end
  local function add(mesh, tint, part, maxXZ, texture)
    if not mesh then return end
    stage.resources[#stage.resources + 1] = mesh
    stage.groups[#stage.groups + 1] = {
      mesh = mesh, texture = texture or solid, tint = tint,
      material = -1, layer = 3, court = part, noShadow = true,
      bounds = { maxXZ = maxXZ, minY = 0, maxY = 7 },
    }
  end

  -- Stadium's low centre meshes form venue-specific emblems. Keep
  -- the physical battle platform independent from the replacement mark. The
  -- platform must not be circular: a circular rim around the room reads as a
  -- second screen-sized Poké Ball. This 2400x1600 native-textured rectangle
  -- makes the 500-unit mark visibly subordinate and contained. Slightly
  -- separated Y levels prevent coplanar flicker.
  add(platform(1200, 800, 0), { 1, 1, 1, 1 }, "stage-field", 1200,
    stageTexture or solid)
  add(rectangularRim(1200, 800, 1140, 740, 2), { .67, .65, .70, 1 },
    "stage-rim", 1200)
  add(disc(225, 3, 64), { .38, .37, .42, 1 }, "logo-field", 225)
  add(ring(225, 250, 4, 64), { .88, .86, .90, 1 }, "logo-outer-ring", 250)
  add(bar(245, 10, 5), { .88, .86, .90, 1 }, "logo-divider", 245)
  add(disc(50, 6, 48), { .38, .37, .42, 1 }, "logo-button-fill", 50)
  add(ring(50, 65, 7, 48), { .88, .86, .90, 1 }, "logo-button-ring", 65)
end

local function loadStage(member, voxel, wantedLayer)
  local bytes = Storage.bytes(("arenas/stages/member_%02d"):format(member))
  if type(bytes) ~= "string" or bytes:sub(1, 4) ~= NATIVE_MAGIC then
    return nil, "native arena cache is unreadable"
  end
  local count, cursor = u16(bytes, 4), 6
  local stage = { groups = {}, resources = {}, member = member }
  local textures = {}
  for _ = 1, count do
    local material, fmt, size = s16(bytes, cursor), u8(bytes, cursor + 2), u8(bytes, cursor + 3)
    local width, height = u16(bytes, cursor + 4), u16(bytes, cursor + 6)
    local textureBytes, vertexCount, indexCount = u32(bytes, cursor + 8),
      u32(bytes, cursor + 12), u32(bytes, cursor + 16)
    local rgba = { bytes:byte(cursor + 21, cursor + 24) }
    local layer = u8(bytes, cursor + 24)
    cursor = cursor + 28
    local textureRaw = bytes:sub(cursor + 1, cursor + textureBytes)
    cursor = cursor + textureBytes
    local vertexRaw = bytes:sub(cursor + 1, cursor + vertexCount * 16)
    cursor = cursor + vertexCount * 16
    local vertices = {}
    local maxXZ, minY, maxY = 0, math.huge, -math.huge
    for index = 0, vertexCount - 1 do
      local at = index * 16
      local x, y, z = s16(vertexRaw, at), s16(vertexRaw, at + 2),
        s16(vertexRaw, at + 4)
      maxXZ = math.max(maxXZ, math.abs(x), math.abs(z))
      minY, maxY = math.min(minY, y), math.max(maxY, y)
      vertices[#vertices + 1] = {
        x, y, z,
        s16(vertexRaw, at + 8) / (32 * width),
        s16(vertexRaw, at + 10) / (32 * height), vertexShade(vertexRaw, at),
      }
    end
    local indices = {}
    for index = 0, indexCount - 1 do indices[#indices + 1] = u16(bytes, cursor + index * 2) end
    cursor = cursor + indexCount * 2
    if not wantedLayer or layer == wantedLayer then
      local texture = textures[material]
      if not texture then
        texture = imageFor(fmt, size, width, height, textureRaw)
        textures[material] = texture
        stage.resources[#stage.resources + 1] = texture
      end
      local mesh = voxel.newMesh(vertices, indices)
      if not mesh then return nil, "could not create native Stadium mesh" end
      stage.resources[#stage.resources + 1] = mesh
      stage.groups[#stage.groups + 1] = {
        mesh = mesh, texture = texture,
        tint = { rgba[1] / 255, rgba[2] / 255, rgba[3] / 255, rgba[4] / 255 },
        material = material, layer = layer,
        floorMark = ((member >= 7 and member <= 14 and layer == 3
            and maxXZ < 1600 and maxY <= 0)
          or (member >= 15 and layer == 1 and minY == 0 and maxY == 0
            and maxXZ <= 1300)) or false,
        bounds = { maxXZ = maxXZ, minY = minY, maxY = maxY },
        -- Retain bounds for diagnostics and camera work. Stadium draws these
        -- groups too: large/deep groups are the circular arena and foundation,
        -- while tall groups form the enclosing Gym Leader Castle chamber.
        -- Earlier builds misclassified them as disposable scenery and reduced
        -- Brock's room to its small inset platform.
      }
    end
  end
  stage.nativeGroupCount = #stage.groups
  if not wantedLayer then appendBossCourt(stage, voxel) end
  return stage
end

function ArenaAssets.get(venue, voxel)
  if stages[venue] then return stages[venue] end
  local member = VENUE_MEMBER[venue]
  if not member then return nil, "unknown native Stadium arena " .. tostring(venue) end
  if not ArenaAssets.ready() then local _, err = readMarker() return nil, err end
  if not (voxel and voxel.newMesh) then return nil, "native arena renderer is unavailable" end
  local ok, stage, err = pcall(loadStage, member, voxel)
  if not ok then return nil, tostring(stage) end
  if not stage then return nil, err end
  stages[venue] = stage
  return stage
end

local function releaseStages()
  local released = {}
  for venue, stage in pairs(stages) do
    for _, item in ipairs(stage.resources or {}) do
      if item and not released[item] and item.release then pcall(item.release, item) end
      released[item] = true
    end
    stages[venue] = nil
  end
end

function ArenaAssets.refresh()
  ArenaAssets.cancel()
  releaseStages()
  validated = nil
  return ArenaAssets.begin(true)
end

function ArenaAssets.cancel()
  job = nil
  if progress.state == "building" then progress.state, progress.done, progress.current = "idle", 0, nil end
end

function ArenaAssets.invalidate()
  releaseStages()
end

function ArenaAssets.status()
  return { state = progress.state, done = progress.done, total = progress.total,
    current = progress.current, error = progress.error, ready = ArenaAssets.ready(),
    cachePath = MARKER, source = "Pokemon Stadium (USA) v1.0 stadium_models 7..16" }
end

ArenaAssets.VENUE_MEMBER = VENUE_MEMBER
ArenaAssets.CACHE_DIR = CACHE_DIR

return ArenaAssets

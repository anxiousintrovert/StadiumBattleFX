local loader = love and love.filesystem and love.filesystem.load or loadfile
local romPath = os.getenv("STADIUM_ROM")
if not romPath or romPath == "" then
  print("skip Stadium arena cache extraction (STADIUM_ROM not set)")
  return
end

local function diskRead(path)
  local file = assert(io.open(path, "rb"))
  local bytes = file:read("*a")
  file:close()
  return bytes
end

local virtual = {}
local originalFilesystem = love.filesystem
love.filesystem = {
  load = originalFilesystem.load,
  getInfo = function(path, kind)
    if path == "baseroms/baserom.z64" then return { type = "file" } end
    if virtual[path] ~= nil then return { type = "file" } end
    if kind == "directory" then return nil end
  end,
  getDirectoryItems = function(path)
    return path == "baseroms" and { "baserom.z64" } or {}
  end,
  createDirectory = function() return true end,
  read = function(path)
    if path == "baseroms/baserom.z64" then return diskRead(romPath) end
    return virtual[path]
  end,
  write = function(path, bytes)
    virtual[path] = bytes
    return true
  end,
}

local StadiumRom = assert(loader("lib/StadiumRom.lua"))({})
local records = {}
local Storage = {
  active = function() return true end,
  bundledRom = function()
    return "baseroms/baserom.z64", diskRead(romPath)
  end,
  bundled = function(path)
    if path == "baseroms/baserom.z64" then return diskRead(romPath) end
  end,
  read = function(key) return records[key] end,
  write = function(key, value) records[key] = value return true end,
  writeBytes = function(key, bytes, fields)
    records[key] = fields or {}
    records[key].bytes = bytes
    return true
  end,
  bytes = function(key)
    local value = records[key]
    return value and value.bytes
  end,
}
local Assets = assert(loader("lib/StadiumArenaAssets.lua"))({
  require = function(name)
    if name == "StadiumRom" then return StadiumRom end
    if name == "ModStorage" then return Storage end
    error(name)
  end,
})

assert(Assets.begin(true))
local guard = 0
while Assets.status().state == "building" do
  Assets.step()
  guard = guard + 1
  assert(guard < 20, "arena cache job did not terminate")
end
assert(Assets.ready(), Assets.status().error)

local voxel = {
  newMesh = function(vertices, indices)
    assert(#vertices >= 3 and #indices >= 3 and #indices % 3 == 0)
    return { vertices = vertices, indices = indices }
  end,
}
local counts = {}
for _, venue in ipairs({ "brock", "misty", "surge", "erika", "koga",
    "sabrina", "blaine", "giovanni", "elite4", "champion" }) do
  local stage, err = Assets.get(venue, voxel)
  assert(stage, venue .. ": " .. tostring(err))
  assert(#stage.groups >= 8, venue .. " did not contain a native 3D scene")
  local triangles = 0
  for _, group in ipairs(stage.groups) do
    triangles = triangles + #group.mesh.indices / 3
  end
  assert(triangles >= 100, venue .. " native scene lost geometry")
  counts[venue] = { groups = #stage.groups, triangles = triangles,
    nativeGroups = stage.nativeGroupCount }
  local marks, parts = 0, 0
  for _, group in ipairs(stage.groups) do
    if group.floorMark then marks = marks + 1 end
    if group.court then parts = parts + 1 end
  end
  assert(parts == 7, venue .. " did not receive the complete shared court")
  assert(marks == ((venue == "elite4" or venue == "champion") and 2 or 4),
    venue .. " native center mark was not isolated correctly")
end
assert(Assets.VENUE_MEMBER.brock == 7)
assert(Assets.VENUE_MEMBER.misty == 8)
assert(Assets.VENUE_MEMBER.giovanni == 14)
assert(Assets.VENUE_MEMBER.elite4 == 15)
assert(Assets.VENUE_MEMBER.champion == 16)
assert(counts.misty.nativeGroups == 26 and counts.misty.triangles > 286,
  "Misty did not reproduce native Stadium member 8")
local brock = assert(Assets.get("brock", voxel))
local broadFloor, tallWall, deepFoundation = false, false, false
local nativeMarks, courtParts, stageRadius, logoRadius = 0, 0, 0, 0
for _, group in ipairs(brock.groups) do
  local bounds = group.bounds
  broadFloor = broadFloor or bounds.maxXZ > 4000
  tallWall = tallWall or (bounds.maxXZ > 2300 and bounds.minY > 500
    and bounds.maxY > 1700)
  deepFoundation = deepFoundation or bounds.minY <= -1000
  if group.floorMark then nativeMarks = nativeMarks + 1 end
  if group.court then
    courtParts = courtParts + 1
    if group.court:match("^stage") then
      stageRadius = math.max(stageRadius, bounds.maxXZ)
    else
      logoRadius = math.max(logoRadius, bounds.maxXZ)
    end
  end
end
assert(broadFloor, "Brock's complete outer battle floor was not converted")
assert(tallWall, "Brock's enclosing chamber wall was not converted")
assert(deepFoundation, "Brock's arena foundation was not converted")
assert(nativeMarks == 4, "Brock's four malformed centre overlays were not identified")
assert(courtParts == 7, "Brock's replacement stage and Poké Ball are incomplete")
assert(stageRadius == 1200, "Brock's physical battle platform is missing")
assert(logoRadius == 250, "Brock's Poké Ball logo is not 500 units across")
assert(records["arenas/stages/member_08"].bytes:sub(1, 4) == "SNA2")

love.filesystem = originalFilesystem
print("ok ROM-backed native Stadium arena conversion")

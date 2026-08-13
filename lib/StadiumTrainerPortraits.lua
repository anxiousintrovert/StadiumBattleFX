-- ROM-local Pokemon Stadium trainer portraits used during the opening send-out.
-- Stadium 1 stores these as 64x64 RGBA5551 pictures, not skeletal models.

local V = ...
local Storage = V.require("ModStorage")
local ModelRom = V.require("StadiumModelRom")

local Portraits = {}
local ARCHIVE = 0x533B20
local FORMAT = "STP1"
local COUNT = 43 -- player, bosses, and every Gen-1 trainer class

local CLASS = {
  OPP_YOUNGSTER = 17, OPP_BUG_CATCHER = 15, OPP_LASS = 16,
  OPP_SAILOR = 27, OPP_JR_TRAINER_M = 18, OPP_JR_TRAINER_F = 19,
  OPP_POKEMANIAC = 21, OPP_SUPER_NERD = 20, OPP_HIKER = 25,
  OPP_BIKER = 38, OPP_BURGLAR = 31, OPP_ENGINEER = 37,
  OPP_JUGGLER = 35, OPP_FISHER = 29, OPP_SWIMMER = 40,
  OPP_CUE_BALL = 39, OPP_GAMBLER = 34, OPP_BEAUTY = 22,
  OPP_PSYCHIC_TR = 42, OPP_ROCKER = 36, OPP_TAMER = 41,
  OPP_BIRD_KEEPER = 32, OPP_BLACKBELT = 33, OPP_ROCKET = 43,
  OPP_SCIENTIST = 30, OPP_GENTLEMAN = 28, OPP_CHANNELER = 26,
  OPP_COOLTRAINER_M = 23, OPP_COOLTRAINER_F = 24,
  OPP_BROCK = 2, OPP_MISTY = 3, OPP_LT_SURGE = 4, OPP_ERIKA = 5,
  OPP_KOGA = 6, OPP_SABRINA = 7, OPP_BLAINE = 8, OPP_GIOVANNI = 9,
  OPP_LORELEI = 10, OPP_BRUNO = 11, OPP_AGATHA = 12, OPP_LANCE = 13,
  OPP_RIVAL1 = 14, OPP_RIVAL2 = 14, OPP_RIVAL3 = 14,
}

local status = { state = "idle", done = 0, total = COUNT }
local readyCache, job = nil, nil
local images, silhouettes = {}, {}

local function marker()
  local value = Storage.read("trainers/cache")
  return type(value) == "table" and value or nil
end

function Portraits.ready()
  if readyCache ~= nil then return readyCache end
  local value = marker()
  readyCache = value and value.format == FORMAT and value.count == COUNT or false
  return readyCache
end

function Portraits.pending()
  return not Portraits.ready() and Storage.bundledRom() ~= nil
end

local function rgba5551(data)
  if #data ~= 64 * 64 * 2 then error("unexpected Stadium trainer portrait size") end
  local out, n = {}, 0
  for i = 1, #data, 2 do
    local value = data:byte(i) * 256 + data:byte(i + 1)
    local r = math.floor(value / 0x800) % 32
    local g = math.floor(value / 0x40) % 32
    local b = math.floor(value / 2) % 32
    n = n + 1
    out[n] = string.char(math.floor(r * 255 / 31 + .5),
      math.floor(g * 255 / 31 + .5), math.floor(b * 255 / 31 + .5),
      value % 2 == 1 and 255 or 0)
  end
  return table.concat(out)
end

function Portraits.begin()
  local path, bytes = Storage.bundledRom()
  if not path or type(bytes) ~= "string" then return false, "no Stadium ROM" end
  local rom, err = ModelRom.open(bytes)
  if not rom then return false, err end
  local directory = rom:archive(ARCHIVE)
  if not directory or #directory < COUNT + 1 then
    return false, "Stadium trainer portrait archive is missing"
  end
  readyCache, images, silhouettes = nil, {}, {}
  job = { rom = rom, directory = directory, index = 1 }
  status.state, status.done, status.error = "building", 0, nil
  status.current = "TRAINER 1"
  return true
end

function Portraits.step()
  if not job then return false end
  local index = job.index
  local rec = job.directory[index + 1] -- archive file 0 is the unknown silhouette
  local blob = job.rom.data:sub(rec.start + 1, rec.start + rec.size)
  local decoded, err = ModelRom.decompress(blob)
  if not decoded then
    status.state, status.error, job = "failed", tostring(err), nil
    return false
  end
  local ok, rgba = pcall(rgba5551, decoded)
  if ok then ok, err = Storage.writeBytes(("trainers/portraits/%02d"):format(index), rgba) end
  if not ok then
    status.state, status.error, job = "failed", tostring(err or rgba), nil
    return false
  end
  status.done = index
  job.index = index + 1
  status.current = "TRAINER " .. tostring(job.index)
  if index < COUNT then return true end
  local wrote, _, writeErr = Storage.write("trainers/cache", {
    format = FORMAT, count = COUNT,
  })
  if not wrote then
    status.state, status.error, job = "failed", tostring(writeErr), nil
    return false
  end
  readyCache, status.state, status.current, job = true, "done", nil, nil
  return false
end

function Portraits.cancel()
  job = nil
  if status.state == "building" then status.state = "idle" end
end

function Portraits.status() return status end
function Portraits.indexFor(oppClass) return CLASS[oppClass] end

local function makeImage(index, black)
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then return nil end
  local rgba = Storage.bytes(("trainers/portraits/%02d"):format(index))
  if type(rgba) ~= "string" then return nil end
  if black then
    local out = {}
    for i = 1, #rgba, 4 do out[#out + 1] = "\0\0\0" .. rgba:sub(i + 3, i + 3) end
    rgba = table.concat(out)
  end
  local ok, image = pcall(function()
    local data = love.image.newImageData(64, 64, "rgba8", rgba)
    local result = love.graphics.newImage(data)
    if result.setFilter then result:setFilter("nearest", "nearest") end
    return result
  end)
  return ok and image or nil
end

function Portraits.image(index, black)
  if not Portraits.ready() then return nil end
  local cache = black and silhouettes or images
  if cache[index] == nil then cache[index] = makeImage(index, black) or false end
  return cache[index] or nil
end

-- Replace only the opening pictures. Once each trainer has slid away for the
-- first send-out, restore the engine art so victory/blackout scenes keep their
-- normal semantics.
function Portraits.apply(battle)
  if not (battle and battle.kind == "trainer") then return nil end
  local index = CLASS[battle.oppClass]
  if not index then return nil end
  local token = { battle = battle, foe = battle.trainerPic,
    foeIndex = index, foeOpening = battle.showEnemyTrainer and true or false }
  -- The 3D arena is already visible during the opening slide. A pure-black
  -- silhouette reads as a missing/failed portrait against that scene, then
  -- pops into colour when the slide lands. Keep the Stadium portrait coloured
  -- for the complete travel so it remains identifiable and frame-stable.
  local replacement = Portraits.image(index, false)
  if replacement then battle.trainerPic = replacement; token.foeApplied = true end
  token.coloured = replacement and true or false
  return token
end

function Portraits.update(token)
  local battle = token and token.battle
  if not battle or not token.foeApplied then return end
  if not battle.showEnemyTrainer then
    battle.trainerPic = token.foe
    token.foeApplied = false
  elseif (battle.introSlide or 0) <= 0 and not token.coloured then
    local image = Portraits.image(token.foeIndex, false)
    if image then battle.trainerPic = image; token.coloured = true end
  end
end

function Portraits.restore(token)
  if token and token.battle and token.foeApplied then token.battle.trainerPic = token.foe end
end

-- BattleState intentionally silhouettes ordinary Gen-1 trainer art while it
-- slides in. Stadium portraits are already full-colour presentation assets;
-- applying the engine's black-image conversion makes them look unloaded until
-- the exact frame the slide lands. BattleHost uses this narrow predicate to
-- bypass that conversion only for the currently installed replacement.
function Portraits.owns(battle, image)
  local token = battle and battle.stadiumTrainerPortraitToken
  return token and token.foeApplied and battle.trainerPic == image and true or false
end

function Portraits.invalidate()
  readyCache, images, silhouettes, job = nil, {}, {}, nil
  status.state, status.done, status.current, status.error = "idle", 0, nil, nil
end

Portraits.CLASS = CLASS
Portraits.FORMAT = FORMAT
Portraits.COUNT = COUNT
Portraits._rgba5551 = rgba5551

return Portraits

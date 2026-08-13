local loader = love and love.filesystem and love.filesystem.load or loadfile
local romPath = os.getenv("STADIUM_ROM")
if not romPath or romPath == "" then
  print("skip Stadium trainer portrait extraction (STADIUM_ROM not set)")
  return
end

local file = assert(io.open(romPath, "rb"))
local romBytes = file:read("*a")
file:close()

local records = {}
local Storage = {
  bundledRom = function() return "baseroms/baserom.z64", romBytes end,
  read = function(key) return records[key] end,
  write = function(key, value) records[key] = value; return true end,
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
local ModelRom = assert(loader("lib/StadiumModelRom.lua"))({})
local Portraits = assert(loader("lib/StadiumTrainerPortraits.lua"))({
  require = function(name)
    if name == "ModStorage" then return Storage end
    if name == "StadiumModelRom" then return ModelRom end
    error("unexpected dependency " .. tostring(name))
  end,
})

assert(Portraits.indexFor("OPP_BROCK") == 2)
assert(Portraits.indexFor("OPP_RIVAL3") == 14)
assert(Portraits.indexFor("OPP_BUG_CATCHER") == 15)
assert(Portraits.indexFor("OPP_COOLTRAINER_F") == 24)
assert(Portraits.indexFor("OPP_ROCKET") == 43)
assert(Portraits.begin())
local guard = 0
while Portraits.status().state == "building" do
  Portraits.step()
  guard = guard + 1
  assert(guard <= Portraits.COUNT)
end
assert(Portraits.ready(), Portraits.status().error)
assert(#assert(Storage.bytes("trainers/portraits/02")) == 64 * 64 * 4)
local brock = assert(Portraits.image(2, false), "decoded portrait did not become a LOVE image")
assert(brock:getWidth() == 64 and brock:getHeight() == 64)

local original, stadium = {}, {}
function Portraits.image(index, black)
  stadium.index, stadium.black = index, black
  return stadium
end
local battle = { kind = "trainer", oppClass = "OPP_BROCK",
  trainerPic = original, showEnemyTrainer = true, introSlide = 20 }
local token = assert(Portraits.apply(battle))
assert(battle.trainerPic == stadium and stadium.index == 2 and stadium.black == false)
battle.stadiumTrainerPortraitToken = token
assert(Portraits.owns(battle, stadium),
  "active Stadium portrait was not identified for palette bypass")
battle.introSlide = 0
Portraits.update(token)
assert(battle.trainerPic == stadium and stadium.black == false)
battle.showEnemyTrainer = false
Portraits.update(token)
assert(battle.trainerPic == original, "opening portrait leaked into victory scene")
assert(not Portraits.owns(battle, stadium),
  "retired Stadium portrait still claimed palette ownership")

print("ok ROM-backed Stadium trainer portraits")

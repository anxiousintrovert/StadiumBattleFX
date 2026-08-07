package.path = "./?.lua;./?/init.lua;" .. package.path

local StadiumRom = dofile("lib/StadiumRom.lua")

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
  end
end

local z64 = string.char(
  0x80, 0x37, 0x12, 0x40,
  0x01, 0x02, 0x03, 0x04,
  0x10, 0x20, 0x30, 0x40
)
local v64 = string.char(
  0x37, 0x80, 0x40, 0x12,
  0x02, 0x01, 0x04, 0x03,
  0x20, 0x10, 0x40, 0x30
)
local n64 = string.char(
  0x40, 0x12, 0x37, 0x80,
  0x04, 0x03, 0x02, 0x01,
  0x40, 0x30, 0x20, 0x10
)

for _, case in ipairs({
  { z64, "z64" }, { v64, "v64" }, { n64, "n64" },
}) do
  local normalized, order = StadiumRom.normalize(case[1])
  eq(order, case[2], case[2] .. " order")
  eq(normalized, z64, case[2] .. " normalization")
end

local reader = assert(StadiumRom.reader(z64))
eq(reader:u32be(0), 0x80371240, "u32be")
eq(reader:u16be(4), 0x0102, "u16be")
local value, err = reader:u32be(#z64 - 3)
eq(value, nil, "out-of-bounds value")
eq(err.code, "out_of_bounds", "out-of-bounds code")

print("stadium_rom_test: ok")

local loader = love and love.filesystem and love.filesystem.load or loadfile

local spec = {
  id = 59, key = "BLIZZARD", kind = "generic", duration = 60,
  impactAt = 30, assets = {},
}
local positions = {
  attachment = { 795, 720 }, -- leaked framebuffer coordinates
  center = { 111, 47 },      -- live model centre in the animation layer
}
local genericDraws = 0
local modules = {
  ["effects/MoveSpecs"] = { get = function() return spec end },
  StadiumAssets = { has = function() return true end, get = function() end },
  ["effects/ThunderShockSpec"] = {},
  DramaticShapeState = { read = function()
    return { projectedAnchors = { player = { 26, 96 }, enemy = { 124, 56 } } }
  end },
  DramaticShapeAttachment = {
    position = function(_, _, tag)
      local p = tag == 0xFF and positions.center or positions.attachment
      return p[1], p[2]
    end,
  },
  DramaticShapeHit = { effectiveness = function() end, request = function() end },
  ["effects/GenericMoveRenderer"] = { draw = function(active)
    local x, y = active:anchor("target")
    assert(x == 111 and y == 47, "off-layer attachment did not use live centre")
    genericDraws = genericDraws + 1
  end },
  ["effects/StadiumAuthenticRenderer"] = { draw = function() return false end },
  ["effects/StadiumScreenFx"] = { activate = function() end, clear = function() end },
  AttackCinematics = { stop = function() end, start = function() end, setTick = function() end },
}

local calls = {}
local hostLove = love
love = { graphics = {
  push = function(value) calls[#calls + 1] = "push:" .. tostring(value) end,
  pop = function() calls[#calls + 1] = "pop" end,
  origin = function() calls[#calls + 1] = "origin" end,
  setShader = function() calls[#calls + 1] = "shader" end,
  setScissor = function() calls[#calls + 1] = "scissor" end,
  setBlendMode = function() calls[#calls + 1] = "blend" end,
} }

local Player = assert(loader("lib/effects/StadiumFxPlayer.lua"))({
  require = function(name) return assert(modules[name], name) end,
})
local player = Player.new({}, function() return true end)
player.spec, player.custom, player.assetsReady = spec, true, false
player.attackerIsPlayer = true
player:draw()

assert(genericDraws == 1, "particle program was not drawn")
assert(table.concat(calls, ",") ==
  "push:all,origin,shader,scissor,blend,pop",
  "particle pass did not isolate or restore its graphics state")

love = hostLove
print("ok particle layer anchor and graphics isolation")

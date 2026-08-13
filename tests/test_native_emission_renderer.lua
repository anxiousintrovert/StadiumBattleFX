local loader = love and love.filesystem and love.filesystem.load or loadfile
local draws = 0
love = { graphics = {
  setColor = function() end,
  draw = function() draws = draws + 1 end,
  setLineWidth = function() end,
  line = function() end,
  circle = function() end,
  polygon = function() end,
  rectangle = function() end,
  arc = function() end,
  ellipse = function() end,
} }

local Renderer = assert(loader("lib/effects/GenericMoveRenderer.lua"))({
  require = function(name)
    assert(name == "effects/StadiumScreenFx")
    return { drawMove = function() return false end }
  end,
})
local image = {}
local asset = {
  image = image, quads = { {}, {}, {}, {} }, frames = 4,
  frameWidth = 32, frameHeight = 32,
}
local Assets = { get = function(name)
  if name == "beam_core" then return asset end
end }
local player = {
  tick = 12,
  spec = {
    id = 55, type = "WATER", delivery = "none", duration = 60,
    impactAt = 30, primaryAsset = "beam_core",
  },
  anchor = function(_, which)
    return which == "attacker" and 20 or 120, which == "attacker" and 90 or 50
  end,
  nativeEmissions = function()
    return {{
      channel = "primary", born = 10, age = 2, repeatIndex = 0,
      event = { batchSize = 3, renderPreset = 7, particlePreset = 4 },
    }}
  end,
}

Renderer.draw(player, Assets)
assert(draws == 3, "native scheduler batch did not control fallback births")
print("ok native scheduler-driven fallback renderer")

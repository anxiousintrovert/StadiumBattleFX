local loader = loadfile or (love and love.filesystem and love.filesystem.load)
local savedLove = love
local meshes, images = {}, {}

love = {
  image = {
    newImageData = function()
      return { setPixel = function() end }
    end,
  },
  graphics = {
    newImage = function()
      local image = { setFilter = function() end }
      images[#images + 1] = image
      return image
    end,
  },
}

local draws = {}
local Render = {
  FORMAT = {},
  newMesh = function(_, vertices)
    assert(type(vertices) == "table" and #vertices >= 3)
    local mesh = { vertices = vertices }
    meshes[#meshes + 1] = mesh
    return mesh
  end,
  draw = function(mesh, texture, matrix)
    assert(mesh and texture and matrix)
    draws[#draws + 1] = { mesh = mesh, texture = texture }
  end,
}

local Themes = assert(loader("lib/StadiumArenaThemes.lua"))({
  require = function(name)
    if name == "StadiumRender" then return Render end
    if name == "Mat4" then return { identity = function() return { 1 } end } end
    error(name)
  end,
})

local function context(mapId, tileset, surfing, dataOnly)
  local map = not dataOnly and { id = mapId, def = { tileset = tileset } } or nil
  return {
    encounter = { mapId = mapId },
    game = {
      overworld = { map = map, player = { surfing = surfing } },
      data = { maps = { [mapId] = { tileset = tileset } } },
      save = { player = { surfing = surfing } },
    },
  }
end

assert(Themes.classify(context("ROUTE_1", "OVERWORLD", false)) == Themes.GRASS)
assert(Themes.classify(context("ROCK_TUNNEL_1F", "CAVERN", false)) == Themes.CAVE)
assert(Themes.classify(context("SS_ANNE_1F", "SHIP", false)) == Themes.INTERIOR)
assert(Themes.classify(context("ROUTE_20", "OVERWORLD", true)) == Themes.WATER)
assert(Themes.classify(context("POWER_PLANT", "FACILITY", false, true))
  == Themes.INTERIOR, "data-map tileset fallback was not classified")
assert(Themes.classify({ encounter = { mapId = "UNKNOWN" } }) == Themes.GRASS)

for _, theme in ipairs({ Themes.GRASS, Themes.CAVE, Themes.WATER, Themes.INTERIOR }) do
  local before = #draws
  Themes.draw(theme)
  assert(#draws >= before + 4, theme .. " theme did not draw a layered environment")
  local sky = Themes.sky(theme)
  assert(#sky == 4 and sky[4] == 1, theme .. " theme has no opaque sky clear")
end
assert(#meshes >= 16 and #images >= 16,
  "four themes did not build their expected mesh/material groups")

local built = #meshes
Themes.draw(Themes.GRASS)
assert(#meshes == built, "theme mesh cache rebuilt on a repeated draw")
Themes.invalidate()
Themes.draw(Themes.GRASS)
assert(#meshes > built, "theme invalidation did not rebuild meshes")

love = savedLove
print("ok reusable Stadium arena themes")

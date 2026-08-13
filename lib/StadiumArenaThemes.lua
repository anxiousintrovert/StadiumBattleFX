-- Lightweight portable battle environments for installs without a voxel map.
-- Every theme is authored from ordinary textured meshes so StadiumBattleFX can
-- render it with its standalone depth-buffered renderer and no Dramaless code.

local V = ...
local Render = V.require("StadiumRender")
local Mat4 = V.require("Mat4")

local Themes = {}

Themes.GRASS = "grass"
Themes.CAVE = "cave"
Themes.WATER = "water"
Themes.INTERIOR = "interior"

local CAVE_TILESETS = { CAVERN = true, CEMETERY = true }
local OUTDOOR_TILESETS = { OVERWORLD = true, FOREST = true, PLATEAU = true }

local cache = {}

local DEFINITIONS = {
  grass = {
    sky = { .39, .62, .78, 1 },
    floor = { .24, .43, .19, 1 },
    distance = { .13, .29, .13, 1 },
    accent = { .28, .52, .23, 1 },
    detail = { .25, .16, .08, 1 },
  },
  cave = {
    sky = { .055, .047, .07, 1 },
    floor = { .24, .19, .20, 1 },
    distance = { .12, .10, .14, 1 },
    accent = { .39, .31, .27, 1 },
    detail = { .52, .40, .28, 1 },
  },
  water = {
    sky = { .35, .62, .80, 1 },
    floor = { .08, .34, .55, 1 },
    distance = { .08, .25, .34, 1 },
    accent = { .68, .62, .43, 1 },
    detail = { .86, .82, .65, 1 },
  },
  interior = {
    sky = { .10, .12, .18, 1 },
    floor = { .30, .32, .37, 1 },
    distance = { .17, .19, .25, 1 },
    accent = { .48, .16, .15, 1 },
    detail = { .72, .69, .58, 1 },
  },
}

local function mapContext(ctx)
  local game = ctx and ctx.game
  local overworld = game and game.overworld
  local map = overworld and overworld.map
  local mapId = (ctx and ctx.encounter and ctx.encounter.mapId)
    or (map and map.id)
  local def = map and map.def
  if not def and game and game.data and game.data.maps and mapId then
    def = game.data.maps[mapId]
  end
  local surfing = overworld and overworld.player and overworld.player.surfing
  if surfing == nil then
    surfing = game and game.save and game.save.player
      and game.save.player.surfing
  end
  return tostring(mapId or ""), def and def.tileset, surfing and true or false
end

function Themes.classify(ctx)
  local mapId, tileset, surfing = mapContext(ctx)
  if surfing then return Themes.WATER end
  if CAVE_TILESETS[tileset]
      or mapId:find("MT_MOON", 1, true)
      or mapId:find("ROCK_TUNNEL", 1, true)
      or mapId:find("DIGLETTS_CAVE", 1, true)
      or mapId:find("VICTORY_ROAD", 1, true)
      or mapId:find("SEAFOAM_ISLANDS", 1, true) then
    return Themes.CAVE
  end
  if OUTDOOR_TILESETS[tileset] then return Themes.GRASS end
  if tileset then return Themes.INTERIOR end
  return Themes.GRASS
end

local function vertex(x, y, z, u, v, shade)
  return { x, y, z, u or 0, v or 0, shade or 1 }
end

local function triangle(out, a, b, c)
  out[#out + 1], out[#out + 2], out[#out + 3] = a, b, c
end

local function quad(out, a, b, c, d, shade)
  triangle(out, vertex(a[1], a[2], a[3], 0, 0, shade),
    vertex(b[1], b[2], b[3], 1, 0, shade),
    vertex(c[1], c[2], c[3], 1, 1, shade))
  triangle(out, vertex(a[1], a[2], a[3], 0, 0, shade),
    vertex(c[1], c[2], c[3], 1, 1, shade),
    vertex(d[1], d[2], d[3], 0, 1, shade))
end

local function box(out, x0, y0, z0, x1, y1, z1, shade)
  quad(out, {x0,y0,z0}, {x1,y0,z0}, {x1,y1,z0}, {x0,y1,z0}, shade)
  quad(out, {x1,y0,z1}, {x0,y0,z1}, {x0,y1,z1}, {x1,y1,z1}, shade)
  quad(out, {x0,y0,z1}, {x0,y0,z0}, {x0,y1,z0}, {x0,y1,z1}, shade)
  quad(out, {x1,y0,z0}, {x1,y0,z1}, {x1,y1,z1}, {x1,y1,z0}, shade)
  quad(out, {x0,y1,z0}, {x1,y1,z0}, {x1,y1,z1}, {x0,y1,z1}, shade)
end

local function disc(out, radius, y, segments, shade)
  for i = 0, segments - 1 do
    local a, b = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
    triangle(out, vertex(0, y, 0, .5, .5, shade),
      vertex(math.cos(a) * radius, y, math.sin(a) * radius,
        .5 + math.cos(a) * .5, .5 + math.sin(a) * .5, shade),
      vertex(math.cos(b) * radius, y, math.sin(b) * radius,
        .5 + math.cos(b) * .5, .5 + math.sin(b) * .5, shade))
  end
end

local function makeTexture(color)
  local data = love.image.newImageData(1, 1)
  data:setPixel(0, 0, color[1], color[2], color[3], color[4] or 1)
  local texture = love.graphics.newImage(data)
  if texture.setFilter then texture:setFilter("nearest", "nearest") end
  return texture
end

local function addGroup(groups, vertices, color)
  if #vertices == 0 then return end
  local mesh = Render.newMesh(Render.FORMAT, vertices, "triangles", "static")
  groups[#groups + 1] = { mesh = mesh, texture = makeTexture(color) }
end

local function baseScene(def)
  local groups = {}
  local sky, floor = {}, {}
  quad(floor, {-190,0,-155}, {190,0,-155}, {190,0,270}, {-190,0,270}, 1)
  quad(sky, {-190,0,-155}, {190,0,-155}, {190,125,-155}, {-190,125,-155}, 1)
  quad(sky, {-190,0,270}, {-190,0,-155}, {-190,125,-155}, {-190,125,270}, .88)
  quad(sky, {190,0,-155}, {190,0,270}, {190,125,270}, {190,125,-155}, .88)
  addGroup(groups, floor, def.floor)
  addGroup(groups, sky, def.sky)
  return groups
end

local function grassScene(def)
  local groups = baseScene(def)
  local ridge, trees, trunks = {}, {}, {}
  local heights = {22,30,25,39,27,34,23,42,26,35,22,31}
  local left, step = -190, 380 / #heights
  for i, h in ipairs(heights) do
    local x0, x1 = left + (i - 1) * step, left + i * step
    quad(ridge, {x0,0,-153}, {x1,0,-153}, {x1,h,-153}, {x0,h*.72,-153}, .92)
  end
  for i = 0, 8 do
    local x, h = -160 + i * 40, 24 + (i % 3) * 8
    box(trunks, x-2, 0, -147, x+2, h*.58, -143, .85)
    triangle(trees, vertex(x, h+16, -142, .5, 0, 1),
      vertex(x-14, h*.35, -142, 0, 1, .88),
      vertex(x+14, h*.35, -142, 1, 1, .88))
  end
  addGroup(groups, ridge, def.distance)
  addGroup(groups, trunks, def.detail)
  addGroup(groups, trees, def.accent)
  return groups
end

local function caveScene(def)
  local groups = baseScene(def)
  local wall, formations = {}, {}
  local heights = {64,78,69,91,72,84,66,96,74,88,70,82,65}
  local left, step = -190, 380 / #heights
  for i, h in ipairs(heights) do
    local x0, x1 = left + (i - 1) * step, left + i * step
    quad(wall, {x0,0,-153}, {x1,0,-153}, {x1,h,-153}, {x0,h-8,-153}, .85)
  end
  for i = 0, 7 do
    local x, h = -155 + i * 44, 12 + (i % 4) * 5
    triangle(formations, vertex(x, h, -140, .5, 0, 1),
      vertex(x-10, 0, -140, 0, 1, .75),
      vertex(x+11, 0, -140, 1, 1, .75))
  end
  addGroup(groups, wall, def.distance)
  addGroup(groups, formations, def.accent)
  return groups
end

local function waterScene(def)
  local groups = baseScene(def)
  local platform, rim, islands = {}, {}, {}
  disc(platform, 76, .05, 32, 1)
  for i = 0, 31 do
    local a, b = i * math.pi * 2 / 32, (i + 1) * math.pi * 2 / 32
    quad(rim,
      {math.cos(a)*76,.08,math.sin(a)*76}, {math.cos(b)*76,.08,math.sin(b)*76},
      {math.cos(b)*82,-1.3,math.sin(b)*82}, {math.cos(a)*82,-1.3,math.sin(a)*82}, .82)
  end
  local lumps = { {-135,17,42}, {-70,9,29}, {85,12,38}, {145,20,48} }
  for _, p in ipairs(lumps) do
    triangle(islands, vertex(p[1], p[2], -151, .5, 0, 1),
      vertex(p[1]-p[3], 0, -151, 0, 1, .78),
      vertex(p[1]+p[3], 0, -151, 1, 1, .78))
  end
  addGroup(groups, islands, def.distance)
  addGroup(groups, rim, def.accent)
  addGroup(groups, platform, def.detail)
  return groups
end

local function interiorScene(def)
  local groups = baseScene(def)
  local panels, trim, pillars = {}, {}, {}
  for i = 0, 7 do
    local x0, x1 = -184 + i * 46, -184 + i * 46 + 40
    quad(panels, {x0,7,-153}, {x1,7,-153}, {x1,73,-153}, {x0,73,-153},
      i % 2 == 0 and .92 or .78)
  end
  box(trim, -190, 4, -151, 190, 8, -146, 1)
  box(trim, -190, 72, -151, 190, 77, -146, .9)
  for _, x in ipairs({-186,-92,0,92,186}) do
    box(pillars, x-4, 0, -145, x+4, 88, -137, .9)
  end
  addGroup(groups, panels, def.distance)
  addGroup(groups, trim, def.detail)
  addGroup(groups, pillars, def.accent)
  return groups
end

local BUILDERS = {
  grass = grassScene, cave = caveScene, water = waterScene, interior = interiorScene,
}

local function scene(theme)
  theme = DEFINITIONS[theme] and theme or Themes.GRASS
  if not cache[theme] then cache[theme] = BUILDERS[theme](DEFINITIONS[theme]) end
  return cache[theme]
end

function Themes.draw(theme)
  for _, group in ipairs(scene(theme)) do
    Render.draw(group.mesh, group.texture, Mat4.identity())
  end
end

function Themes.sky(theme)
  local def = DEFINITIONS[theme] or DEFINITIONS.grass
  return { def.sky[1], def.sky[2], def.sky[3], def.sky[4] }
end

function Themes.invalidate()
  cache = {}
end

Themes.DEFINITIONS = DEFINITIONS

return Themes

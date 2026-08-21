-- Pokemon Stadium's native Gym Leader Castle stage renderer. Venue geometry,
-- UVs, materials and textures are converted from stadium_models by
-- StadiumArenaAssets; this module places that scene in StadiumBattleFX space.

local namespace = ...
local mod = namespace.mod
local ArenaAssets = namespace.require and namespace.require("StadiumArenaAssets")
local BattleProviders = namespace.require("BattleProviders")
local StadiumRender = namespace.require("StadiumRender")
local ArenaThemes = namespace.require("StadiumArenaThemes")
local Mat4 = namespace.require("Mat4")

local StadiumArena = {
  id = "STADIUM_BATTLE_FX:native-boss-arenas",
  portable = true,
  replacesMap = true,
  discs = false,
}

local GYM = {
  OPP_BROCK = "brock", OPP_MISTY = "misty", OPP_LT_SURGE = "surge",
  OPP_ERIKA = "erika", OPP_KOGA = "koga", OPP_SABRINA = "sabrina",
  OPP_BLAINE = "blaine",
}

local ELITE4 = {
  OPP_LORELEI = true, OPP_BRUNO = true,
  OPP_AGATHA = true, OPP_LANCE = true,
}

-- Stadium applies a 0.5 root scale. This factor carries that native scene
-- into Dramaless world pixels while preserving its original proportions.
-- The first native passes left the camera almost on Brock's octagonal wall:
-- its near corner could cross the viewpoint and turn into a foreground cliff.
-- Enlarging the conversion puts that complete perimeter outside the
-- wide rig's full orbit while making the battle floor fill the shot.
-- 0.100 is the minimum supported room scale: below it Brock's near wall
-- crosses the raised camera viewpoint.
local NATIVE_SCALE = .100
local NATIVE_YAW = math.pi / 2
local CAMERA_RIG_NAME = "stadiumBattleFxBoss"
local CAMERA_RIG = {
  -- Preserve the tele rig's long Stadium-like view direction, but raise the
  -- eye and open the frame enough to read the complete court from above.
  side = 78.79, back = 217.44, height = 82,
  lookX = -.26, lookY = .34, frameH = 34.11,
}
local CAMERA_BOUNDS = {
  -- Fractions of Dramaless' normal wide-camera orbit/elevation ranges. At
  -- this scale the eye remains well inside the native perimeter and these
  -- stops keep every corner of the view on the broad outer floor.
  orbit = .55,
  pitch = .45,
  zoomMin = 1.0,
  zoomMax = 1.6,
}

local function opponentId(battle)
  return battle and (battle.oppClass or (battle.trainer and battle.trainer.id)) or nil
end

function StadiumArena.venueFor(battle)
  local id = opponentId(battle)
  if id == "OPP_RIVAL3" then return "champion" end
  if ELITE4[id] then return "elite4" end
  if id == "OPP_GIOVANNI" and (battle.partyIndex or 1) == 3 then return "giovanni" end
  return GYM[id]
end

local function fallback()
  return BattleProviders.FALLBACK
end

function StadiumArena:available(ctx)
  return StadiumRender.available()
end

-- The built-in arena choice is intentionally an AUTO policy. Ordinary
-- battles prefer PotatoVoxel's performance-scaled map-backed stage when that
-- exact provider is registered and ready; Gyms, the Elite Four, and the
-- Champion retain their authored Stadium rooms. If the voxel provider later
-- declines, BattleHost returns here and uses a theme.
function StadiumArena:preferredExternal(ctx)
  if not StadiumArena.venueFor(ctx and ctx.battle) then
    return "potato_voxel:voxel-map"
  end
end

local function logVenue(venue, battle, member)
  local logger = namespace.log or mod.log
  local id = opponentId(battle) or "unknown"
  if logger and type(logger.info) == "function" then
    pcall(logger.info, logger,
      "native battle arena selected: venue=%s stadium_model=%s opponent=%s party=%s",
      venue, tostring(member), id, tostring(battle and battle.partyIndex or 1))
  elseif type(logger) == "function" then
    pcall(logger, string.format(
      "native battle arena selected: venue=%s stadium_model=%s opponent=%s party=%s",
      venue, tostring(member), id, tostring(battle and battle.partyIndex or 1)))
  end
end

function StadiumArena:arena(ctx)
  local battle = ctx and ctx.battle
  local venue = StadiumArena.venueFor(battle)
  if venue and not (ArenaAssets and ArenaAssets.ready and ArenaAssets.ready()) then
    venue = nil
  end
  local theme = not venue and ArenaThemes.classify(ctx) or nil
  local arena = {
    id = StadiumArena.id .. ":" .. (venue or ("theme-" .. theme)),
    portable = true,
    replacesMap = true,
    discs = false,
    stadiumVenue = venue,
    stadiumTheme = theme,
    enemy = { 0, -24 },
    player = { 0, 24 },
    mid = { 0, 0 },
    cam = CAMERA_RIG_NAME,
    camera = CAMERA_RIG,
    cameraBounds = CAMERA_BOUNDS,
  }
  if venue then logVenue(venue, battle, ArenaAssets.VENUE_MEMBER[venue]) end
  return arena
end

local neutralMesh, neutralTexture
local function neutralCourt()
  if neutralMesh and neutralTexture then return neutralMesh, neutralTexture end
  local vertices = {
    { -110, 0, -82, 0, 0, .72 }, { 110, 0, -82, 1, 0, .72 },
    { 110, 0, 82, 1, 1, .72 }, { -110, 0, -82, 0, 0, .72 },
    { 110, 0, 82, 1, 1, .72 }, { -110, 0, 82, 0, 1, .72 },
  }
  local okMesh, mesh = pcall(StadiumRender.newMesh,
    StadiumRender.FORMAT, vertices, "triangles", "static")
  if not okMesh or not mesh then return nil end
  local okTexture, texture = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, .28, .31, .38, 1)
    return love.graphics.newImage(data)
  end)
  if not okTexture then return nil end
  neutralMesh, neutralTexture = mesh, texture
  return neutralMesh, neutralTexture
end

local function matrixFor(arena, groundY)
  local mid = arena and arena.mid
  if not mid then return nil end
  return Mat4.mul(Mat4.mul(
      Mat4.translate(mid[1], groundY or 0, mid[2]), Mat4.rotateY(NATIVE_YAW)),
    Mat4.scale(NATIVE_SCALE, NATIVE_SCALE, NATIVE_SCALE))
end

local function render(stage, Voxel3D, matrix, shadowMap)
  for _, group in ipairs(stage.groups) do
    -- Native centre emblems do not survive this camera consistently.
    -- ArenaAssets supplies the contained circular Poké Ball court for every
    -- boss venue. Its coplanar decorative layers do not enter the shadow map.
    if not group.floorMark and (not shadowMap or not group.noShadow) then
      if shadowMap then
        shadowMap.draw(group.mesh, group.texture, matrix)
      else
        local tint = group.tint
        if love.graphics and love.graphics.setColor then
          love.graphics.setColor(tint[1], tint[2], tint[3], tint[4])
        end
        Voxel3D.draw(group.mesh, group.texture, matrix)
      end
    end
  end
  if not shadowMap and love.graphics and love.graphics.setColor then
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function StadiumArena:draw(ctx, arena, groundY)
  local venue = arena and arena.stadiumVenue
  if not venue then
    local ok = pcall(ArenaThemes.draw,
      arena and arena.stadiumTheme or ArenaThemes.GRASS)
    if not ok then
      local mesh, texture = neutralCourt()
      if mesh then StadiumRender.draw(mesh, texture, Mat4.identity()) end
    end
    return
  end
  local stage = ArenaAssets.get(venue, StadiumRender)
  local matrix = matrixFor(arena, groundY)
  if not (stage and matrix) then return end
  StadiumRender.seams(false)
  StadiumRender.glass(false)
  -- Stadium submits every stage root here.  The broad outer floor, its
  -- foundation and the tall perimeter wall are the arena, not an exterior
  -- shell: omitting them leaves only the small inset logo platform and a few
  -- suspended ornaments against the clear colour.
  render(stage, StadiumRender, matrix, nil)
  StadiumRender.glass(true)
  StadiumRender.seams(true)
end

StadiumArena.drawWorld = StadiumArena.draw

function StadiumArena:cast(ctx, shadowMap, arena, groundY)
  local venue = arena and arena.stadiumVenue
  if not (venue and shadowMap and shadowMap.draw) then return end
  local stage = ArenaAssets.get(venue, StadiumRender)
  local matrix = matrixFor(arena, groundY)
  if stage and matrix then render(stage, StadiumRender, matrix, shadowMap) end
end

function StadiumArena:sky(ctx, inherited)
  if not StadiumArena.venueFor(ctx and ctx.battle) then
    return ArenaThemes.sky(ArenaThemes.classify(ctx))
  end
  -- Native Gym Leader Castle members return RGBA16 value 1 for their clear:
  -- opaque black. This is the dark chamber around the lit stage in Stadium.
  return { 0, 0, 0, 1 }
end

function StadiumArena:invalidate()
  if ArenaAssets and ArenaAssets.invalidate then ArenaAssets.invalidate() end
  if ArenaThemes and ArenaThemes.invalidate then ArenaThemes.invalidate() end
  neutralMesh, neutralTexture = nil, nil
end

StadiumArena.NATIVE_SCALE = NATIVE_SCALE
StadiumArena.NATIVE_YAW = NATIVE_YAW
StadiumArena.CAMERA_RIG_NAME = CAMERA_RIG_NAME
StadiumArena.CAMERA_RIG = CAMERA_RIG
StadiumArena.CAMERA_BOUNDS = CAMERA_BOUNDS

return StadiumArena

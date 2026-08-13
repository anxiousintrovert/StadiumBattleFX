local loader = loadfile or (love and love.filesystem and love.filesystem.load)

local FALLBACK = {}
local draws = {}
local fakeVoxel = {
  newMesh = function(vertices, indices)
    assert(#vertices > 0 and #indices > 0)
    return { vertices = vertices, indices = indices }
  end,
  seams = function() end,
  glass = function() end,
  draw = function(mesh, texture, matrix)
    assert(mesh and texture and matrix)
    draws[#draws + 1] = { mesh, texture, matrix }
  end,
}
local fakeMat = {
  translate = function(...) return { "translate", ... } end,
  scale = function(...) return { "scale", ... } end,
  rotateY = function(...) return { "rotateY", ... } end,
  mul = function(...) return { "mul", ... } end,
  identity = function() return { "identity" } end,
}
fakeVoxel.FORMAT = {}
fakeVoxel.available = function() return true end

local logged
local Arena = assert(loader("lib/StadiumArena.lua"))({
  require = function(name)
    if name == "BattleProviders" then return { FALLBACK = FALLBACK } end
    if name == "StadiumRender" then return fakeVoxel end
    if name == "Mat4" then return fakeMat end
    if name == "StadiumArenaThemes" then
      return {
        GRASS = "grass",
        classify = function(ctx)
          local mapId = ctx and ctx.encounter and ctx.encounter.mapId or ""
          if mapId:find("CAVE", 1, true) then return "cave" end
          return "grass"
        end,
        draw = function(theme)
          draws[#draws + 1] = { theme = theme }
        end,
        sky = function() return { .4, .6, .8, 1 } end,
        invalidate = function() end,
      }
    end
    assert(name == "StadiumArenaAssets")
    return {
      VENUE_MEMBER = { brock=7, misty=8, surge=9, erika=10, koga=11,
        sabrina=12, blaine=13, giovanni=14, elite4=15, champion=16 },
      ready = function() return true end,
      get = function(_, voxel)
        local function group(seed)
          return {
            mesh = voxel.newMesh({ { seed, 0, 0, 0, 0, 1 },
              { seed + 1, 0, 0, 1, 0, 1 }, { seed, 1, 0, 0, 1, 1 } },
              { 1, 2, 3 }),
            texture = { source = "native-rom-cache" }, tint = { 1, 1, 1, 1 },
          }
        end
        return { groups = { group(0), group(2), group(4), group(6) } }
      end,
      invalidate = function() end,
    }
  end,
  log = { info = function(_, message, ...)
    logged = string.format(message, ...)
  end },
  mod = {},
})

local gymVenues = {
  OPP_BROCK = "brock", OPP_MISTY = "misty", OPP_LT_SURGE = "surge",
  OPP_ERIKA = "erika", OPP_KOGA = "koga", OPP_SABRINA = "sabrina",
  OPP_BLAINE = "blaine",
}
for opponent, venue in pairs(gymVenues) do
  assert(Arena.venueFor({ oppClass = opponent }) == venue,
    opponent .. " did not select " .. venue)
end
assert(Arena.venueFor({ oppClass = "OPP_GIOVANNI", partyIndex = 3 }) == "giovanni")
assert(Arena.venueFor({ oppClass = "OPP_GIOVANNI", partyIndex = 2 }) == nil)
assert(Arena.venueFor({ trainer = { id = "OPP_LORELEI" } }) == "elite4")
assert(Arena.venueFor({ oppClass = "OPP_LANCE" }) == "elite4")
assert(Arena.venueFor({ oppClass = "OPP_RIVAL3" }) == "champion")
assert(Arena.venueFor({ oppClass = "OPP_YOUNGSTER" }) == nil)

local ctx = { battle = { oppClass = "OPP_AGATHA" } }
assert(Arena:available(ctx))
local stage = Arena:arena(ctx)
assert(stage and stage.portable and stage.discs == false)
assert(stage.stadiumVenue == "elite4")
assert(stage.cam == Arena.CAMERA_RIG_NAME)
assert(stage.camera == Arena.CAMERA_RIG)
assert(Arena.CAMERA_RIG.height == 82 and Arena.CAMERA_RIG.frameH == 34.11)
assert(Arena.NATIVE_SCALE == .100, "native Stadium arena scale floor is not 0.100")
assert(stage.cameraBounds == Arena.CAMERA_BOUNDS)
assert(stage.cameraBounds.orbit == .55 and stage.cameraBounds.pitch == .45)
assert(stage.cameraBounds.zoomMin == 1 and stage.cameraBounds.zoomMax == 1.6)
assert(logged and logged:find("venue=elite4", 1, true)
  and logged:find("opponent=OPP_AGATHA", 1, true),
  "arena selection was not logged")

-- Exercise native material-group drawing, not just the selector.
for opponent, venue in pairs(gymVenues) do
  local before = #draws
  local gym = Arena:arena({ battle = { oppClass = opponent } }, {})
  Arena:draw({}, gym, 0)
  assert(gym.stadiumVenue == venue)
  assert(#draws == before + 4,
    venue .. " did not render the complete native room")
end
local viridian = Arena:arena({ battle = {
  oppClass = "OPP_GIOVANNI", partyIndex = 3,
} }, {})
Arena:draw({}, viridian, 0)
assert(viridian.stadiumVenue == "giovanni")
assert(#draws == 32, "expected four native groups for all eight Gym draws; got "
  .. tostring(#draws))

local ordinary = Arena:arena({ battle = { oppClass = "OPP_YOUNGSTER" } }, {})
assert(ordinary and ordinary.stadiumVenue == nil and ordinary.discs == false
  and ordinary.stadiumTheme == "grass",
  "ordinary battles did not receive the standalone grass theme")
assert(Arena:preferredExternal({ battle = { oppClass = "OPP_YOUNGSTER" } })
  == "DRAMALESS_SHAPE:voxel-map")
assert(Arena:preferredExternal({ battle = { oppClass = "OPP_BROCK" } }) == nil)

print("ok Stadium boss arena selection")

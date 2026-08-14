local loader = loadfile or (love and love.filesystem and love.filesystem.load)

local FALLBACK = {}
local surface = { typeOf = function(_, kind) return kind == "Canvas" end }
local fullFieldDraws, textboxDraws, transparentClears = 0, 0, 0
local shakeZoneDraws = 0
local currentColor = { 1, 1, 1, 1 }
local engineHitFlashDraws = 0
local nativePics, lastNativeSide = 0, nil
local previousLove = love
love = love or {}
local graphics = love.graphics
love.graphics = {
  getPixelDimensions = function() return 1920, 1080 end,
  getColor = function() return unpack(currentColor) end,
  setColor = function(r, g, b, a) currentColor = { r, g, b, a == nil and 1 or a } end,
  rectangle = function(_, x, y, w, h)
    if x == 0 and y == 0 and w == 304 and h == 144 then
      if math.abs((currentColor[4] or 1) - .85) < .001 then
        engineHitFlashDraws = engineHitFlashDraws + 1
      else
        fullFieldDraws = fullFieldDraws + 1
      end
    elseif (x == 0 and y == 0 and w == 160 and h == 144)
        or (x == 8 and y == 0 and w == 80 and h == 32)
        or (x == 80 and y == 56 and w == 80 and h == 32)
        or (x == 0 and y == 32 and w == 72 and h == 64)
        or (x == 88 and y == 0 and w == 72 and h == 56)
        or (x == 0 and y == 96 and w == 160 and h == 48) then
      shakeZoneDraws = shakeZoneDraws + 1
    else
      textboxDraws = textboxDraws + 1
    end
  end,
  clear = function(r, g, b, a)
    if r == 0 and g == 0 and b == 0 and a == 0 then
      transparentClears = transparentClears + 1
    end
  end,
  getCanvas = function() return {} end,
}

local BattleState = {}
function BattleState:draw()
  love.graphics.setColor(.8, .7, .6, 1)
  love.graphics.rectangle("fill", 0, 0, 304, 144)
  if self.fx and (self.fx.shakeX ~= 0 or self.fx.shakeY ~= 0) then
    -- Mirrors BattleState:drawZonePass's opaque SGB-zone refills. These are
    -- the block-shaped white artifacts exposed by a transparent 3D battle.
    love.graphics.setColor(1, 1, 1, 1)
    for _, z in ipairs({
      { 0, 0, 160, 144 }, { 8, 0, 80, 32 }, { 80, 56, 80, 32 },
      { 0, 32, 72, 64 }, { 88, 0, 72, 56 }, { 0, 96, 160, 48 },
    }) do
      love.graphics.rectangle("fill", unpack(z))
    end
  end
  self:drawPicsLayer(0, 0, 0)
  love.graphics.rectangle("fill", 0, 104, 304, 40)
  -- A later move flash uses the same full-field bounds and must survive.
  love.graphics.setColor(1, 1, 1, .35)
  love.graphics.rectangle("fill", 0, 0, 304, 144)
  if self.fx and self.fx.flash and self.fx.flash > 0 and self.frame % 4 < 2 then
    love.graphics.setColor(1, 1, 1, .85)
    love.graphics.rectangle("fill", 0, 0, 304, 144)
  end
end
function BattleState:drawPicsLayer(_, _, _, onlySide)
  nativePics = nativePics + 1
  lastNativeSide = onlySide
end
function BattleState:drawBattlerPic() end
package.preload["src.battle.BattleState"] = function() return BattleState end

local arena = { id = "TEST:world", player = { 0, 24 }, enemy = { 0, -24 },
  mid = { 0, 0 } }
local arenaProvider = {
  arena = function() return arena end,
  begin = function() return true end,
  render = function(_, _, _, drawActors)
    drawActors({
      project = function() return 1590, 1440 end,
      width = 3840, height = 2160,
    })
    return surface
  end,
}
local coverage = { player = true, enemy = true }
local modelProvider = {
  begin = function() return true end,
  covers = function(_, _, side) return coverage[side] end,
}
local Providers = {
  VERSION = 1, FALLBACK = FALLBACK, DEFAULT = "stadium:default",
  resolve = function(slot)
    if slot == "arena" then
      return arenaProvider, { id = "DRAMALESS_SHAPE:voxel-map" }
    end
    if slot == "models" then return modelProvider, { id = "TEST:models" } end
  end,
  builtin = function() return nil end,
}
local logicalProjector, screenProjector
local Host = assert(loader("lib/BattleHost.lua"))({
  log = { info = function() end, error = function() end },
  require = function(name)
    if name == "BattleProviders" then return Providers end
    if name == "Mat4" then return {} end
    if name == "StadiumRender" then return {} end
    if name == "BattleCinematicsCompat" then
      return { claim = function() return false end, update = function() end }
    end
    if name == "BattleArtCompat" then
      return { active = function() return false end,
        ownsBattle = function() return false end }
    end
    if name == "StadiumTrainerPortraits" then
      return { apply = function() end, update = function() end,
        restore = function() end }
    end
    if name == "AttackCinematics" then
      return { camera = function(base) return base end }
    end
    if name == "StadiumModels" then
      return {
        setProjector = function(value) logicalProjector = value end,
        setScreenProjector = function(value) screenProjector = value end,
      }
    end
    error(name)
  end,
})

local override
local battle = setmetatable({
  kind = "trainer", player = {}, enemy = {},
  game = { renderer = {
    uiFill = true,
    uiSize = function() return 160, 144 end,
    setWorldOverride = function(_, value) override = value end,
  } },
}, { __index = BattleState })

local engineDraw = BattleState.draw
assert(Host.install())
-- Gen3 Battle UI and similar presentation mods can replace BattleState.draw
-- after Stadium first initializes. Reinstalling at the battle boundary must
-- chain the final method instead of trusting a stale boolean marker.
BattleState.draw = function(self, ...)
  return engineDraw(self, ...)
end
assert(Host.install(true), "battle draw hook did not reattach after replacement")
assert(Host.begin(battle))
local captureOk = Host.session.context.services.withNativeBattlePics(function()
  battle:drawPicsLayer(0, 0, 0, "enemy", true)
end)
assert(captureOk and nativePics == 1 and lastNativeSide == "enemy",
  "native picture capture did not bypass host suppression")
battle:draw()
assert(override == surface, "battle renderer did not receive the 3D world override")
local screenX, screenY = assert(screenProjector)()
assert(math.abs(screenX - 795) < 1e-6 and math.abs(screenY - 720) < 1e-6,
  "supersampled attachment was not resolved to the shown world surface")
local logicalX, logicalY = assert(logicalProjector)()
assert(math.abs(logicalX - 58) < 1e-6 and math.abs(logicalY - 96) < 1e-6,
  ("supersampled attachment was not mapped into the Android move layer: %.3f,%.3f")
    :format(logicalX, logicalY))
assert(nativePics == 1, "native picture layer flashed over covered 3D models")
assert(fullFieldDraws == 1,
  "wide battle field was not suppressed or the later move flash was lost")
assert(engineHitFlashDraws == 0,
  "legacy GB-sized hit flash leaked over the Dramaless world")
assert(textboxDraws == 1, "battle UI layers were suppressed with the background")
assert(transparentClears >= 1, "battle UI canvas was not cleared transparent")
assert(battle.letterboxWhite == false, "white battle letterbox still masks the world")

-- Every custom impact supplies a small shake offset. The engine's colorized
-- path must not use that offset to rebuild the transparent battlefield out of
-- six opaque SGB zone rectangles.
battle.fx, battle.frame = { shakeX = 2, shakeY = -1 }, 1
battle:draw()
assert(shakeZoneDraws == 0,
  "screen shake rebuilt the opaque Game Boy battle framebuffer")
assert(textboxDraws == 2,
  "shake-zone suppression removed normal battle UI rectangles")

-- On a hit frame, the engine's 0.85-alpha white overlay is suppressed while
-- the lower-alpha authored move flash above remains visible.
battle.fx, battle.frame = { flash = 2 }, 0
battle:draw()
assert(fullFieldDraws == 3,
  "authored full-field move flash was suppressed on the hit frame")
assert(engineHitFlashDraws == 0,
  "borderless hit frame emitted a white battle-sized square")

-- The built-in Stadium arena also owns the custom hit presentation. It must
-- not reveal the legacy white rectangle after fixing particle projection.
Host.session.ids.arena = "stadium:default"
battle.animPlayer = { custom = true }
battle:draw()
assert(engineHitFlashDraws == 0,
  "legacy hit flash leaked over the built-in Stadium animation")

coverage.enemy = false
battle:drawPicsLayer(0, 0, 0)
assert(nativePics == 2 and lastNativeSide == "enemy",
  "partially covered picture layer did not preserve the uncovered side")

Host.finish("test")
if previousLove then love.graphics = graphics else love = nil end
print("ok framebuffer world override under transparent battle UI")

local repo = assert(os.getenv("STADIUM_FX_REPO"), "set STADIUM_FX_REPO")
local output = assert(os.getenv("STADIUM_FX_CAPTURE_DIR"),
  "set STADIUM_FX_CAPTURE_DIR")

local all = assert(loadfile(repo .. "/lib/effects/AllMoveSpecs.lua"))()
local Renderer = assert(loadfile(repo .. "/lib/effects/GenericMoveRenderer.lua"))()

local PICKS = {
  { "normal", "HYPER_BEAM" },
  { "fighting", "SUBMISSION" },
  { "flying", "WING_ATTACK" },
  { "poison", "ACID" },
  { "ground", "BONE_CLUB" },
  { "rock", "ROCK_SLIDE" },
  { "bug", "PIN_MISSILE" },
  { "ghost", "NIGHT_SHADE" },
  { "fire", "FIRE_BLAST" },
  { "water", "HYDRO_PUMP" },
  { "grass", "RAZOR_LEAF" },
  { "electric", "THUNDERBOLT" },
  { "psychic", "PSYBEAM" },
  { "ice", "ICE_BEAM" },
  { "dragon", "DRAGON_RAGE" },
}

local byKey = {}
for _, spec in ipairs(all) do byKey[spec.key] = spec end
for _, pick in ipairs(PICKS) do
  pick.spec = assert(byKey[pick[2]], "missing move " .. pick[2])
end
local SCALE, FRAME_COUNT = 3, 36
local moveIndex, frameIndex, pending = 1, 1, false
local font, tiny
local assets = { get = function() return nil end }
local player = { attackerIsPlayer = true }
function player:anchor(which)
  if which == "attacker" then return 26, 96 end
  return 124, 56
end

local function capturePath()
  local pick = PICKS[moveIndex]
  return ("%s/%02d_%s_%s/frame_%03d.png"):format(
    output, moveIndex, pick[1], pick[2]:lower(), frameIndex)
end

local function drawPokemon(x, y, facing, target)
  local g = love.graphics
  g.setColor(0.03, 0.055, 0.09, 0.32)
  g.ellipse("fill", x, y + 2, target and 21 or 25, target and 5 or 7)
  g.setColor(target and 0.18 or 0.12, target and 0.24 or 0.20,
    target and 0.34 or 0.31, 1)
  g.ellipse("fill", x, y - 16, target and 14 or 17, target and 20 or 24)
  g.circle("fill", x + facing * (target and 5 or 7),
    y - (target and 36 or 43), target and 10 or 12)
  g.polygon("fill", x + facing * 2, y - (target and 44 or 52),
    x + facing * 7, y - (target and 56 or 66),
    x + facing * 11, y - (target and 43 or 51))
  g.setColor(0.42, 0.55, 0.72, 0.5)
  g.ellipse("line", x, y - 16, target and 14 or 17, target and 20 or 24)
end

local function drawStage()
  local g = love.graphics
  g.clear(0.025, 0.045, 0.085, 1)
  g.setColor(0.055, 0.11, 0.17, 1)
  g.rectangle("fill", 0, 35, 160, 109)
  g.setColor(0.10, 0.20, 0.25, 1)
  g.polygon("fill", 0, 87, 36, 58, 77, 79, 112, 48, 160, 72, 160, 144, 0, 144)
  g.setColor(0.08, 0.16, 0.19, 1)
  g.ellipse("fill", 81, 113, 91, 32)
  g.setColor(0.20, 0.36, 0.39, 0.5)
  for radius = 18, 74, 14 do g.ellipse("line", 81, 113, radius, radius * 0.35) end
  drawPokemon(27, 118, 1, false)
  drawPokemon(124, 72, -1, true)
end

local function drawHeader(pick)
  local g = love.graphics
  g.setColor(0.015, 0.025, 0.05, 0.94)
  g.rectangle("fill", 0, 0, 160, 35)
  g.setFont(font)
  g.setColor(0.96, 0.98, 1, 1)
  g.print(pick.spec.name:upper(), 7, 5)
  g.setFont(tiny)
  g.setColor(0.58, 0.76, 0.96, 1)
  g.print(pick.spec.type .. "  /  STADIUM ATTACK ANIMATIONS 1.0.1", 7, 21)
end

function love.load()
  font = love.graphics.newFont(10)
  tiny = love.graphics.newFont(6)
  love.graphics.setDefaultFilter("nearest", "nearest")
end

function love.update() end

function love.draw()
  love.graphics.push()
  love.graphics.scale(SCALE, SCALE)
  love.graphics.setLineWidth(1)
  local pick = PICKS[moveIndex]
  drawStage()
  player.spec = pick.spec
  player.tick = math.floor((frameIndex - 1) * (pick.spec.duration - 1)
    / (FRAME_COUNT - 1))
  Renderer.draw(player, assets)
  drawHeader(pick)
  love.graphics.pop()

  if pending then return end
  pending = true
  local path = capturePath()
  love.graphics.captureScreenshot(function(data)
    local encoded = data:encode("png")
    local file = assert(io.open(path, "wb"))
    file:write(encoded:getString())
    file:close()
    frameIndex = frameIndex + 1
    if frameIndex > FRAME_COUNT then
      print(("captured %s / %s"):format(PICKS[moveIndex][1], PICKS[moveIndex][2]))
      frameIndex = 1
      moveIndex = moveIndex + 1
      if moveIndex > #PICKS then
        love.event.quit(0)
        return
      end
    end
    pending = false
  end)
end

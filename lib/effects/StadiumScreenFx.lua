-- Shared screen-space presentation primitives.
--
-- Effects are authored on Gen1's 160x144 animation layer. Dramaless Shape may
-- transform that layer around the projected combatants in every video mode,
-- while Gen1Recomp composites it into a larger desktop surface. Screen-wide
-- primitives always cancel the combatant transform; in borderless mode they
-- are also replayed into the outer margins after composition. Anchored
-- particles keep the normal path.

local ScreenFx = {}

local WIDTH, HEIGHT = 160, 144
local borderless = false
local pending

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

function ScreenFx.envelope(tick, duration, attack, release)
  tick, duration = tonumber(tick) or 0, math.max(1, tonumber(duration) or 1)
  attack, release = math.max(1, attack or 1), math.max(1, release or 1)
  return math.min(clamp(tick / attack, 0, 1),
    clamp((duration - tick) / release, 0, 1))
end

function ScreenFx.setBorderless(value)
  borderless = value and true or false
end

function ScreenFx.activate(owner)
  pending = owner and { owner = owner, operations = {} } or nil
end

function ScreenFx.clear(owner)
  if not owner or (pending and pending.owner == owner) then pending = nil end
end

local function record(owner, operation)
  if not owner then return end
  if not pending or pending.owner ~= owner then ScreenFx.activate(owner) end
  pending.operations[#pending.operations + 1] = operation
end

local function transform(owner)
  local state = owner and owner.dsState
  local value = state and state.layerTransform
  -- The staged battle's animation-layer transform exists on Android and in
  -- windowed desktop mode too.  `borderless` controls only the post-compose
  -- margin pass below; tying this inverse transform to it shrinks a supposed
  -- full-screen field (notably Surf) to the active camera rectangle.
  if not (value and value.scale and value.scale > 0
      and value.authoredCenter and value.projectedCenter) then return nil end
  return value
end

-- Cancel Dramaless Shape's outer combatant-pair transform for a screen layer.
function ScreenFx.push(g, owner)
  local value = transform(owner)
  if not value then return false end
  g.push()
  g.translate(value.authoredCenter[1], value.authoredCenter[2])
  g.scale(1 / value.scale, 1 / value.scale)
  g.translate(-value.projectedCenter[1], -value.projectedCenter[2])
  return true
end

function ScreenFx.pop(g, pushed)
  if pushed then g.pop() end
end

function ScreenFx.region(g, color, alpha, x, y, width, height, owner, raw)
  if not g or (alpha or 0) <= 0 then return false end
  color = color or { 1, 1, 1 }
  record(owner, { kind = "region", color = color, alpha = alpha,
    x = x, y = y, width = width, height = height })
  local pushed = not raw and ScreenFx.push(g, owner)
  g.setColor(color[1], color[2], color[3], alpha)
  g.rectangle("fill", x, y, width, height)
  ScreenFx.pop(g, pushed)
  return true
end

function ScreenFx.fill(g, color, alpha, owner, raw)
  return ScreenFx.region(g, color, alpha, 0, 0, WIDTH, HEIGHT, owner, raw)
end

function ScreenFx.tile(g, value, frame, options)
  if not (g and value) then return false end
  options = options or {}
  local color = options.color or { 1, 1, 1 }
  local scale = options.scale or 1
  local width, height = value.frameWidth * scale, value.frameHeight * scale
  if width <= 0 or height <= 0 then return false end
  local quad = value.quads[math.floor(frame or 0) % value.frames + 1]
  local ox = (options.x or 0) % width - width
  local oy = (options.y or 0) % height - height
  record(options.owner, { kind = "tile", value = value, frame = frame,
    color = color, alpha = options.alpha or 1, x = options.x or 0,
    y = options.y or 0, scale = scale })
  local pushed = not options.raw and ScreenFx.push(g, options.owner)
  g.setColor(color[1], color[2], color[3], options.alpha or 1)
  for py = oy, HEIGHT + height, height do
    for px = ox, WIDTH + width, width do
      g.draw(value.image, quad, px, py, 0, scale, scale)
    end
  end
  ScreenFx.pop(g, pushed)
  return true
end

-- A triangular flash supports one-frame pops and short Stadium-style blooms.
function ScreenFx.flash(g, tick, at, length, color, peak, owner, raw)
  local age = (tonumber(tick) or 0) - (at or 0)
  length = math.max(2, length or 8)
  if age < 0 or age >= length then return false end
  local midpoint = math.max(1, math.floor(length * 0.3))
  local alpha
  if age <= midpoint then
    alpha = age / midpoint
  else
    alpha = 1 - (age - midpoint) / math.max(1, length - midpoint)
  end
  return ScreenFx.fill(g, color or { 1, 1, 1 },
    clamp(alpha, 0, 1) * (peak or 1), owner, raw)
end

local function mist(self, g)
  local fade = ScreenFx.envelope(self.tick, self.spec.duration, 12, 22)
  local pushed = ScreenFx.push(g, self)
  ScreenFx.fill(g, { 0.72, 0.90, 1 }, 0.16 * fade, self, true)
  g.setLineWidth(1.2)
  for i = 0, 8 do
    local y = 18 + i * 15 + math.sin(self.tick * 0.045 + i) * 7
    local x = ((self.tick * (0.22 + i * 0.015) + i * 31) % 210) - 25
    g.setColor(0.84, 0.95, 1, fade * (0.18 + (i % 3) * 0.055))
    g.ellipse("line", x, y, 30 + (i % 4) * 9, 7 + (i % 3) * 2)
  end
  ScreenFx.pop(g, pushed)
end

local function haze(self, g)
  local fade = ScreenFx.envelope(self.tick, self.spec.duration, 10, 24)
  local pushed = ScreenFx.push(g, self)
  ScreenFx.fill(g, { 0.11, 0.16, 0.24 }, 0.30 * fade, self, true)
  for i = 0, 7 do
    local width = 34 + (i % 3) * 15
    local x = ((i * 37 - self.tick * (0.28 + i * 0.025)) % 220) - 30
    local y = 10 + i * 19
    g.setColor(0.58, 0.68, 0.78, fade * (0.08 + (i % 2) * 0.04))
    g.rectangle("fill", x, y, width, 8 + (i % 3) * 3)
  end
  ScreenFx.pop(g, pushed)
end

local function flashMove(self, g)
  local fade = ScreenFx.envelope(self.tick, self.spec.duration, 5, 22)
  local pushed = ScreenFx.push(g, self)
  ScreenFx.fill(g, { 1, 0.98, 0.76 }, 0.18 * fade, self, true)
  ScreenFx.flash(g, self.tick, 6, 14, { 1, 1, 0.92 }, 0.82, self, true)
  ScreenFx.flash(g, self.tick, 24, 10, { 1, 0.98, 0.72 }, 0.48, self, true)
  ScreenFx.pop(g, pushed)
  -- Target rings are anchored VFX, so they intentionally stay outside the
  -- screen-space inverse transform.
  local x, y = self:anchor("target")
  g.setColor(1, 0.96, 0.55, 0.72 * fade)
  for i = 0, 5 do
    local radius = 8 + ((self.tick * 2.2 + i * 17) % 72)
    g.circle("line", x, y - 12, radius)
  end
end

local PROGRAMS = { MIST = mist, HAZE = haze, FLASH = flashMove }

function ScreenFx.drawMove(self)
  local key = self and self.spec and self.spec.key
  local draw = key and PROGRAMS[key]
  if not draw then return false end
  draw(self, love.graphics)
  return true
end

local function marginGeometry(viewport)
  local ww, wh = viewport.width or 0, viewport.height or 0
  local scale = (viewport.gameHeight or 0) / HEIGHT
  if scale <= 0 then scale = viewport.scale or 1 end
  local cw, ch = WIDTH * scale, HEIGHT * scale
  -- A 304x144 wide-battle canvas contains the classic animation layer in its
  -- center. Height is the stable yardstick in both classic and wide layouts.
  local cx = (viewport.gameX or 0) + ((viewport.gameWidth or cw) - cw) / 2
  local cy = viewport.gameY or 0
  return scale, cx, cy, {
    { 0, 0, ww, math.max(0, cy) },
    { 0, cy, math.max(0, cx), ch },
    { cx + cw, cy, math.max(0, ww - cx - cw), ch },
    { 0, cy + ch, ww, math.max(0, wh - cy - ch) },
  }
end

local function drawOperation(g, operation, viewport, scale, cx, cy)
  if operation.kind == "region" then
    local x1 = operation.x <= 0 and 0 or cx + operation.x * scale
    local y1 = operation.y <= 0 and 0 or cy + operation.y * scale
    local x2 = operation.x + operation.width >= WIDTH and viewport.width
      or cx + (operation.x + operation.width) * scale
    local y2 = operation.y + operation.height >= HEIGHT and viewport.height
      or cy + (operation.y + operation.height) * scale
    g.setColor(operation.color[1], operation.color[2], operation.color[3], operation.alpha)
    g.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
    return
  end

  local value = operation.value
  local drawScale = operation.scale * scale
  local width, height = value.frameWidth * drawScale, value.frameHeight * drawScale
  if width <= 0 or height <= 0 then return end
  local quad = value.quads[math.floor(operation.frame or 0) % value.frames + 1]
  local phaseX = ((operation.x or 0) % (value.frameWidth * operation.scale)
    - value.frameWidth * operation.scale) * scale
  local phaseY = ((operation.y or 0) % (value.frameHeight * operation.scale)
    - value.frameHeight * operation.scale) * scale
  local startX, startY = cx + phaseX, cy + phaseY
  while startX > 0 do startX = startX - width end
  while startY > 0 do startY = startY - height end
  g.setColor(operation.color[1], operation.color[2], operation.color[3], operation.alpha)
  for py = startY, viewport.height + height, height do
    for px = startX, viewport.width + width, width do
      g.draw(value.image, quad, px, py, 0, drawScale, drawScale)
    end
  end
end

-- Extend recorded screen primitives into borderless margins after the game
-- canvas has been composed. Anchored VFX are never replayed here.
function ScreenFx.present(game, viewport)
  local options = game and game.save and game.save.options
  local enabled = options and options.videoMode == "borderless"
  ScreenFx.setBorderless(enabled)
  if not (enabled and pending and #pending.operations > 0 and viewport) then return false end
  local g = love and love.graphics
  if not g then return false end
  local scale, cx, cy, clips = marginGeometry(viewport)
  local oldBlend, oldAlpha = g.getBlendMode()
  local r, gr, b, a = g.getColor()
  local oldX, oldY, oldW, oldH = g.getScissor()
  g.setBlendMode("alpha", "alphamultiply")
  for _, operation in ipairs(pending.operations) do
    for _, clip in ipairs(clips) do
      if clip[3] > 0 and clip[4] > 0 then
        g.setScissor(clip[1], clip[2], clip[3], clip[4])
        drawOperation(g, operation, viewport, scale, cx, cy)
      end
    end
  end
  if oldX then g.setScissor(oldX, oldY, oldW, oldH) else g.setScissor() end
  g.setColor(r or 1, gr or 1, b or 1, a or 1)
  g.setBlendMode(oldBlend or "alpha", oldAlpha)
  return true
end

return ScreenFx

-- Shared screen-space presentation primitives.
--
-- Effects are authored on Gen1's 160x144 animation layer. Dramaless Shape may
-- transform that layer around the projected combatants in every video mode,
-- while Gen1Recomp composites it into a larger desktop surface. Screen-wide
-- primitives always cancel the combatant transform; in borderless mode they
-- are also replayed into the outer margins after composition. Anchored
-- particles keep the normal path.

local V = ...
local ScreenFx = {}

local WIDTH, HEIGHT = 160, 144
local borderless = false
local pending

local function liveViewport()
  if not (V and type(V.require) == "function") then return nil end
  local ok, Host = pcall(V.require, "BattleHost")
  if not (ok and Host and type(Host.animationViewport) == "function") then
    return nil
  end
  local viewportOk, viewport = pcall(Host.animationViewport)
  return viewportOk and viewport or nil
end

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

-- Coordinates returned by the current 3D camera are expressed relative to
-- the classic animation layer. In borderless mode that layer is centred in a
-- larger window, so camera-visible model bones may legitimately have a
-- negative x/y or lie beyond 160x144. Keep a small off-screen lead-in for
-- projectiles while still rejecting leaked framebuffer/world coordinates.
function ScreenFx.anchorBounds()
  local viewport = borderless and liveViewport() or nil
  if viewport and tonumber(viewport.scale) and viewport.scale > 0 then
    local pad = 64
    return -viewport.x / viewport.scale - pad,
      (viewport.width - viewport.x) / viewport.scale + pad,
      -viewport.y / viewport.scale - pad,
      (viewport.height - viewport.y) / viewport.scale + pad
  end
  return 0, WIDTH, 0, HEIGHT
end

-- Local particles belong to the 3D scene, not the centred Game Boy UI.
-- Redirect their draw to the already-rendered world canvas and apply the
-- exact inverse of BattleHost's current framebuffer projection. Because this
-- runs after the world render but before Renderer composites the UI, beams
-- and impacts can reach models in the margins without covering the HUD.
function ScreenFx.beginAnchored(g)
  if not (g and g.getCanvas and g.setCanvas) then return nil end
  local viewport = liveViewport()
  if not (viewport and viewport.surface and viewport.scale > 0) then return nil end
  local token = { canvas = g.getCanvas(), scale = viewport.scale,
    width = viewport.width, height = viewport.height, screen = true }
  g.setCanvas(viewport.surface)
  if g.origin then g.origin() end
  if g.setShader then g.setShader() end
  if g.setScissor then g.setScissor() end
  -- Particle programs keep their authored sizes by drawing in scaled units,
  -- but their anchors come from raw framebuffer projections divided only by
  -- this scale. There is deliberately no Game Boy canvas origin here.
  g.scale(viewport.scale, viewport.scale)
  return token
end

function ScreenFx.endAnchored(g, token)
  if not token then return end
  if token.canvas ~= nil then g.setCanvas(token.canvas) else g.setCanvas() end
end

local function record(owner, operation)
  if not owner then return end
  if not pending or pending.owner ~= owner then ScreenFx.activate(owner) end
  if owner.anchoredRedirect and owner.anchoredRedirect.screen then
    pending.shownSurface = true
  end
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
  -- Secondary attachment passes replay localized particles only. Stadium's
  -- second dispatch does not justify multiplying this mod's shared
  -- presentation layer (camera, UI-wide wash, or borderless margin replay).
  if owner and owner.attachmentPass and owner.attachmentPass.secondary then
    return false
  end
  if not g or (alpha or 0) <= 0 then return false end
  color = color or { 1, 1, 1 }
  record(owner, { kind = "region", color = color, alpha = alpha,
    x = x, y = y, width = width, height = height })
  -- Borderless presentation has no single 160x144 screen rectangle. Drawing
  -- here and then filling only the outer margins in render.hud produces two
  -- differently-scaled copies with a visible centered Game Boy-sized block.
  -- Record the operation now and draw it once over the completed window.
  if owner and (borderless or (owner.anchoredRedirect
      and owner.anchoredRedirect.screen)) then return true end
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
  if options.owner and options.owner.attachmentPass
      and options.owner.attachmentPass.secondary then
    return false
  end
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
  if options.owner and (borderless or (options.owner.anchoredRedirect
      and options.owner.anchoredRedirect.screen)) then return true end
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
  if borderless or self.anchoredRedirect then
    record(self, { kind = "mist", tick = self.tick, fade = fade })
    ScreenFx.pop(g, pushed)
    return
  end
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
  if borderless or self.anchoredRedirect then
    record(self, { kind = "haze", tick = self.tick, fade = fade })
    ScreenFx.pop(g, pushed)
    return
  end
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
  -- These programs are entirely shared screen presentation (with only
  -- incidental decoration).  A secondary attachment has no independent
  -- screen layer, so consume the pass without replaying the program.
  if self.attachmentPass and self.attachmentPass.secondary then return true end
  draw(self, love.graphics)
  return true
end

local function marginGeometry(viewport)
  local live = liveViewport()
  if live and live.scale and live.scale > 0 then
    local ww, wh = viewport.width or live.width or 0,
      viewport.height or live.height or 0
    local scale, cx, cy = live.scale, live.x, live.y
    local cw, ch = WIDTH * scale, HEIGHT * scale
    return scale, cx, cy, {
      { 0, 0, ww, math.max(0, cy) },
      { 0, cy, math.max(0, cx), ch },
      { cx + cw, cy, math.max(0, ww - cx - cw), ch },
      { 0, cy + ch, ww, math.max(0, wh - cy - ch) },
    }
  end
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

local function drawOperation(g, operation, viewport, scale, cx, cy, clip)
  if operation.kind == "mist" then
    local sx, sy = viewport.width / WIDTH, viewport.height / HEIGHT
    g.setLineWidth(math.max(1, 1.2 * math.min(sx, sy)))
    for i = 0, 8 do
      local y = (18 + i * 15 + math.sin(operation.tick * 0.045 + i) * 7) * sy
      local x = (((operation.tick * (0.22 + i * 0.015) + i * 31) % 210) - 25) * sx
      g.setColor(0.84, 0.95, 1,
        operation.fade * (0.18 + (i % 3) * 0.055))
      g.ellipse("line", x, y, (30 + (i % 4) * 9) * sx,
        (7 + (i % 3) * 2) * sy)
    end
    return
  elseif operation.kind == "haze" then
    local sx, sy = viewport.width / WIDTH, viewport.height / HEIGHT
    for i = 0, 7 do
      local width = 34 + (i % 3) * 15
      local x = ((i * 37 - operation.tick * (0.28 + i * 0.025)) % 220) - 30
      local y = 10 + i * 19
      g.setColor(0.58, 0.68, 0.78,
        operation.fade * (0.08 + (i % 2) * 0.04))
      g.rectangle("fill", x * sx, y * sy, width * sx,
        (8 + (i % 3) * 3) * sy)
    end
    return
  end
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
  local clipX, clipY = clip[1], clip[2]
  local clipRight, clipBottom = clipX + clip[3], clipY + clip[4]
  while startX > clipX do startX = startX - width end
  while startX + width <= clipX do startX = startX + width end
  while startY > clipY do startY = startY - height end
  while startY + height <= clipY do startY = startY + height end
  g.setColor(operation.color[1], operation.color[2], operation.color[3], operation.alpha)
  for py = startY, clipBottom, height do
    for px = startX, clipRight, width do
      g.draw(value.image, quad, px, py, 0, drawScale, drawScale)
    end
  end
end

-- Extend recorded screen primitives into borderless margins after the game
-- canvas has been composed. Anchored VFX are never replayed here.
function ScreenFx.present(game, viewport)
  -- Recorded operations belong only to the frame that just drew them.  The
  -- HUD hook also runs over party screens, menus, and transitions, so keeping
  -- this table alive would replay the last battle wash or tiled field over an
  -- unrelated later screen until another move explicitly replaced it.
  local frame = pending
  pending = nil
  local options = game and game.save and game.save.options
  local isBorderless = options and options.videoMode == "borderless"
  local enabled = isBorderless or (frame and frame.shownSurface)
  ScreenFx.setBorderless(isBorderless)
  if not (enabled and frame and #frame.operations > 0 and viewport) then return false end
  local g = love and love.graphics
  if not g then return false end
  local scale, cx, cy = marginGeometry(viewport)
  local clips = { { 0, 0, viewport.width or 0, viewport.height or 0 } }
  -- render.hud is shared with other mods and the touch-control pass. Fence
  -- every graphics setting, including settings this module does not normally
  -- touch, and restore it even if an image becomes invalid during hot reload.
  g.push("all")
  local ok, err = pcall(function()
    g.setBlendMode("alpha", "alphamultiply")
    for _, operation in ipairs(frame.operations) do
      for _, clip in ipairs(clips) do
        if clip[3] > 0 and clip[4] > 0 then
          g.setScissor(clip[1], clip[2], clip[3], clip[4])
          drawOperation(g, operation, viewport, scale, cx, cy, clip)
        end
      end
    end
  end)
  g.pop()
  if not ok then error(err, 0) end
  return true
end

return ScreenFx

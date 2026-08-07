-- Delegating AnimPlayer adapter for the complete Gen 1 move roster.

local V = ...
local Registry = V.require("effects/MoveSpecs")
local Assets = V.require("StadiumAssets")
local ThunderShock = V.require("effects/ThunderShockSpec")
local DramaticShapeState = V.require("DramaticShapeState")
local GenericMoveRenderer = V.require("effects/GenericMoveRenderer")

local Player = {}
Player.__index = Player

local ANCHOR = { player = { 26, 96 }, enemy = { 124, 56 } }

local function call(inner, name, ...)
  local fn = inner and inner[name]
  if type(fn) ~= "function" then return nil end
  return fn(inner, ...)
end

local function hash01(a, b, c)
  local n = (a * 73856093 + b * 19349663 + c * 83492791) % 104729
  return n / 104729
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function stadiumParticleScale(callback, age, seed)
  local profile = ThunderShock.scaleProfiles[callback]
  if not profile then return 1 end
  local target = profile.target
  if not target then
    target = profile.targetMin
      + hash01(seed, 41, 73) * (profile.targetMax - profile.targetMin)
  end
  return math.min(target, profile.initial + profile.step * age)
end

function Player.new(inner, options, logger, companion, cameraCompanion)
  return setmetatable({ inner = inner, options = options, logger = logger,
    companion = companion, cameraCompanion = cameraCompanion,
    custom = false, tick = 0, warned = {},
    drawWarned = false, context = nil }, Player)
end

function Player:setMoveContext(payload)
  self.context = payload
end

function Player:warn(key, reason)
  if self.warned[key] then return end
  self.warned[key] = true
  if self.logger and self.logger.warn then
    self.logger:warn("%s falls back to the Gen1 animation: %s", tostring(key), tostring(reason))
  end
end

function Player:stadiumModelShowing()
  self.dsState = DramaticShapeState.read(
    self.companion, self.attackerIsPlayer, self.cameraCompanion)
  return self.dsState and self.dsState.attackerShowing or false
end

function Player:start(moveId, attackerIsPlayer, opts)
  self.custom, self.spec = false, nil
  local spec = Registry.get(moveId)
  if not spec or not self.options() then
    return call(self.inner, "start", moveId, attackerIsPlayer, opts)
  end

  self.attackerIsPlayer = attackerIsPlayer and true or false
  self.dsState = DramaticShapeState.read(
    self.companion, self.attackerIsPlayer, self.cameraCompanion)
  if spec.bodyOnly and not self:stadiumModelShowing() then
    return call(self.inner, "start", moveId, attackerIsPlayer, opts)
  end
  local ok, err = Assets.has(spec.assets)
  if not ok and #spec.assets > 0 then
    self:warn(spec.key, err)
    return call(self.inner, "start", moveId, attackerIsPlayer, opts)
  end

  -- Keep the original player as the audio clock, but suppress its GB sprites
  -- and screen effects while a Stadium presentation is active.
  call(self.inner, "start", moveId, attackerIsPlayer, opts)
  self.custom, self.spec, self.tick = true, spec, 0
end

function Player:anchor(which)
  local attackerSide = self.attackerIsPlayer and "player" or "enemy"
  local targetSide = self.attackerIsPlayer and "enemy" or "player"
  local side = which == "attacker" and attackerSide or targetSide
  local p = ANCHOR[side]

  -- DS transforms the complete animation layer after this draw. Its camera
  -- wrapper supplies translation and uniform scale but no rotation, so a
  -- cinematic orbit can otherwise leave an authored target anchor beside
  -- the newly projected Pokemon. Draw at the inverse-transformed point;
  -- DS's outer transform then lands the particle on the exact live mark.
  local state = self.dsState
  local transform = state and state.layerTransform
  local projected = state and state.projectedAnchors
  local desired = projected and projected[side]
  if transform and desired and transform.scale > 0 then
    local authoredCenter = transform.authoredCenter
    local projectedCenter = transform.projectedCenter
    return authoredCenter[1] + (desired[1] - projectedCenter[1]) / transform.scale,
           authoredCenter[2] + (desired[2] - projectedCenter[2]) / transform.scale
  end
  return p[1], p[2]
end

function Player:update()
  if not self.custom then return call(self.inner, "update") end
  self.tick = self.tick + 1
  if self.inner and not call(self.inner, "isDone") then call(self.inner, "update") end
end

function Player:isDone()
  if not self.custom then return call(self.inner, "isDone") ~= false end
  if self.spec.bodyOnly then return call(self.inner, "isDone") ~= false end
  return self.tick >= self.spec.duration
end

function Player:pollEffects()
  if not self.custom then return call(self.inner, "pollEffects") or {} end
  local original = call(self.inner, "pollEffects") or {}
  local sounds = {}
  for _, event in ipairs(original) do
    if event.sound then sounds[#sounds + 1] = event end
  end
  return sounds
end

local function drawAsset(g, asset, frame, x, y, rotation, sx, sy, ox, oy)
  if not asset then return end
  frame = (frame - 1) % asset.frames + 1
  g.draw(asset.image, asset.quads[frame], x, y, rotation or 0,
    sx or 1, sy or sx or 1, ox or asset.frameWidth / 2, oy or asset.frameHeight / 2)
end

local function lineBetween(g, ax, ay, bx, by, along, across)
  local dx, dy = bx - ax, by - ay
  local length = math.sqrt(dx * dx + dy * dy)
  if length == 0 then return ax, ay end
  local nx, ny = -dy / length, dx / length
  return ax + dx * along + nx * across, ay + dy * along + ny * across
end

local function drawHit(self, localTick, variant)
  if localTick < 0 or localTick >= 24 then return end
  local g = love.graphics
  local x, y = self:anchor("target")
  local fade = 1 - localTick / 24
  local spin = (self.attackerIsPlayer and 1 or -1) * localTick * 0.08
  local ia = Assets.get("impact_ia")
  local ii = Assets.get("impact_i")
  if variant ~= "small" and ia then
    g.setColor(1, 0.96, 0.72, fade * 0.9)
    drawAsset(g, ia, math.floor(localTick / 3) + 1, x, y - 10,
      spin, 0.48 + localTick * 0.008)
  end
  if ii then
    local tint = variant == "kick" and { 1, 0.72, 0.25 }
      or variant == "psychic" and { 0.92, 0.45, 1 }
      or { 1, 1, 1 }
    g.setColor(tint[1], tint[2], tint[3], fade)
    drawAsset(g, ii, localTick + 1, x, y - 10, -spin,
      variant == "small" and 0.38 or 0.55)
  end
end

local function drawThunderShock(self)
  local g = love.graphics
  local asset = Assets.get("electric")
  if not asset then return end
  local function stage(name, localTick)
    if localTick < 0 then return end
    for si, schedule in ipairs(ThunderShock[name].schedules) do
      for bi = 0, schedule.bursts - 1 do
        local born = schedule.at + schedule.interval * bi
        local age = localTick - born
        if age >= 0 and age < 20 then
          local seed = si * 31 + bi * 17 + (name == "impact" and 97 or 0)
          local spread = name == "impact" and 22 or 16
          local px = (hash01(seed, 1, 7) - 0.5) * spread
          local py = (hash01(seed, 2, 11) - 0.5) * 9
          local angle = (hash01(seed, 3, 13) - 0.5) * 0.42
          if schedule.callback == "func_8433D070" then angle = angle - 0.34 end
          if schedule.callback == "func_8433D224" then angle = angle + 0.34 end
          if schedule.callback == "func_8433D560" then py = py - 12 - age * 0.25 end
          local width = ({ [0x14] = 32, [0x13] = 16,
                           [0x12] = 32, [0x0F] = 8 })[schedule.preset] or 16
          local nativeScale = stadiumParticleScale(schedule.callback, age, seed)
          -- Portable projection anchor. The changing component is Stadium's
          -- source world scale; the fixed component comes from its base
          -- battle-camera distance/FOV table and remains capture-tunable.
          local projectedScale = nativeScale * ThunderShock.portableWorldToPixel
          local x, y = self:anchor(name == "primary" and "attacker" or "target")
          g.setColor(1, 0.92, 0.22, 1 - age / 20)
          drawAsset(g, asset, age + 1, x + px, y - 22 + py,
            angle, (width / asset.frameWidth) * projectedScale, projectedScale)
        end
      end
    end
  end
  stage("primary", self.tick)
  stage("impact", self.tick - self.spec.impactAt)
end

local function drawThunderWave(self)
  local g = love.graphics
  local asset = Assets.get("thunder_wave")
  local x, y = self:anchor("target")
  for series = 0, 2 do
    for burst = 0, 11 do
      local born = burst * 8 + series * 2
      local age = self.tick - born
      if age >= 0 and age < 18 then
        local fade = 1 - age / 18
        g.setColor(1, 0.92, 0.18, fade * 0.72)
        local scale = 0.18 + age * 0.012 + series * 0.035
        drawAsset(g, asset, 1, x, y - 12, series * 2.094 + age * 0.055,
          scale, scale * (0.78 + series * 0.08))
      end
    end
  end
  local impact = self.tick - self.spec.impactAt
  if impact >= 0 and impact < 44 then
    for i = 0, 2 do
      local age = impact - i * 6
      if age >= 0 and age < 22 then
        g.setColor(1, 0.82, 0.08, (1 - age / 22) * 0.85)
        drawAsset(g, asset, 1, x, y - 12, -age * 0.08 + i,
          0.22 + age * 0.014)
      end
    end
  end
end

local function drawScratch(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  local claw, spark, swipe = Assets.get("scratch_claw"), Assets.get("scratch_spark"), Assets.get("scratch_swipe")
  for i, born in ipairs({ 0, 4, 10 }) do
    local age = self.tick - born
    if age >= 0 and age < 22 then
      local off = (i - 2) * 7
      g.setColor(1, 1, 1, 1 - age / 22)
      drawAsset(g, claw, age + 1, x + off, y - 12 + off * 0.25,
        -0.56, 0.55)
    end
  end
  local age = self.tick - 30
  if age >= 0 and age < 24 then
    g.setColor(1, 0.96, 0.88, 1 - age / 24)
    drawAsset(g, swipe, 1, x, y - 12, -0.4, 0.48 + age * 0.006)
    drawAsset(g, spark, age + 1, x + 4, y - 14, age * 0.1, 0.55)
  end
  drawHit(self, self.tick - self.spec.impactAt, "small")
end

local function drawSand(self)
  local g = love.graphics
  local asset = Assets.get("sand")
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  for i = 1, 18 do
    local born = (i - 1) * 3
    local age = self.tick - born
    if age >= 0 and age < 34 then
      local p = clamp(age / 27, 0, 1)
      local arc = math.sin(p * math.pi) * (8 + (i % 4) * 2)
      local x, y = lineBetween(g, ax, ay - 10, bx, by - 10, p,
        (hash01(i, 7, 3) - 0.5) * 18)
      g.setColor(0.88, 0.70, 0.34, (1 - age / 34) * 0.9)
      drawAsset(g, asset, age + i, x, y - arc, age * 0.06, 0.28 + (i % 3) * 0.04)
    end
  end
  local impact = self.tick - self.spec.impactAt
  if impact >= 0 and impact < 28 then
    for i = 1, 7 do
      local angle = i * 0.9 + impact * 0.06
      g.setColor(0.86, 0.66, 0.30, 1 - impact / 28)
      drawAsset(g, asset, impact + i, bx + math.cos(angle) * (8 + impact * 0.3),
        by - 10 + math.sin(angle) * (5 + impact * 0.2), angle, 0.24)
    end
  end
end

local function drawQuick(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local fade = clamp(1 - self.tick / self.spec.impactAt, 0, 1)
  if self.tick < self.spec.impactAt then
    g.setLineWidth(1.5)
    for i = 1, 8 do
      local p = ((self.tick * 0.09 + i * 0.13) % 1)
      local x1, y1 = lineBetween(g, ax, ay - 10, bx, by - 10, p, (i - 4.5) * 4)
      local x2, y2 = lineBetween(g, ax, ay - 10, bx, by - 10, math.min(1, p + 0.16), (i - 4.5) * 4)
      g.setColor(1, 1, 1, fade * 0.75)
      g.line(x1, y1, x2, y2)
    end
  end
  drawHit(self, self.tick - self.spec.impactAt)
end

local function drawGust(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local p = clamp(self.tick / self.spec.impactAt, 0, 1)
  local cx, cy = lineBetween(g, ax, ay - 12, bx, by - 12, p, 0)
  g.setLineWidth(1.25)
  for i = 0, 4 do
    local age = self.tick - i * 5
    if age >= 0 then
      local radius = 6 + ((age * 0.6 + i * 3) % 17)
      g.setColor(0.82, 0.93, 1, clamp(0.85 - age / 90, 0, 0.85))
      g.arc("line", cx, cy, radius, age * 0.10 + i, age * 0.10 + i + 4.5, 20)
    end
  end
  drawHit(self, self.tick - self.spec.impactAt, "small")
end

local function drawHorn(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local p = clamp(self.tick / self.spec.impactAt, 0, 1)
  local x, y = lineBetween(g, ax, ay - 11, bx, by - 11, p, 0)
  g.setColor(1, 0.92, 0.55, clamp(1 - self.tick / self.spec.impactAt, 0, 1))
  g.setLineWidth(2)
  g.polygon("line", x + 10 * (self.attackerIsPlayer and 1 or -1), y,
    x - 5 * (self.attackerIsPlayer and 1 or -1), y - 4,
    x - 5 * (self.attackerIsPlayer and 1 or -1), y + 4)
  drawHit(self, self.tick - self.spec.impactAt)
end

local function drawLeer(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  local pulse = 0.5 + 0.5 * math.sin(self.tick * 0.32)
  local fade = clamp(1 - self.tick / self.spec.duration, 0, 1)
  g.setColor(1, 0.08, 0.06, fade * (0.32 + pulse * 0.28))
  g.circle("fill", x, y - 12, 22 + pulse * 4)
  g.setColor(1, 0.82, 0.50, fade)
  g.polygon("fill", x - 14, y - 17, x - 3, y - 13, x - 14, y - 9)
  g.polygon("fill", x + 14, y - 17, x + 3, y - 13, x + 14, y - 9)
end

local function drawString(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  g.setLineWidth(1.2)
  for i = 0, 17 do
    local born = i * 7
    local age = self.tick - born
    if age >= 0 and age < 58 then
      local p = clamp(age / 34, 0, 1)
      local sway = math.sin(age * 0.35 + i) * 5
      local x1, y1 = lineBetween(g, ax, ay - 12, bx, by - 12, math.max(0, p - 0.22), sway)
      local x2, y2 = lineBetween(g, ax, ay - 12, bx, by - 12, p, -sway)
      g.setColor(0.96, 0.96, 0.86, (1 - age / 58) * 0.88)
      g.line(x1, y1, x2, y2)
    end
  end
  if self.tick > 32 then
    local fade = clamp((self.spec.duration - self.tick) / 50, 0, 1)
    g.setColor(0.96, 0.96, 0.88, fade * 0.78)
    for r = 7, 22, 5 do g.circle("line", bx, by - 12, r) end
    for i = 0, 5 do
      local a = i * math.pi / 3
      g.line(bx, by - 12, bx + math.cos(a) * 23, by - 12 + math.sin(a) * 23)
    end
  end
end

local function drawConfusion(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  g.setLineWidth(1.5)
  for i = 0, 5 do
    local born = i * 7
    local age = self.tick - born
    if age >= 0 and age < 50 then
      local radius = 5 + age * 0.48
      g.setColor(0.78, 0.30 + i * 0.035, 1, (1 - age / 50) * 0.8)
      g.ellipse("line", x, y - 12, radius, radius * 0.52)
    end
  end
  local wash = clamp(math.sin(self.tick * 0.11) * 0.06 + 0.06, 0, 0.12)
  g.setColor(0.55, 0.08, 0.72, wash)
  g.rectangle("fill", 0, 0, 160, 144)
  drawHit(self, self.tick - self.spec.impactAt, "psychic")
end

local function drawDoubleKick(self)
  drawHit(self, self.tick - self.spec.impactAt, "kick")
  drawHit(self, self.tick - self.spec.impactAt - 17, "kick")
end

local DRAW = {
  thundershock = drawThunderShock,
  thunder_wave = drawThunderWave,
  scratch = drawScratch,
  sand = drawSand,
  quick = drawQuick,
  gust = drawGust,
  horn = drawHorn,
  leer = drawLeer,
  string = drawString,
  confusion = drawConfusion,
  double_kick = drawDoubleKick,
  single_kick = function(self) drawHit(self, self.tick - self.spec.impactAt, "kick") end,
  tackle = function(self) drawHit(self, self.tick - self.spec.impactAt) end,
  generic = function(self) GenericMoveRenderer.draw(self, Assets) end,
  body_only = function() end,
}

local function drawCustom(self)
  local g = love and love.graphics
  if not (g and self.spec) then return end
  -- Cinematic cameras can move between every frame. Refresh their read-only
  -- projected anchors immediately before drawing rather than using the shot
  -- captured when the move started.
  self.dsState = DramaticShapeState.read(
    self.companion, self.attackerIsPlayer, self.cameraCompanion)
  local oldMode, oldAlpha = g.getBlendMode()
  local oldWidth = g.getLineWidth and g.getLineWidth() or 1
  local r, gg, b, a = g.getColor()
  g.setBlendMode("alpha", "alphamultiply")
  local draw = DRAW[self.spec.kind]
  if draw then draw(self) end
  g.setColor(r or 1, gg or 1, b or 1, a or 1)
  if g.setLineWidth then g.setLineWidth(oldWidth) end
  g.setBlendMode(oldMode or "alpha", oldAlpha)
end

function Player:draw(...)
  if not self.custom then return call(self.inner, "draw", ...) end
  local ok, err = pcall(drawCustom, self)
  if ok then return end
  if not self.drawWarned then
    self.drawWarned = true
    if self.logger and self.logger.warn then
      self.logger:warn("Stadium effect draw failed; using Gen1 renderer: %s", tostring(err))
    end
  end
  return call(self.inner, "draw", ...)
end

function Player:drawSprites(...)
  return call(self.inner, "drawSprites", ...)
end

function Player:finalSprites()
  return call(self.inner, "finalSprites")
end

function Player:release()
  self.custom, self.spec, self.context = false, nil, nil
  return call(self.inner, "release")
end

return Player

-- Complete-roster Stadium-style procedural renderer.
-- Exact source-traced move renderers override this module where available.

local V = ...
local ScreenFx = V.require("effects/StadiumScreenFx")
local Renderer = {}

local COLORS = {
  NORMAL = { 1.00, 0.94, 0.72 }, FIGHTING = { 1.00, 0.42, 0.18 },
  FLYING = { 0.72, 0.90, 1.00 }, POISON = { 0.72, 0.24, 0.84 },
  GROUND = { 0.72, 0.48, 0.20 }, ROCK = { 0.66, 0.58, 0.38 },
  BUG = { 0.62, 0.82, 0.18 }, GHOST = { 0.46, 0.30, 0.72 },
  FIRE = { 1.00, 0.28, 0.06 }, WATER = { 0.18, 0.62, 1.00 },
  GRASS = { 0.24, 0.86, 0.28 }, ELECTRIC = { 1.00, 0.88, 0.08 },
  PSYCHIC = { 0.92, 0.26, 0.84 }, ICE = { 0.56, 0.94, 1.00 },
  DRAGON = { 0.38, 0.52, 1.00 },
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function hash01(a, b, c)
  local n = (a * 73856093 + b * 19349663 + c * 83492791) % 104729
  return n / 104729
end

local function between(ax, ay, bx, by, p, across)
  local dx, dy = bx - ax, by - ay
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.001 then return ax, ay end
  return ax + dx * p - dy / length * across,
         ay + dy * p + dx / length * across
end

local function tint(g, family, alpha, boost)
  local c = COLORS[family] or COLORS.NORMAL
  boost = boost or 1
  g.setColor(clamp(c[1] * boost, 0, 1), clamp(c[2] * boost, 0, 1),
             clamp(c[3] * boost, 0, 1), alpha)
end

local function glyph(g, family, x, y, size, phase, alpha)
  tint(g, family, alpha)
  if family == "FIRE" then
    g.circle("fill", x, y + size * 0.25, size * 0.62)
    g.polygon("fill", x - size * 0.55, y + size * 0.2,
      x + size * 0.12, y - size, x + size * 0.58, y + size * 0.35)
  elseif family == "WATER" then
    g.circle("line", x, y, size)
    g.circle("fill", x - size * 0.2, y - size * 0.25, size * 0.28)
  elseif family == "GRASS" then
    local cs, sn = math.cos(phase), math.sin(phase)
    g.polygon("fill", x + cs * size, y + sn * size,
      x - sn * size * 0.48, y + cs * size * 0.48,
      x - cs * size, y - sn * size,
      x + sn * size * 0.48, y - cs * size * 0.48)
  elseif family == "ELECTRIC" then
    g.setLineWidth(math.max(1, size * 0.28))
    g.line(x - size, y - size * 0.5, x - size * 0.2, y,
      x - size * 0.48, y + size, x + size, y - size * 0.18)
  elseif family == "ICE" then
    g.polygon("line", x, y - size, x + size * 0.72, y,
      x, y + size, x - size * 0.72, y)
    g.line(x - size * 0.65, y, x + size * 0.65, y)
  elseif family == "PSYCHIC" then
    g.ellipse("line", x, y, size, size * 0.5)
    g.ellipse("line", x, y, size * 0.55, size)
  elseif family == "POISON" then
    g.circle("line", x, y, size)
    g.circle("fill", x - size * 0.28, y - size * 0.2, size * 0.18)
  elseif family == "GROUND" then
    g.rectangle("fill", x - size * 0.65, y - size * 0.4,
      size * 1.3, size * 0.8)
  elseif family == "ROCK" then
    g.polygon("fill", x - size, y + size * 0.4, x - size * 0.45, y - size,
      x + size * 0.65, y - size * 0.55, x + size, y + size * 0.62,
      x, y + size)
  elseif family == "FLYING" then
    g.arc("line", x, y, size, phase, phase + math.pi * 1.45, 12)
    g.arc("line", x, y, size * 0.55, phase + math.pi, phase + math.pi * 2.35, 10)
  elseif family == "BUG" then
    g.circle("line", x, y, size * 0.65)
    g.line(x - size, y - size, x + size, y + size,
      x + size, y - size, x - size, y + size)
  elseif family == "GHOST" then
    g.arc("line", x, y, size, phase, phase + math.pi * 1.6, 14)
    g.circle("fill", x - size * 0.3, y - size * 0.2, size * 0.12)
    g.circle("fill", x + size * 0.3, y - size * 0.2, size * 0.12)
  elseif family == "DRAGON" then
    g.circle("line", x, y, size)
    g.arc("line", x, y, size * 1.4, phase, phase + math.pi, 12)
  else
    g.line(x - size, y - size * 0.5, x + size, y + size * 0.5)
    g.line(x - size, y + size * 0.5, x + size, y - size * 0.5)
  end
end

local function drawAsset(g, asset, frame, x, y, rotation, scale, alpha)
  if not asset then return end
  frame = (frame - 1) % asset.frames + 1
  g.setColor(1, 1, 1, alpha)
  g.draw(asset.image, asset.quads[frame], x, y, rotation or 0,
    scale or 1, scale or 1, asset.frameWidth / 2, asset.frameHeight / 2)
end

local function impact(self, Assets, age, hitIndex)
  if age < 0 or age >= 24 then return end
  local g = love.graphics
  local x, y = self:anchor("target")
  local family = self.spec.type or "NORMAL"
  local fade = 1 - age / 24
  local strength = clamp((self.spec.power or 40) / 80, 0.55, 1.35)
    * (self.spec.impactScale or 1)
  local ia, ii = Assets.get("impact_ia"), Assets.get("impact_i")
  tint(g, family, fade, 1.15)
  if ia then drawAsset(g, ia, math.floor(age / 3) + 1, x, y - 11,
      age * 0.08 + hitIndex, 0.36 * strength + age * 0.006, fade * 0.8) end
  if ii then drawAsset(g, ii, age + hitIndex, x, y - 11,
      -age * 0.1, 0.42 * strength, fade) end
  for i = 1, 7 do
    local angle = i * 0.897 + hitIndex
    glyph(g, family, x + math.cos(angle) * (5 + age * 0.45),
      y - 11 + math.sin(angle) * (4 + age * 0.35),
      1.4 + strength, angle + age * 0.1, fade * 0.78)
  end
end

-- Layer the exact cartridge texture selected by the move's fragment-62
-- resource signature over the portable geometry. This keeps the complete
-- roster recognizable even where an effect program has not yet received a
-- dedicated source port. Attachment-specific origins are intentionally not
-- consulted here.
local function sourceTexture(self, Assets)
  local value = self.spec.primaryAsset and Assets.get(self.spec.primaryAsset)
  if not value then return end
  local g = love.graphics
  local delivery = self.spec.delivery or "projectile"
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor(self.spec.anchor or "target")
  local unit = self.spec.particleScale or 1
  local base = (value.frameWidth >= 64 and 0.17 or 0.28) * unit
  local fade = clamp((self.spec.duration - self.tick) / 18, 0, 1)

  if delivery == "projectile" or delivery == "beam" then
    for i = 0, 5 do
      local delay = i * (delivery == "beam" and 3 or 5)
      local age = self.tick - delay
      if age >= 0 then
        local p = clamp(age / math.max(1, self.spec.impactAt - delay * 0.2), 0, 1)
        local x, y = between(ax, ay - 12, bx, by - 12, p,
          math.sin(i * 2.3 + self.tick * 0.16) * (delivery == "beam" and 3 or 6))
        drawAsset(g, value, math.floor(age / 3) + i + 1, x,
          y - math.sin(p * math.pi) * 5, age * 0.08 + i,
          base * (delivery == "beam" and 0.82 or 1), fade * 0.72)
      end
    end
  elseif delivery == "contact" then
    local age = self.tick - self.spec.impactAt + 8
    if age >= 0 and age < 30 then
      drawAsset(g, value, math.floor(age / 3) + 1, bx, by - 12,
        age * 0.08, base * (1 + age * 0.012), (1 - age / 30) * 0.82)
    end
  elseif delivery == "status" then
    local x, y = self:anchor(self.spec.anchor or "target")
    for i = 0, 3 do
      local angle = self.tick * 0.055 + i * math.pi / 2
      drawAsset(g, value, math.floor(self.tick / 4) + i + 1,
        x + math.cos(angle) * 16, y - 13 + math.sin(angle) * 10,
        -angle, base * 0.78, fade * 0.62)
    end
  end
end

local function projectile(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local family = self.spec.type or "NORMAL"
  local travel = math.max(1, self.spec.impactAt)
  local strength = clamp((self.spec.power or 35) / 70, 0.65, 1.5)
  for i = 1, 13 do
    local born = (i - 1) * 2
    local age = self.tick - born
    if age >= 0 and age <= travel then
      local p = clamp(age / math.max(1, travel - born * 0.25), 0, 1)
      local across = math.sin(p * math.pi * 3 + i) * (2 + i % 3)
      local x, y = between(ax, ay - 12, bx, by - 12, p, across)
      glyph(g, family, x, y - math.sin(p * math.pi) * 8,
        (2.2 + i % 3) * strength, age * 0.12 + i, 0.82)
    end
  end
end

local function beam(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local family = self.spec.type or "NORMAL"
  local grow = clamp(self.tick / math.max(1, self.spec.impactAt * 0.65), 0, 1)
  local fade = clamp((self.spec.impactAt + 20 - self.tick) / 20, 0, 1)
  local ex, ey = between(ax, ay - 12, bx, by - 12, grow, 0)
  for i = -2, 2 do
    tint(g, family, fade * (i == 0 and 1 or 0.42), i == 0 and 1.35 or 1)
    g.setLineWidth(i == 0 and 2.4 or 1)
    g.line(ax, ay - 12 + i * 1.5, ex, ey + i * 1.5)
  end
  for i = 1, 8 do
    local p = ((self.tick * 0.07 + i / 8) % 1) * grow
    local x, y = between(ax, ay - 12, bx, by - 12, p, math.sin(i + self.tick * 0.2) * 4)
    glyph(g, family, x, y, 2.2, i, fade)
  end
end

local function contact(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local p = clamp(self.tick / math.max(1, self.spec.impactAt), 0, 1)
  for i = 1, 8 do
    local q = clamp(p - i * 0.045, 0, 1)
    local x, y = between(ax, ay - 10, bx, by - 10, q, (i - 4.5) * 2.2)
    tint(g, self.spec.type or "NORMAL", (1 - q) * 0.65 + 0.2)
    g.setLineWidth(1.2)
    g.line(x - 7, y + 2, x + 3, y - 2)
  end
end

local function status(self)
  local g = love.graphics
  local which = self.spec.anchor or "target"
  local x, y = self:anchor(which)
  local family = self.spec.type or "NORMAL"
  local effect = self.spec.effect or ""
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  local rising = effect:find("_UP", 1, true) or effect:find("HEAL", 1, true)
  local falling = effect:find("DOWN", 1, true)
  for i = 1, 10 do
    local age = (self.tick + i * 7) % 46
    local angle = i * 0.628 + self.tick * 0.025
    local radius = 8 + (i % 3) * 5
    local yy = y - 12 + math.sin(angle) * radius * 0.45
    if rising then yy = y + 8 - age * 0.7 end
    if falling then yy = y - 34 + age * 0.7 end
    glyph(g, family, x + math.cos(angle) * radius, yy,
      2 + i % 2, angle, fade * (1 - age / 60))
  end
  if effect:find("SLEEP", 1, true) then
    for i = 0, 2 do
      local age = (self.tick + i * 15) % 45
      tint(g, "PSYCHIC", fade * (1 - age / 45))
      g.circle("line", x + age * 0.22, y - 25 - age * 0.35, 2 + i)
    end
  elseif effect:find("PARALYZE", 1, true) then
    for i = 0, 3 do glyph(g, "ELECTRIC", x + (i - 1.5) * 9,
      y - 12 + math.sin(self.tick * 0.2 + i) * 8, 4, i, fade) end
  elseif effect:find("CONFUSION", 1, true) then
    tint(g, "PSYCHIC", fade)
    g.ellipse("line", x, y - 28, 18, 6)
  end
end

local function screen(self)
  local g = love.graphics
  local family = self.spec.type or "NORMAL"
  local pulse = 0.5 + 0.5 * math.sin(self.tick * 0.16)
  local color = COLORS[family] or COLORS.NORMAL
  ScreenFx.fill(g, color, 0.06 + pulse * 0.08, self)
  tint(g, family, 0.35)
  for i = 1, 7 do
    local r = ((self.tick * 1.4 + i * 19) % 100)
    g.circle("line", 80, 64, r)
  end
end

local function slash(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local windup = clamp(self.tick / math.max(1, self.spec.impactAt), 0, 1)
  if windup < 1 then
    local x, y = between(ax, ay - 11, bx, by - 11, windup, 0)
    tint(g, self.spec.type, 0.25 + windup * 0.55)
    g.setLineWidth(1.2)
    for i = -1, 1 do g.line(x - 9, y + i * 4 + 5, x + 6, y + i * 4 - 5) end
  end
  local age = self.tick - self.spec.impactAt
  if age >= 0 and age < 26 then
    local fade = 1 - age / 26
    tint(g, self.spec.type, fade, 1.25)
    g.setLineWidth(2.2)
    for i = -1, 1 do
      local spread = i * 7
      g.arc("line", bx + spread, by - 11 + spread * 0.18,
        13 + age * 0.45, -2.55, 0.35, 18)
    end
  end
end

local function strike(self, variant)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local p = clamp(self.tick / math.max(1, self.spec.impactAt), 0, 1)
  local lift = variant == "kick" and math.sin(p * math.pi) * 15 or 5 * math.sin(p * math.pi)
  local x, y = between(ax, ay - 10, bx, by - 10, p, 0)
  tint(g, self.spec.type, clamp(1 - p * 0.35, 0, 1), 1.12)
  if variant == "kick" then
    g.setLineWidth(2.4)
    g.arc("line", x, y - lift, 8, -1.8, 1.0, 14)
    g.line(x - 8, y - lift + 7, x + 7, y - lift - 4)
  else
    g.circle("line", x, y - lift, 6 + 2 * math.sin(self.tick * 0.25))
    g.line(x - 10, y - lift, x + 10, y - lift)
  end
end

local function bite(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  local age = self.tick - self.spec.impactAt + 10
  if age < 0 or age >= 34 then return end
  local close = clamp(age / 12, 0, 1)
  local fade = clamp((34 - age) / 15, 0, 1)
  tint(g, self.spec.type, fade, 1.1)
  g.setLineWidth(2.2)
  local jaw = 15 * (1 - close)
  g.arc("line", x, y - 11 - jaw, 20, 0.18, math.pi - 0.18, 18)
  g.arc("line", x, y - 11 + jaw, 20, math.pi + 0.18, math.pi * 2 - 0.18, 18)
  for i = -2, 2 do
    g.line(x + i * 7, y - 28 + jaw, x + i * 6, y - 19 + jaw)
    g.line(x + i * 7, y + 6 - jaw, x + i * 6, y - 3 - jaw)
  end
end

local function grapple(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  local start = math.max(0, self.tick - math.floor(self.spec.impactAt * 0.45))
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  tint(g, self.spec.type, fade * 0.85)
  g.setLineWidth(1.6)
  for band = 0, 4 do
    local yy = y - 30 + band * 9
    local rx = 8 + clamp(start * 0.45, 0, 14)
    g.arc("line", x, yy, rx, start * 0.16 + band, start * 0.16 + band + 5.2, 20)
  end
end

local function volley(self, style)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local count = math.max(3, math.min(9, (self.spec.hits or 1) * 2 + 2))
  for i = 1, count do
    local age = self.tick - (i - 1) * 5
    local travel = math.max(16, self.spec.impactAt - (i - 1) * 2)
    if age >= 0 and age <= travel + 8 then
      local p = clamp(age / travel, 0, 1)
      local across = (i - (count + 1) / 2) * (style == "leaf" and 3.5 or 2.0)
      local x, y = between(ax, ay - 12, bx, by - 12, p, across * math.sin(p * math.pi))
      tint(g, self.spec.type, clamp(1 - math.max(0, age - travel) / 8, 0, 1), 1.08)
      if style == "leaf" then
        local s = 4 + (i % 2)
        local a = age * 0.24 + i
        g.polygon("fill", x + math.cos(a) * s, y + math.sin(a) * s,
          x - math.sin(a) * s * 0.55, y + math.cos(a) * s * 0.55,
          x - math.cos(a) * s, y - math.sin(a) * s,
          x + math.sin(a) * s * 0.55, y - math.cos(a) * s * 0.55)
      else
        local dx, dy = bx - ax, by - ay
        local len = math.max(1, math.sqrt(dx * dx + dy * dy))
        g.setLineWidth(style == "needle" and 1.8 or 1.2)
        g.line(x - dx / len * 8, y - dy / len * 8, x + dx / len * 5, y + dy / len * 5)
        if style == "orb" then g.circle("fill", x, y, 3 + (i % 3)) end
      end
    end
  end
end

local function wind(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local p = clamp(self.tick / math.max(1, self.spec.impactAt), 0, 1)
  for i = 0, 6 do
    local q = clamp(p - i * 0.07, 0, 1)
    local x, y = between(ax, ay - 12, bx, by - 12, q, math.sin(self.tick * 0.2 + i) * 5)
    tint(g, self.spec.type, 0.25 + (1 - q) * 0.6)
    g.setLineWidth(1.2)
    g.arc("line", x, y, 5 + i * 1.5, self.tick * 0.11 + i,
      self.tick * 0.11 + i + 4.8, 14)
  end
end

local function sound(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  for i = 0, 7 do
    local age = self.tick - i * 7
    if age >= 0 and age < 48 then
      local p = clamp(age / 38, 0, 1)
      local x, y = between(ax, ay - 15, bx, by - 15, p, 0)
      tint(g, self.spec.type, (1 - age / 48) * 0.78)
      g.setLineWidth(1.4)
      g.arc("line", x, y, 3 + age * 0.22, -1.2, 1.2, 14)
      g.arc("line", x, y, 3 + age * 0.22, math.pi - 1.2, math.pi + 1.2, 14)
    end
  end
end

local function stream(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local grow = clamp(self.tick / math.max(1, self.spec.impactAt * 0.75), 0, 1)
  local fade = clamp((self.spec.impactAt + 26 - self.tick) / 22, 0, 1)
  for i = 1, 22 do
    local p = (i / 22) * grow
    local sway = math.sin(p * 18 - self.tick * 0.35) * (2.5 + (i % 3))
    local x, y = between(ax, ay - 12, bx, by - 12, p, sway)
    tint(g, self.spec.type, fade * (0.35 + (i % 4) * 0.14), 1.08)
    g.circle("fill", x, y - math.sin(p * math.pi) * 4, 2 + (i % 4))
  end
end

local function wave(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local p = clamp(self.tick / math.max(1, self.spec.impactAt), 0, 1)
  local x, y = between(ax, ay, bx, by, p, 0)
  tint(g, self.spec.type, 0.22)
  g.polygon("fill", 0, 144, 160, 144, 160, y + 18,
    x + 35, y + 8, x, y - 7, math.max(0, x - 40), y + 13, 0, y + 21)
  tint(g, self.spec.type, 0.8, 1.2)
  g.setLineWidth(2)
  for i = 0, 3 do
    g.arc("line", x - i * 17, y + i * 3, 16 + i * 3, math.pi, math.pi * 2, 18)
  end
end

local function storm(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  for i = 1, 18 do
    local age = self.tick - (i - 1) * 3
    if age >= 0 and age < 42 then
      local px = x + (hash01(i, self.spec.id or 1, 7) - 0.5) * 62
      local py = y - 58 + age * (1.2 + hash01(i, 9, 3))
      glyph(g, self.spec.type, px, py, 2.5 + i % 4,
        age * 0.13 + i, (1 - age / 42) * 0.85)
    end
  end
end

local function electric(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  local startX, startY = ax, ay - 14
  if self.spec.key == "THUNDER" then startX, startY = bx, 0 end
  local grow = clamp(self.tick / math.max(1, self.spec.impactAt * 0.7), 0, 1)
  local ex, ey = between(startX, startY, bx, by - 13, grow, 0)
  local points = { startX, startY }
  local frame = math.floor(self.tick / 2)
  for i = 1, 8 do
    local p = i / 9 * grow
    local x, y = between(startX, startY, bx, by - 13, p,
      (hash01(i, frame, self.spec.id or 1) - 0.5) * 13)
    points[#points + 1] = x
    points[#points + 1] = y
  end
  points[#points + 1] = ex
  points[#points + 1] = ey
  tint(g, "ELECTRIC", 0.95, 1.2)
  g.setLineWidth(2.2)
  g.line(points)
  for i = 4, #points - 2, 4 do
    local x, y = points[i - 1], points[i]
    g.setLineWidth(1)
    g.line(x, y, x + (hash01(i, frame, 5) - 0.5) * 15, y + 8)
  end
end

local function psychic(self)
  local g = love.graphics
  local x, y = self:anchor(self.spec.anchor or "target")
  for i = 0, 7 do
    local age = self.tick - i * 5
    if age >= 0 and age < 50 then
      tint(g, "PSYCHIC", (1 - age / 50) * 0.76)
      g.setLineWidth(1.5)
      g.ellipse("line", x, y - 13, 5 + age * 0.52,
        3 + age * 0.22 + math.sin(age * 0.25 + i) * 2)
    end
  end
  ScreenFx.fill(g, COLORS.PSYCHIC,
    0.035 + 0.035 * math.sin(self.tick * 0.2), self)
end

local function drain(self)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  for i = 1, 15 do
    local age = self.tick - (i - 1) * 4
    if age >= 0 and age < 48 then
      local p = clamp(age / 38, 0, 1)
      local x, y = between(bx, by - 13, ax, ay - 13, p,
        math.sin(age * 0.24 + i) * 7)
      tint(g, self.spec.type, (1 - age / 48) * 0.8, 1.15)
      g.circle("fill", x, y - math.sin(p * math.pi) * 7, 2 + i % 3)
    end
  end
end

local function ground(self)
  local g = love.graphics
  local x, y = self:anchor("target")
  local pulse = math.max(0, self.tick - math.floor(self.spec.impactAt * 0.35))
  tint(g, "GROUND", clamp((self.spec.duration - self.tick) / 28, 0, 0.9))
  g.setLineWidth(1.8)
  for i = 0, 4 do
    local width = 10 + ((pulse * 2 + i * 13) % 55)
    g.line(x - width, y + i * 3, x - width * 0.35, y - 2 + i * 3,
      x, y + i * 3, x + width * 0.42, y - 3 + i * 3,
      x + width, y + i * 3)
  end
  for i = 1, 9 do
    local age = pulse - i * 3
    if age >= 0 and age < 26 then
      local px = x + (hash01(i, self.spec.id or 1, 3) - 0.5) * 58
      glyph(g, "ROCK", px, y - math.sin(age / 26 * math.pi) * (9 + i),
        2 + i % 3, age, 1 - age / 26)
    end
  end
end

local function barrier(self)
  local g = love.graphics
  local x, y = self:anchor(self.spec.anchor or "attacker")
  local grow = clamp(self.tick / 24, 0, 1)
  local fade = clamp((self.spec.duration - self.tick) / 25, 0, 1)
  tint(g, self.spec.type, fade * 0.22)
  g.circle("fill", x, y - 12, 26 * grow)
  tint(g, self.spec.type, fade * 0.8, 1.18)
  g.setLineWidth(1.6)
  for i = 0, 2 do g.ellipse("line", x, y - 12, (15 + i * 6) * grow, (25 + i * 4) * grow) end
end

local function heal(self)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  for i = 1, 14 do
    local age = (self.tick + i * 9) % 60
    local px = x + math.sin(i * 2.1) * (8 + i % 4 * 3)
    tint(g, self.spec.type, fade * (1 - age / 60), 1.22)
    g.circle("fill", px, y + 12 - age * 0.75, 1.5 + i % 3)
  end
  tint(g, self.spec.type, fade * 0.55)
  g.circle("line", x, y - 12, 9 + (self.tick % 24))
end

local function transform(self)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  for i = 0, 5 do
    local a = self.tick * 0.08 + i * math.pi / 3
    local r = 8 + ((self.tick + i * 7) % 34)
    glyph(g, self.spec.type, x + math.cos(a) * r, y - 12 + math.sin(a) * r * 0.55,
      2.5, -a, fade * 0.76)
  end
  tint(g, self.spec.type, fade * (0.08 + 0.08 * math.sin(self.tick * 0.3)))
  g.circle("fill", x, y - 12, 24)
end

local function explosion(self)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  local age = self.tick
  local peak = clamp(age / 28, 0, 1)
  local fade = clamp((self.spec.duration - age) / 45, 0, 1)
  ScreenFx.fill(g, COLORS.FIRE, fade * 0.30, self)
  ScreenFx.flash(g, age, math.max(0, self.spec.impactAt - 8), 14,
    { 1, 0.94, 0.66 }, 0.40, self)
  for i = 1, 8 do
    local r = peak * (9 + i * 8) + math.sin(age * 0.2 + i) * 3
    tint(g, i % 2 == 0 and "FIRE" or "NORMAL", fade * (0.85 - i * 0.06), 1.2)
    g.setLineWidth(1 + (i % 3))
    g.circle("line", x, y - 12, r)
  end
end

local VISUAL = {
  impact = contact,
  rush = contact,
  slash = slash,
  punch = function(self) strike(self, "punch") end,
  kick = function(self) strike(self, "kick") end,
  bite = bite,
  grapple = grapple,
  needle = function(self) volley(self, "needle") end,
  leaf = function(self) volley(self, "leaf") end,
  orb = function(self) volley(self, "orb") end,
  wind = wind,
  sound = sound,
  stream = stream,
  wave = wave,
  beam = beam,
  storm = storm,
  electric = electric,
  psychic = psychic,
  drain = drain,
  ground = ground,
  status = status,
  barrier = barrier,
  heal = heal,
  transform = transform,
  explosion = explosion,
}

function Renderer.draw(self, Assets)
  local delivery = self.spec.delivery or "projectile"
  if ScreenFx.drawMove(self) then return end
  local draw = VISUAL[self.spec.visual]
  if draw then draw(self)
  elseif delivery == "beam" then beam(self)
  elseif delivery == "projectile" then projectile(self)
  elseif delivery == "contact" then contact(self)
  elseif delivery == "status" then status(self)
  elseif delivery == "screen" then screen(self) end

  sourceTexture(self, Assets)

  if delivery ~= "status" and delivery ~= "screen" then
    for hit = 1, self.spec.hits or 1 do
      impact(self, Assets, self.tick - self.spec.impactAt - (hit - 1) * 10, hit)
    end
  end
end

return Renderer

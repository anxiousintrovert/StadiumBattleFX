-- Complete-roster Stadium-style procedural renderer.
-- Exact source-traced move renderers override this module where available.

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
  tint(g, family, 0.06 + pulse * 0.08)
  g.rectangle("fill", 0, 0, 160, 144)
  tint(g, family, 0.35)
  for i = 1, 7 do
    local r = ((self.tick * 1.4 + i * 19) % 100)
    g.circle("line", 80, 64, r)
  end
end

function Renderer.draw(self, Assets)
  local delivery = self.spec.delivery or "projectile"
  if delivery == "beam" then beam(self)
  elseif delivery == "projectile" then projectile(self)
  elseif delivery == "contact" then contact(self)
  elseif delivery == "status" then status(self)
  elseif delivery == "screen" then screen(self) end

  if delivery ~= "status" and delivery ~= "screen" then
    for hit = 1, self.spec.hits or 1 do
      impact(self, Assets, self.tick - self.spec.impactAt - (hit - 1) * 10, hit)
    end
  end
end

return Renderer

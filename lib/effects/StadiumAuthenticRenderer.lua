-- ROM-textured Stadium 1 renderer for the curated fidelity roster.

local V = ...
local ScreenFx = V.require("effects/StadiumScreenFx")
local Renderer = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function between(ax, ay, bx, by, p, across)
  local dx, dy = bx - ax, by - ay
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.001 then return ax, ay end
  return ax + dx * p - dy / length * (across or 0),
         ay + dy * p + dx / length * (across or 0)
end

local function asset(Assets, name)
  return name and Assets.get(name) or nil
end

local function drawAsset(g, value, frame, x, y, rotation, sx, sy, alpha)
  if not value then return false end
  frame = math.floor(frame or 0) % value.frames + 1
  g.setColor(1, 1, 1, alpha or 1)
  g.draw(value.image, value.quads[frame], x, y, rotation or 0,
    sx or 1, sy or sx or 1, value.frameWidth / 2, value.frameHeight / 2)
  return true
end

local function tinted(g, value, frame, x, y, rotation, scale, color, alpha)
  if not value then return false end
  local c = color or { 1, 1, 1 }
  g.setColor(c[1], c[2], c[3], alpha or 1)
  frame = math.floor(frame or 0) % value.frames + 1
  g.draw(value.image, value.quads[frame], x, y, rotation or 0,
    scale or 1, scale or 1, value.frameWidth / 2, value.frameHeight / 2)
  return true
end

local function tile(g, value, frame, color, alpha, ox, oy, scale, owner)
  return ScreenFx.tile(g, value, frame, {
    color = color, alpha = alpha, x = ox, y = oy, scale = scale,
    owner = owner,
  })
end

local function impact(self, Assets, color, scale)
  local age = self.tick - self.spec.impactAt
  if age < 0 or age >= 28 then return end
  local g = love.graphics
  local x, y = self:anchor("target")
  local fade = 1 - age / 28
  tinted(g, asset(Assets, "beam_impact"), age / 3, x, y - 12,
    age * 0.08, (scale or 0.55) + age * 0.008, color, fade)
  tinted(g, asset(Assets, "large_burst"), age / 4, x, y - 12,
    -age * 0.045, (scale or 0.4) + age * 0.005, color, fade * 0.72)
end

local function stream(self, Assets, names, color, reverse, width)
  local g = love.graphics
  local ax, ay = self:anchor(reverse and "target" or "attacker")
  local bx, by = self:anchor(reverse and "attacker" or "target")
  local travel = math.max(1, self.spec.impactAt)
  local lead = clamp(self.tick / travel, 0, 1)
  for i = 1, 18 do
    local delay = (i - 1) * 2
    local p = clamp((self.tick - delay) / math.max(1, travel - delay * 0.35), 0, lead)
    if self.tick >= delay and p < 1.04 then
      local sway = math.sin(self.tick * 0.22 + i * 1.7) * (width or 5)
      local x, y = between(ax, ay - 13, bx, by - 13, p, sway)
      local value = asset(Assets, names[(i - 1) % #names + 1])
      tinted(g, value, self.tick / 3 + i, x, y - math.sin(p * math.pi) * 5,
        self.tick * 0.06 + i, 0.28 + (i % 4) * 0.055, color, 0.78)
    end
  end
end

local function fire(self, Assets)
  local variant = self.spec.variant
  local color = variant == "ember" and { 1, 0.48, 0.08 } or { 1, 0.22, 0.03 }
  stream(self, Assets, { "energy_orb", "energy_core", "energy_column" },
    color, false, variant == "blast" and 10 or 6)
  local g = love.graphics
  local x, y = self:anchor("target")
  if variant == "blast" and self.tick >= self.spec.impactAt - 16 then
    for i = 0, 4 do
      local a = i * math.pi * 0.4 - math.pi * 0.5
      tinted(g, asset(Assets, "energy_column"), self.tick / 3 + i,
        x + math.cos(a) * 18, y - 12 + math.sin(a) * 18, a,
        0.38 + i * 0.025, { 1, 0.32 + i * 0.05, 0.04 }, 0.86)
    end
  end
  impact(self, Assets, color, variant == "ember" and 0.34 or 0.66)
end

local function water(self, Assets)
  local variant = self.spec.variant
  if variant == "surf" then
    local g = love.graphics
    local cycle = asset(Assets, "water_cycle")
    local rise = clamp(self.tick / 42, 0, 1)
    ScreenFx.region(g, { 0.12, 0.50, 0.96 }, 0.16 + rise * 0.18,
      0, 144 - rise * 82, 160, rise * 82, self)
    tile(g, cycle, self.tick / 4, { 0.35, 0.76, 1 }, 0.38,
      -self.tick * 0.8, self.tick * 0.25, 1.1, self)
  else
    stream(self, Assets, { "beam_core", "beam_spark", "water_cycle" },
      { 0.20, 0.68, 1 }, false, variant == "pump" and 9 or 4)
  end
  impact(self, Assets, { 0.30, 0.76, 1 }, variant == "pump" and 0.72 or 0.46)
end

local function spectrumBeam(self, Assets)
  local variant = self.spec.variant
  local colors = {
    psybeam = { 0.92, 0.28, 1 }, hyper = { 1, 0.78, 0.22 },
    solar = { 0.54, 1, 0.34 }, beam = { 0.56, 0.94, 1 },
  }
  local color = colors[variant] or { 0.8, 0.8, 1 }
  stream(self, Assets, { "spectrum_cycle", "beam_core", "spectrum_glint" },
    color, false, variant == "hyper" and 4 or 2)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  if variant == "solar" and self.tick < 36 then
    for i = 1, 8 do
      local a = i * math.pi / 4 + self.tick * 0.035
      tinted(g, asset(Assets, "heal_star_a"), i, ax + math.cos(a) * (22 - self.tick * 0.3),
        ay - 13 + math.sin(a) * (13 - self.tick * 0.12), -a, 0.32,
        { 0.72, 1, 0.48 }, 0.82)
    end
  end
  impact(self, Assets, color, variant == "hyper" and 0.82 or 0.58)
end

local function ice(self, Assets)
  local g = love.graphics
  if self.spec.variant == "storm" then
    local fieldFade = ScreenFx.envelope(self.tick, self.spec.duration, 16, 26)
    ScreenFx.fill(g, { 0.58, 0.78, 0.92 }, 0.08 * fieldFade, self)
    tile(g, asset(Assets, "screen_grain"), self.tick / 6,
      { 0.72, 0.92, 1 }, 0.13 * fieldFade,
      -self.tick * 0.55, self.tick * 0.85, 1, self)
    ScreenFx.flash(g, self.tick, self.spec.impactAt - 4, 10,
      { 0.86, 0.98, 1 }, 0.26, self)
    local x, y = self:anchor("target")
    for i = 1, 24 do
      local age = self.tick - (i - 1) * 2
      if age >= 0 and age < 48 then
        local px = x + math.sin(i * 12.9898) * 38
        local py = y - 62 + age * (1.1 + (i % 4) * 0.16)
        local flake = asset(Assets, i % 3 == 0 and "beam_star" or "spectrum_cycle")
        if flake then
          tinted(g, flake, age / 3 + i, px, py, age * 0.08,
            0.22 + i % 3 * 0.06, { 0.62, 0.96, 1 }, 1 - age / 48)
        else
          -- Keep the defining Blizzard motion visible if the optional ROM
          -- texture cache is incomplete. Overlay assets must never erase the
          -- core snow field.
          g.setColor(0.72, 0.94, 1, 1 - age / 48)
          local size = 1 + (i % 3) * 0.6
          g.line(px - size, py, px + size, py)
          g.line(px, py - size, px, py + size)
        end
      end
    end
  else
    spectrumBeam(self, Assets)
  end
  impact(self, Assets, { 0.60, 0.96, 1 }, 0.62)
end

local function leaf(self, Assets)
  local g = love.graphics
  local ax, ay = self:anchor("attacker")
  local bx, by = self:anchor("target")
  for i = 1, 14 do
    local age = self.tick - (i - 1) * 3
    if age >= 0 and age <= self.spec.impactAt + 6 then
      local p = clamp(age / math.max(1, self.spec.impactAt - i), 0, 1)
      local x, y = between(ax, ay - 13, bx, by - 13, p, math.sin(i * 2.2) * 8)
      local name = i % 5 == 0 and "leaf_gold" or "leaf_green"
      drawAsset(g, asset(Assets, name), 0, x, y - math.sin(p * math.pi) * 9,
        age * 0.18 + i, 0.30 + i % 3 * 0.04, nil, 0.92)
      tinted(g, asset(Assets, "leaf_spin"), age / 3, x, y,
        -age * 0.12, 0.24, { 0.48, 1, 0.35 }, 0.55)
    end
  end
  impact(self, Assets, { 0.42, 0.94, 0.30 }, 0.50)
end

local function electric(self, Assets)
  local g = love.graphics
  local bx, by = self:anchor("target")
  local fromX, fromY = self:anchor("attacker")
  -- Thunderbolt is a target-locked lightning strike. In a dramatic shot the
  -- attacker can be intentionally framed outside the animation layer, so a
  -- cross-screen source can bend the visible bolt toward the lower edge.
  -- Give both electric strikes a target-local origin to keep their endpoint
  -- nailed to the defending Pokemon.
  if self.spec.variant == "thunder" or self.spec.variant == "bolt" then
    fromX, fromY = bx, -8
  end
  local grow = clamp(self.tick / math.max(1, self.spec.impactAt * 0.72), 0, 1)
  for band = -2, 2 do
    local pts = { fromX, fromY - 12 }
    for i = 1, 7 do
      local p = i / 8 * grow
      local x, y = between(fromX, fromY - 12, bx, by - 13, p,
        math.sin(i * 8.7 + self.tick * 0.55 + band) * (5 + math.abs(band)))
      pts[#pts + 1], pts[#pts + 1] = x, y
    end
    pts[#pts + 1], pts[#pts + 1] = between(fromX, fromY - 12, bx, by - 13, grow, 0)
    g.setColor(1, band == 0 and 1 or 0.78, 0.08, band == 0 and 0.95 or 0.42)
    g.setLineWidth(band == 0 and 2.2 or 1)
    g.line(pts)
  end
  tinted(g, asset(Assets, "thunder_orb"), self.tick / 3, bx, by - 13,
    self.tick * 0.04, self.spec.variant == "thunder" and 0.72 or 0.48,
    { 1, 0.90, 0.10 }, 0.88)
  impact(self, Assets, { 1, 0.88, 0.08 }, 0.58)
end

local function drain(self, Assets)
  stream(self, Assets, { "energy_core", "energy_orb", "heal_star_a" },
    { 0.48, 1, 0.36 }, true, self.spec.variant == "mega" and 10 or 6)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  if self.tick > self.spec.impactAt then
    tinted(g, asset(Assets, "heal_ring"), self.tick / 3, x, y - 13,
      0, self.spec.variant == "mega" and 0.62 or 0.42,
      { 0.52, 1, 0.42 }, clamp((self.spec.duration - self.tick) / 24, 0, 0.9))
  end
end

local function psychic(self, Assets)
  local g = love.graphics
  local x, y = self:anchor("target")
  local fade = clamp((self.spec.duration - self.tick) / 26, 0, 1)
  ScreenFx.fill(g, { 0.62, 0.08, 0.82 },
    (0.05 + 0.04 * math.sin(self.tick * 0.22)) * fade, self)
  for i = 0, 7 do
    local age = self.tick - i * 5
    if age >= 0 and age < 52 then
      tinted(g, asset(Assets, self.spec.variant == "confuse" and "spectrum_cycle" or "screen_pulse"),
        age / 3 + i, x, y - 13, i + age * 0.05,
        0.28 + age * 0.016, { 0.92, 0.32, 1 }, (1 - age / 52) * fade)
    end
  end
  impact(self, Assets, { 0.94, 0.30, 1 }, 0.62)
end

local function poison(self, Assets)
  local g = love.graphics
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  tile(g, asset(Assets, "poison_field"), 0, { 0.66, 0.15, 0.82 },
    0.10 * fade, self.tick * 0.3, -self.tick * 0.2, 1, self)
  local x, y = self:anchor("target")
  for i = 1, 12 do
    local age = (self.tick + i * 9) % 58
    tinted(g, asset(Assets, "beam_core"), age / 4, x + math.sin(i * 3.1) * 24,
      y + 8 - age * 0.8, age * 0.07, 0.22 + i % 3 * 0.05,
      { 0.76, 0.20, 0.92 }, (1 - age / 58) * fade)
  end
end

local function heal(self, Assets)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  tinted(g, asset(Assets, "heal_ring"), self.tick / 3, x, y - 13, 0,
    0.62, { 0.58, 1, 0.78 }, fade)
  for i = 1, 10 do
    local age = (self.tick + i * 8) % 56
    local name = i % 2 == 0 and "heal_star_a" or "heal_star_b"
    tinted(g, asset(Assets, name), 0, x + math.sin(i * 2.3) * 24,
      y + 14 - age * 0.9, -age * 0.08, 0.27,
      { 0.76, 1, 0.82 }, (1 - age / 56) * fade)
  end
end

local function barrier(self, Assets)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  local color = self.spec.variant == "reflect" and { 0.88, 0.54, 1 }
    or { 0.52, 0.90, 1 }
  local grow = clamp(self.tick / 22, 0, 1)
  local fade = clamp((self.spec.duration - self.tick) / 24, 0, 1)
  tile(g, asset(Assets, "screen_dual"), self.tick / 8, color,
    0.035 * fade, self.tick * 0.18, 0, 1, self)
  for i = 0, 3 do
    tinted(g, asset(Assets, "screen_pulse"), self.tick / 3 + i,
      x, y - 13, i * math.pi / 2, (0.34 + i * 0.12) * grow,
      color, fade * (0.72 - i * 0.1))
  end
end

local function ground(self, Assets)
  local g = love.graphics
  local age = math.max(0, self.tick - 12)
  tile(g, asset(Assets, "screen_grain"), 0, { 0.62, 0.40, 0.16 },
    clamp(age / 60, 0, 0.14), age * 1.7, 0, 1, self)
  local x, y = self:anchor("target")
  g.setColor(0.54, 0.34, 0.12, 0.82)
  g.setLineWidth(1.8)
  for i = 0, 5 do
    local spread = ((age * 2.3 + i * 19) % 76)
    g.line(x - spread, y + i * 2, x - spread * 0.28, y - 3 + i * 2,
      x, y + i * 2, x + spread * 0.34, y - 2 + i * 2, x + spread, y + i * 2)
  end
  impact(self, Assets, { 0.74, 0.48, 0.18 }, 0.70)
end

local function explosion(self, Assets)
  local g = love.graphics
  local x, y = self:anchor("attacker")
  local age = self.tick
  local grow = clamp(age / 34, 0, 1)
  local fade = clamp((self.spec.duration - age) / 42, 0, 1)
  ScreenFx.fill(g, { 1, 0.36, 0.04 }, fade * 0.24, self)
  ScreenFx.flash(g, age, math.max(0, self.spec.impactAt - 8), 14,
    { 1, 0.92, 0.55 }, 0.46, self)
  for i = 0, 7 do
    tinted(g, asset(Assets, i % 2 == 0 and "large_burst" or "screen_pulse"),
      age / 3 + i, x + math.cos(i * math.pi / 4) * grow * 25,
      y - 13 + math.sin(i * math.pi / 4) * grow * 20,
      i + age * 0.035, (0.34 + i * 0.11) * grow,
      i % 2 == 0 and { 1, 0.28, 0.02 } or { 1, 0.82, 0.20 },
      fade * (0.94 - i * 0.07))
  end
end

local PROGRAM = {
  fire = fire, water = water, beam = spectrumBeam, ice = ice,
  leaf = leaf, electric = electric, drain = drain, psychic = psychic,
  poison = poison, heal = heal, barrier = barrier, ground = ground,
  explosion = explosion,
}

function Renderer.draw(self, Assets)
  local draw = self.spec and PROGRAM[self.spec.stadiumProgram]
  if not draw then return false end
  draw(self, Assets)
  return true
end

return Renderer

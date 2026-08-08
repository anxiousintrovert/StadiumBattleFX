-- Move-84-only adapter around Gen1Recomp's AnimPlayer.
-- All non-Thunder-Shock calls delegate without alteration.

local V = ...
local spec = V.require("effects/ThunderShockSpec")
local Texture = V.require("StadiumTexture")

local Player = {}
Player.__index = Player

local IMPACT_AT = 44
local COMPLETE_AT = 100
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

local function isThunderShock(moveId)
  return moveId == "THUNDERSHOCK" or moveId == 84 or moveId == "84"
end

function Player.new(inner, options, logger)
  return setmetatable({ inner = inner, options = options, logger = logger,
    custom = false, tick = 0, particles = {}, emitted = {}, warned = false,
    drawWarned = false }, Player)
end

function Player:warn(reason)
  if self.warned then return end
  self.warned = true
  if self.logger and self.logger.warn then
    self.logger:warn("Thunder Shock falls back to Gen1 animation: %s", tostring(reason))
  end
end

function Player:start(moveId, attackerIsPlayer, opts)
  self.custom = false
  if not isThunderShock(moveId) or not self.options() then
    return call(self.inner, "start", moveId, attackerIsPlayer, opts)
  end
  local asset, err = Texture.get()
  if not asset then
    self:warn(err or "Stadium texture unavailable")
    return call(self.inner, "start", moveId, attackerIsPlayer, opts)
  end

  -- Compile the original animation too, but use it only as an audio event
  -- clock. Its sprites and screen/picture effects are not drawn/applied.
  call(self.inner, "start", moveId, attackerIsPlayer, opts)
  self.custom = true
  self.asset = asset
  self.attackerIsPlayer = attackerIsPlayer and true or false
  self.tick, self.particles, self.emitted = 0, {}, {}
  self:runSchedules("primary", 0)
end

function Player:anchor(stage)
  local attacker = self.attackerIsPlayer and ANCHOR.player or ANCHOR.enemy
  local target = self.attackerIsPlayer and ANCHOR.enemy or ANCHOR.player
  local p = stage == "primary" and attacker or target
  return p[1], p[2]
end

function Player:spawn(stage, scheduleIndex, burstIndex, born)
  local schedule = spec[stage].schedules[scheduleIndex]
  local seed = scheduleIndex * 31 + burstIndex * 17 + (stage == "impact" and 97 or 0)
  local spread = stage == "impact" and 22 or 16
  local x = (hash01(seed, 1, 7) - 0.5) * spread
  local y = (hash01(seed, 2, 11) - 0.5) * 9
  local angle = (hash01(seed, 3, 13) - 0.5) * 0.42
  if schedule.callback == "func_8433D070" then angle = angle - 0.34 end
  if schedule.callback == "func_8433D224" then angle = angle + 0.34 end
  if schedule.callback == "func_8433D560" then y = y - 12 end
  local width = ({ [0x14] = 32, [0x13] = 16, [0x12] = 32, [0x0F] = 8 })[schedule.preset] or 16
  self.particles[#self.particles + 1] = {
    stage = stage, born = born, width = width, life = 20,
    x = x, y = y, angle = angle, callback = schedule.callback,
  }
end

function Player:runSchedules(stage, localTick)
  for si, schedule in ipairs(spec[stage].schedules) do
    for bi = 0, schedule.bursts - 1 do
      local at = schedule.at + schedule.interval * bi
      local key = stage .. ":" .. si .. ":" .. bi
      if localTick == at and not self.emitted[key] then
        self.emitted[key] = true
        self:spawn(stage, si, bi, self.tick)
      end
    end
  end
end

function Player:update()
  if not self.custom then return call(self.inner, "update") end
  self.tick = self.tick + 1
  if self.inner and not call(self.inner, "isDone") then call(self.inner, "update") end
  self:runSchedules("primary", self.tick)
  if self.tick >= IMPACT_AT then self:runSchedules("impact", self.tick - IMPACT_AT) end
  for i = #self.particles, 1, -1 do
    if self.tick - self.particles[i].born >= self.particles[i].life then
      table.remove(self.particles, i)
    end
  end
end

function Player:isDone()
  if self.custom then return self.tick >= COMPLETE_AT end
  return call(self.inner, "isDone") ~= false
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

local function drawCustom(self)
  local g = love and love.graphics
  if not (g and self.asset) then return end
  local oldMode, oldAlpha = g.getBlendMode()
  -- Dramaless Shape renders the battle UI over a transparent canvas. An
  -- additive-only draw colors the RGB channels there without establishing
  -- usable coverage for the later canvas composite, so it disappears even
  -- though the particles were drawn. Ordinary alpha preserves that coverage
  -- and remains correct on Gen1Recomp's opaque classic battle field.
  g.setBlendMode("alpha", "alphamultiply")
  for _, particle in ipairs(self.particles) do
    local age = self.tick - particle.born
    local frame = age % self.asset.frames + 1
    local ax, ay = self:anchor(particle.stage)
    local fade = math.max(0, 1 - age / particle.life)
    local sx = (particle.width / self.asset.frameWidth) * 0.45
    local sy = 0.45
    local lift = particle.callback == "func_8433D560" and age * 0.25 or 0
    g.setColor(1, 0.92, 0.22, fade)
    g.draw(self.asset.image, self.asset.quads[frame],
      ax + particle.x, ay - 22 + particle.y - lift,
      particle.angle, sx, sy,
      self.asset.frameWidth / 2, self.asset.frameHeight / 2)
  end
  g.setColor(1, 1, 1, 1)
  g.setBlendMode(oldMode or "alpha", oldAlpha)
end

function Player:draw(...)
  if not self.custom then return call(self.inner, "draw", ...) end
  local ok, err = pcall(drawCustom, self)
  if ok then return end
  if not self.drawWarned then
    self.drawWarned = true
    if self.logger and self.logger.warn then
      self.logger:warn("Thunder Shock draw failed; using Gen1 renderer: %s",
        tostring(err))
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
  self.custom, self.particles = false, {}
  return call(self.inner, "release")
end

return Player

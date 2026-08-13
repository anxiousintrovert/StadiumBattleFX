-- One-time, first-run screen for building the local Stadium attack cache.
-- It is an ordinary opaque Gen1Recomp state: gameplay beneath it pauses,
-- while StadiumAssets advances one concrete extraction step per tick.

local V = ...
local Assets = V.require("StadiumAssets")
local ArenaAssets = V.require("StadiumArenaAssets")
local TrainerPortraits = V.require("StadiumTrainerPortraits")
local ModelInstall = V.require("StadiumInstall")
local Announcer = V.require("Announcer")

local Screen = {}
Screen.__index = Screen
Screen.isOpaque = true
Screen.HOLD = 0.9

local W, H = 160, 144
local Font

local function font()
  if Font then return Font end
  local ok, value = pcall(require, "src.render.Font")
  if ok then Font = value end
  return Font
end

local function text(value, x, y)
  local f = font()
  if not f then return end
  love.graphics.setColor(0.04, 0.05, 0.10, 1)
  f.draw(tostring(value), math.floor(x), math.floor(y))
end

local function centred(value, y)
  local f = font()
  if not f then return end
  value = tostring(value)
  text(value, (W - f.width(value)) / 2, y)
end

local function short(value)
  value = tostring(value or "WORKING"):gsub("_", " ")
  if #value > 20 then value = value:sub(1, 20) end
  return value
end

local function wrapped(value, limit)
  local lines, line = {}, nil
  for word in tostring(value or "unknown error"):gmatch("%S+") do
    local joined = line and (line .. " " .. word) or word
    if #joined <= 20 then
      line = joined
    else
      if line and #lines < limit then lines[#lines + 1] = line end
      line = word:sub(1, 20)
    end
    if #lines >= limit then break end
  end
  if line and #lines < limit then lines[#lines + 1] = line end
  return lines
end

function Screen.new(game, refresh)
  return setmetatable({ game = game, hold = 0, refresh = refresh and true or false }, Screen)
end

function Screen:enter()
  V.log:event("cache", "sequence-started", { refresh = self.refresh })
  local ok, err
  if self.refresh then ok, err = Assets.refresh()
  else ok, err = Assets.begin() end
  if not ok then
    self.startError = tostring(err or "could not start cache")
    V.log:error("[cache] attack cache start failed: %s", self.startError)
  end
end

function Screen:activeStatus()
  local effects = Assets.status()
  if effects.state == "building" or effects.state == "failed" then return effects end
  local arenas = ArenaAssets.status()
  if arenas.state == "building" or arenas.state == "failed" then return arenas end
  local trainers = TrainerPortraits.status()
  if trainers.state == "building" or trainers.state == "failed" then return trainers end
  if not self.trainerStarted then return trainers end
  if not self.modelStarted then return arenas end
  if ModelInstall.status.state == "building" or ModelInstall.status.state == "failed" then
    return ModelInstall.status
  end
  if self.voiceStarted then return Announcer.cacheStatus() end
  return ModelInstall.status
end

local function pop(self)
  local stack = self.game and self.game.stack
  if stack and stack:top() == self then stack:pop() end
end

function Screen:update(dt)
  local status = Assets.status()
  if status.state == "building" then
    Assets.step()
    self.hold = 0
    return
  end
  if status.state ~= "failed" and not self.arenaStarted then
    self.arenaStarted = true
    local ok, err
    if self.refresh then ok, err = ArenaAssets.refresh()
    else ok, err = ArenaAssets.begin() end
    if not ok then self.startError = tostring(err or "could not start arena cache") end
    V.log:event("cache", "arena-stage-started", { accepted = ok and true or false })
  end
  local arenaStatus = ArenaAssets.status()
  if arenaStatus.state == "building" then
    ArenaAssets.step()
    self.hold = 0
    return
  end
  if arenaStatus.state ~= "failed" and not self.trainerStarted then
    self.trainerStarted = true
    local shouldBuild = self.refresh or TrainerPortraits.pending()
    if shouldBuild then
      local ok, err = TrainerPortraits.begin()
      if not ok then self.startError = tostring(err or "could not start trainer cache") end
      V.log:event("cache", "trainer-stage-started", { accepted = ok and true or false })
    end
  end
  if TrainerPortraits.status().state == "building" then
    TrainerPortraits.step()
    self.hold = 0
    return
  end
  if TrainerPortraits.status().state ~= "failed" and not self.modelStarted then
    self.modelStarted = true
    local shouldBuild = self.refresh or ModelInstall.pending()
    if shouldBuild then
      local ok, err = ModelInstall.begin()
      if not ok then self.startError = tostring(err or "could not start model cache") end
      V.log:event("cache", "model-stage-started", {
        accepted = ok and true or false,
        refresh = self.refresh,
      })
    end
  end
  if ModelInstall.status.state == "building" then
    ModelInstall.step()
    self.hold = 0
    return
  end
  if ModelInstall.status.state ~= "failed" and not self.voiceStarted then
    self.voiceStarted = true
    if Announcer.cachePending() then
      local ok, err = Announcer.beginCache(self.refresh)
      if not ok then self.startError = tostring(err or "could not start voice cache") end
      V.log:event("cache", "voice-stage-started", { accepted = ok and true or false })
    end
  end
  local voiceStatus = Announcer.cacheStatus()
  if voiceStatus.state == "building" then
    Announcer.stepCache()
    self.hold = 0
    return
  end
  status = self:activeStatus()
  self.hold = self.hold + (tonumber(dt) or 1 / 60)
  local wait = (status.state == "failed" or self.startError)
    and Screen.HOLD * 4 or Screen.HOLD
  if self.hold >= wait then
    V.log:event("cache", "sequence-finished", {
      state = (status.state == "failed" or self.startError) and "failed" or "ready",
      effects = Assets.status().state,
      arenas = ArenaAssets.status().state,
      models = ModelInstall.status.state,
      voices = Announcer.cacheStatus().state,
    })
    pop(self)
  end
end

function Screen:onKeyPressed(key)
  if key == "escape" or key == "backspace" then
    Assets.cancel()
    ArenaAssets.cancel()
    TrainerPortraits.cancel()
    ModelInstall.cancel()
    Announcer.cancelCache()
    V.log:event("cache", "sequence-cancelled")
    pop(self)
    return true
  end
  return false
end

function Screen:draw()
  local status = self:activeStatus()
  love.graphics.setColor(0.93, 0.95, 0.98, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  centred("STADIUM ATTACK FX", 14)
  local failed = status.state == "failed" or self.startError
  if failed then
    centred("CACHE FAILED", 52)
    for i, line in ipairs(wrapped(self.startError or status.error, 3)) do
      centred(line, 70 + (i - 1) * 10)
    end
    centred("VANILLA FX ENABLED", 114)
    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  centred("BUILDING CACHE", 28)
  local done, total = status.done or 0, status.total or 1
  local frac = total > 0 and done / total or 1
  if status.state == "done" then frac = 1 end
  frac = math.max(0, math.min(1, frac))

  local bx, by, bw, bh = 22, 44, W - 44, 9
  love.graphics.setColor(0.04, 0.05, 0.10, 1)
  love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2)
  love.graphics.setColor(0.93, 0.95, 0.98, 1)
  love.graphics.rectangle("fill", bx, by, bw, bh)
  love.graphics.setColor(0.15, 0.31, 0.66, 1)
  love.graphics.rectangle("fill", bx, by, math.floor(bw * frac + 0.5), bh)

  if status.state == "done" then
    centred("READY", 59)
  else
    centred(("%d/%d"):format(done, total), 59)
    centred(short(status.current), 71)
  end
  local function row(label, value, y)
    text(label, 10, y)
    text(value, 88, y)
  end
  local function labelStatus(s, applicable)
    if not applicable then return "NOT FOUND" end
    if s.ready or s.state == "done" then return "READY" end
    if s.state == "building" then return "BUILDING" end
    if s.state == "failed" then return "FAILED" end
    return "WAITING"
  end
  local effects, arenas = Assets.status(), ArenaAssets.status()
  local models = ModelInstall.status
  models.ready = ModelInstall.ready()
  row("ATTACK FX", labelStatus(effects, true), 83)
  row("ARENAS", labelStatus(arenas, true), 94)
  row("TRAINERS", labelStatus(TrainerPortraits.status(), true), 105)
  row("MODELS", labelStatus(models, true), 116)
  local voice = Announcer.cacheStatus()
  row("ANNOUNCER", labelStatus(voice, voice.installed), 127)
  love.graphics.setColor(1, 1, 1, 1)
end

local asked = false

function Screen.maybePush(game)
  if asked or not (game and game.stack and game.overworld) then return false end
  if game.stack:top() ~= game.overworld then return false end
  asked = true
  if not Assets.pending() and not ArenaAssets.pending() and not TrainerPortraits.pending()
      and not ModelInstall.pending()
      and not Announcer.cachePending() then
    return false
  end
  game.stack:push(Screen.new(game))
  return true
end

function Screen._reset()
  asked = false
end

return Screen

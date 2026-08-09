-- One-time, first-run screen for building the private Stadium attack cache.
-- It is an ordinary opaque Gen1Recomp state: gameplay beneath it pauses,
-- while StadiumAssets advances one concrete extraction step per tick.

local V = ...
local Assets = V.require("StadiumAssets")

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
  local ok, err
  if self.refresh then ok, err = Assets.refresh()
  else ok, err = Assets.begin() end
  if not ok then
    self.startError = tostring(err or "could not start cache")
  end
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
  self.hold = self.hold + (tonumber(dt) or 1 / 60)
  local wait = (status.state == "failed" or self.startError)
    and Screen.HOLD * 4 or Screen.HOLD
  if self.hold >= wait then pop(self) end
end

function Screen:onKeyPressed(key)
  if key == "escape" or key == "backspace" then
    Assets.cancel()
    pop(self)
    return true
  end
  return false
end

function Screen:draw()
  local status = Assets.status()
  love.graphics.setColor(0.93, 0.95, 0.98, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)

  centred("STADIUM ATTACK FX", 24)
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

  centred("CACHING ATTACK FX", 45)
  local done, total = status.done or 0, status.total or 1
  local frac = total > 0 and done / total or 1
  if status.state == "done" then frac = 1 end
  frac = math.max(0, math.min(1, frac))

  local bx, by, bw, bh = 22, 66, W - 44, 9
  love.graphics.setColor(0.04, 0.05, 0.10, 1)
  love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2)
  love.graphics.setColor(0.93, 0.95, 0.98, 1)
  love.graphics.rectangle("fill", bx, by, bw, bh)
  love.graphics.setColor(0.15, 0.31, 0.66, 1)
  love.graphics.rectangle("fill", bx, by, math.floor(bw * frac + 0.5), bh)

  if status.state == "done" then
    centred("READY", 84)
  else
    centred(("%d/%d"):format(done, total), 84)
    centred(short(status.current), 98)
  end
  centred("FIRST RUN ONLY", 118)
  love.graphics.setColor(1, 1, 1, 1)
end

local asked = false

local function dramaticShapesBusy()
  local ds = V.mod.find("DRAMALESS_SHAPE")
  local lib = ds and ds.exports and ds.exports.lib
  if not (lib and type(lib.require) == "function") then return false end
  local ok, install = pcall(lib.require, "StadiumInstall")
  if not (ok and install) then return false end
  if install.status and install.status.state == "building" then return true end
  local pending = type(install.pending) == "function" and install.pending()
  return pending and true or false
end

function Screen.maybePush(game)
  if asked or not (game and game.stack and game.overworld) then return false end
  if game.stack:top() ~= game.overworld then return false end
  -- DS gets first use of the shared player-supplied ROM. This reads only its
  -- exported install state and lets its own screen finish before ours opens.
  if dramaticShapesBusy() then return false end
  asked = true
  if not Assets.pending() then return false end
  game.stack:push(Screen.new(game))
  return true
end

function Screen._reset()
  asked = false
end

return Screen

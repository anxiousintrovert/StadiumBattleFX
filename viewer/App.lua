local spec = require("lib.effects.ThunderShockSpec")
local RuntimeTexture = require("lib.StadiumTexture")

local TICK = 1 / spec.stadiumTickRate
local ATLAS = "cache/dev/thunder_shock/electric_i4_atlas.png"

local app = {
  tick = 0,
  accumulator = 0,
  running = true,
  stage = "primary",
  particles = {},
  emitted = {},
  atlas = nil,
  quads = {},
  error = nil,
}

local function stageSpec()
  return spec[app.stage]
end

local function hash01(a, b, c)
  local n = (a * 73856093 + b * 19349663 + c * 83492791) % 104729
  return n / 104729
end

local function anchorPosition()
  local w, h = love.graphics.getDimensions()
  if app.stage == "primary" then return w * 0.29, h * 0.61 end
  return w * 0.71, h * 0.65
end

local function profileFor(preset)
  if preset == 0x14 then return 32, 32 end
  if preset == 0x13 then return 16, 28 end
  if preset == 0x12 then return 32, 34 end
  return 8, 24
end

local function spawn(scheduleIndex, burstIndex)
  local schedule = stageSpec().schedules[scheduleIndex]
  local width, life = profileFor(schedule.preset)
  local seed = scheduleIndex * 31 + burstIndex * 17
  local spread = app.stage == "impact" and 66 or 48
  local x = (hash01(seed, 1, 7) - 0.5) * spread
  local y = (hash01(seed, 2, 11) - 0.5) * 22
  local angle = (hash01(seed, 3, 13) - 0.5) * 0.42

  if schedule.callback == "func_8433D070" then angle = angle - 0.34 end
  if schedule.callback == "func_8433D224" then angle = angle + 0.34 end
  if schedule.callback == "func_8433D560" then y = y - 36 end

  app.particles[#app.particles + 1] = {
    born = app.tick,
    width = width,
    life = life,
    x = x,
    y = y,
    angle = angle,
    callback = schedule.callback,
  }
end

local function runSchedules()
  for si, schedule in ipairs(stageSpec().schedules) do
    for bi = 0, schedule.bursts - 1 do
      local at = schedule.at + schedule.interval * bi
      local key = si .. ":" .. bi
      if app.tick == at and not app.emitted[key] then
        app.emitted[key] = true
        spawn(si, bi)
      end
    end
  end
end

local function reset()
  app.tick = 0
  app.accumulator = 0
  app.particles = {}
  app.emitted = {}
  runSchedules()
end

local function step()
  app.tick = app.tick + 1
  runSchedules()
  for i = #app.particles, 1, -1 do
    if app.tick - app.particles[i].born >= app.particles[i].life then
      table.remove(app.particles, i)
    end
  end
  if app.tick > 110 then reset() end
end

local function loadAtlas()
  local runtimeAsset, runtimeErr = RuntimeTexture.get()
  if runtimeAsset then
    app.atlas = runtimeAsset.image
    app.quads = runtimeAsset.quads
    print("runtime Stadium texture: " .. tostring(runtimeAsset.path))
    return
  end
  if not love.filesystem.getInfo(ATLAS, "file") then
    app.error = "No usable Stadium ROM in baseroms/ (" .. tostring(runtimeErr)
      .. ").\nRun the Python developer extractor or add your US 1.0 ROM."
    return
  end
  local ok, image = pcall(love.graphics.newImage, ATLAS)
  if not ok then app.error = tostring(image); return end
  image:setFilter("linear", "linear")
  app.atlas = image
  for frame = 0, spec.texture.frameCount - 1 do
    app.quads[frame + 1] = love.graphics.newQuad(
      frame * spec.texture.frameWidth, 0,
      spec.texture.frameWidth, spec.texture.frameHeight,
      image:getDimensions())
  end
end

local function drawCombatant(x, y, facing)
  local g = love.graphics
  g.setColor(0.14, 0.16, 0.21, 1)
  g.ellipse("fill", x, y - 42, 42, 56)
  g.circle("fill", x + facing * 20, y - 91, 29)
  g.setColor(0.27, 0.30, 0.37, 1)
  g.ellipse("line", x, y - 42, 42, 56)
  g.circle("line", x + facing * 20, y - 91, 29)
end

local function drawParticle(p)
  local age = app.tick - p.born
  local frame = (age % spec.texture.frameCount) + 1
  local ax, ay = anchorPosition()
  local fade = 1 - age / p.life
  local scaleX = p.width / spec.texture.frameWidth
  local lift = p.callback == "func_8433D560" and age * 0.8 or 0
  love.graphics.setColor(1, 0.93, 0.30, math.max(0, fade))
  love.graphics.draw(
    app.atlas, app.quads[frame], ax + p.x, ay + p.y - lift,
    p.angle, scaleX, 0.72, spec.texture.frameWidth / 2,
    spec.texture.frameHeight / 2)
end

local function drawTimeline(w, h)
  local g = love.graphics
  local left, right, y = 54, w - 54, h - 58
  g.setColor(0.18, 0.20, 0.26, 1)
  g.rectangle("fill", left, y, right - left, 4)
  for _, schedule in ipairs(stageSpec().schedules) do
    for burst = 0, schedule.bursts - 1 do
      local at = schedule.at + schedule.interval * burst
      local x = left + (right - left) * at / 110
      g.setColor(0.95, 0.78, 0.18, 1)
      g.circle("fill", x, y + 2, 3)
    end
  end
  local cursor = left + (right - left) * math.min(app.tick, 110) / 110
  g.setColor(1, 1, 1, 1)
  g.rectangle("fill", cursor - 1, y - 8, 2, 20)
  g.print(("tick %03d"):format(app.tick), left, y + 14)
  g.printf("events from exact Stadium schedule", left, y + 14, right - left, "right")
end

function love.load()
  love.graphics.setBackgroundColor(0.035, 0.045, 0.07, 1)
  love.graphics.setLineWidth(2)
  loadAtlas()
  reset()
end

function love.update(dt)
  if not app.running or app.error then return end
  app.accumulator = app.accumulator + math.min(dt, 0.25)
  while app.accumulator >= TICK do
    step()
    app.accumulator = app.accumulator - TICK
  end
end

function love.keypressed(key)
  if key == "space" then app.running = not app.running end
  if key == "r" then reset() end
  if key == "1" then app.stage = "primary"; reset() end
  if key == "2" then app.stage = "impact"; reset() end
  if key == "right" and not app.running then step() end
  if key == "escape" then love.event.quit() end
end

function love.draw()
  local g = love.graphics
  local w, h = g.getDimensions()
  g.setColor(0.07, 0.09, 0.13, 1)
  g.ellipse("fill", w * 0.5, h * 0.68, w * 0.45, h * 0.16)
  drawCombatant(w * 0.29, h * 0.66, 1)
  drawCombatant(w * 0.71, h * 0.66, -1)

  if app.atlas then
    g.setBlendMode("add", "alphamultiply")
    for _, particle in ipairs(app.particles) do drawParticle(particle) end
    g.setBlendMode("alpha")
  end

  g.setColor(0.92, 0.94, 1, 1)
  g.print("THUNDER SHOCK / MOVE 84", 28, 24)
  g.print(("[%s stage]  1 primary  2 impact  SPACE pause  R restart  ESC quit")
    :format(app.stage), 28, 48)
  g.setColor(0.62, 0.67, 0.76, 1)
  g.printf("Exact atlas, frame rate, anchors, widths, and emission ticks. Particle motion, tint, blend, and controller behavior remain provisional.", 28, 75, w - 56)

  if app.error then
    g.setColor(1, 0.35, 0.30, 1)
    g.printf(app.error, 80, h * 0.35, w - 160, "center")
  end
  drawTimeline(w, h)
end

return app

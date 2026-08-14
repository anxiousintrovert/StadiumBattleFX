-- Standalone Stadium battle-presentation host and protected provider dispatch.

local V = ...
local Providers = V.require("BattleProviders")
local Mat4 = V.require("Mat4")
local Render = V.require("StadiumRender")
local CinematicsCompat = V.require("BattleCinematicsCompat")
local TrainerPortraits = V.require("StadiumTrainerPortraits")

local Host = { session = nil }
local GB_W, GB_H = 160, 144
local canvas, canvasW, canvasH = nil, 0, 0
local installedDraw, installedPicsLayer, installedPicImage
local SERVICE_SLOTS = {
  "animations", "camera", "effects", "announcer",
  "hud", "overlay", "transitions",
}
local defaultArena

local function invoke(session, slot, provider, method, ...)
  if session.failed[slot] and method ~= "finish" and method ~= "invalidate" then
    return false, "provider disabled"
  end
  local fn = provider and provider[method]
  if type(fn) ~= "function" then return true, nil end
  local ok, a, b, c = pcall(fn, provider, session.context, ...)
  if not ok then
    session.failed[slot] = true
    V.log:error("battle provider failed: slot=%s id=%s method=%s error=%s",
      slot, tostring(session.ids[slot] or "unknown"), method, tostring(a))
    return false, a
  end
  return true, a, b, c
end

local function acquire(session, slot)
  local provider, entry = Providers.resolve(slot, session.context)
  if not provider then return nil end
  session.ids[slot] = entry and entry.id or "unknown"
  return provider
end

local function fallback(session, slot)
  local provider, entry = Providers.builtin(slot, session.context)
  session.ids[slot] = entry and entry.id or "unknown"
  return provider
end

local function builtinArena(session)
  session.failed.arena = nil
  local provider = fallback(session, "arena")
  if not provider then
    session.providers.arena = nil
    session.context.arena = defaultArena()
    return false
  end
  local ok, arena = invoke(session, "arena", provider, "arena")
  if not ok or not arena or arena == Providers.FALLBACK then
    session.providers.arena = nil
    session.context.arena = defaultArena()
    return false
  end
  session.context.arena = arena
  session.providers.arena = provider
  local began, accepted = invoke(session, "arena", provider, "begin", arena)
  if not began or accepted == Providers.FALLBACK or accepted == false then
    session.providers.arena = nil
    session.context.arena = defaultArena()
    return false
  end
  return true
end

defaultArena = function()
  return {
    id = "stadium:neutral",
    portable = true,
    player = { 0, 24 }, enemy = { 0, -24 }, mid = { 0, 0 },
    camera = { side = 78.79, back = 217.44, height = 82,
               lookX = -0.26, lookY = 0.34, frameH = 70 },
  }
end

local function contextFor(battle)
  return {
    apiVersion = Providers.VERSION,
    battle = battle,
    game = battle and battle.game,
    encounter = {
      kind = battle and battle.kind,
      trainerId = battle and (battle.oppClass or (battle.trainer and battle.trainer.id)),
      mapId = battle and battle.currentMapId and battle:currentMapId() or nil,
      partyIndex = battle and battle.partyIndex,
    },
    sides = {
      player = { battler = battle and battle.player },
      enemy = { battler = battle and battle.enemy },
    },
    phase = "intro",
    groundY = 0,
    services = { log = V.log },
  }
end

local function baseCamera(arena)
  local R = arena and arena.camera or defaultArena().camera
  local mid = arena and arena.mid or { 0, 0 }
  local focus = { mid[1] + (R.lookX or 0), R.lookY or 0, mid[2] }
  local eye = { mid[1] + (R.side or 78.79), R.height or 82,
                mid[2] + (R.back or 217.44) }
  local dx, dy, dz = eye[1] - focus[1], eye[2] - focus[2], eye[3] - focus[3]
  local dist = math.max(2, math.sqrt(dx * dx + dy * dy + dz * dz))
  local fov = 2 * math.atan(((R.frameH or 70) / 2) / dist)
  return { eye = eye, focus = focus, fov = fov, curve = 0 }
end

local function cameraPose(session)
  local arena = session.context.arena
  local camera = baseCamera(arena)
  local pitch
  -- A mixed native/world composition (for example Dramaless BACK SPRITES)
  -- is half pinned to the GB frame and cannot follow a directed camera.
  -- Model providers may request the arena's authored base shot without
  -- reaching into the selected camera provider.
  local lockOk, cameraLocked = invoke(session, "models",
    session.providers.models, "cameraLocked")
  if lockOk and cameraLocked then return camera end
  local cameraProvider = session.providers.camera
  if cameraProvider and session.ids.camera == Providers.DEFAULT
      and CinematicsCompat.claim(session.context) then
    local directed, directedPitch = CinematicsCompat.shot(
      session.context, camera, false)
    if directed then camera, pitch = directed, directedPitch end
  elseif cameraProvider and session.ids.camera ~= Providers.DEFAULT then
    local claimedOk, claimed = invoke(session, "camera", cameraProvider, "claim",
      session.context.phase)
    if claimedOk and claimed then
      local shotOk, directed, directedPitch = invoke(session, "camera", cameraProvider,
        "shot", session.context.phase, session.context.progress, camera, arena)
      if shotOk and directed and directed ~= Providers.FALLBACK
          and directed.eye and directed.focus and directed.fov then
        camera, pitch = directed, directedPitch
      end
    end
  end
  local okDirector, Director = pcall(V.require, "AttackCinematics")
  if okDirector and Director and type(Director.camera) == "function" then
    local okShot, directed = pcall(Director.camera, camera, arena, 0)
    if okShot and directed and directed.eye and directed.focus then camera = directed end
  end
  return camera, pitch
end

local function cameraFor(session, width, height)
  local camera = cameraPose(session)
  local eye, focus, fov = camera.eye, camera.focus, camera.fov
  local renderer = session.battle and session.battle.game and session.battle.game.renderer
  local scale = renderer and renderer.fitScale and renderer:fitScale() or 1
  local span = GB_H * math.max(1, scale or 1)
  if height and span > 0 then
    fov = 2 * math.atan(math.tan(fov / 2) * height / span)
  end
  local dx, dy, dz = eye[1] - focus[1], eye[2] - focus[2], eye[3] - focus[3]
  local dist = math.max(2, math.sqrt(dx * dx + dy * dy + dz * dz))
  local projection = Mat4.perspective(fov, width / height,
    math.max(1, dist * .03), dist * 6)
  projection = Mat4.mul(Mat4.scale(1, -1, 1), projection)
  return Mat4.mul(projection, Mat4.lookAt(eye, focus, { 0, 1, 0 }))
end

local function project(vp, width, height, x, y, z)
  local cx = vp[1] * x + vp[2] * y + vp[3] * z + vp[4]
  local cy = vp[5] * x + vp[6] * y + vp[7] * z + vp[8]
  local cw = vp[13] * x + vp[14] * y + vp[15] * z + vp[16]
  if cw <= 1e-6 then return nil end
  return (cx / cw * .5 + .5) * width, (cy / cw * .5 + .5) * height
end

local function pixelSize()
  if love.graphics.getPixelDimensions then
    local w, h = love.graphics.getPixelDimensions()
    if w and h and w > 0 and h > 0 then return w, h end
  end
  return love.graphics.getDimensions()
end

-- Stadium's camera projects model attachments into framebuffer pixels, while
-- BattleState draws move sprites on its 160x144 logical canvas.  Convert the
-- live projection back into that canvas before StadiumFxPlayer consumes it.
-- This matters most on Android, where the framebuffer can be thousands of
-- pixels wide: passing those coordinates through unchanged draws every
-- particle completely off-screen and leaves only the engine's hit flash.
local function battleLayerGeometry(renderer, width, height)
  local uiWidth, uiHeight = GB_W, GB_H
  if renderer and type(renderer.uiSize) == "function" then
    local ok, w, h = pcall(renderer.uiSize, renderer)
    if ok and tonumber(w) and tonumber(h) then
      uiWidth, uiHeight = tonumber(w), tonumber(h)
    end
  end
  local scale
  if renderer and renderer.uiFill then
    scale = math.min(width / uiWidth, height / uiHeight)
  elseif renderer and type(renderer.uiScale) == "function" then
    local ok, value = pcall(renderer.uiScale, renderer)
    if ok then scale = tonumber(value) end
  elseif renderer and type(renderer.fitScale) == "function" then
    local ok, value = pcall(renderer.fitScale, renderer)
    if ok then scale = tonumber(value) end
  end
  scale = scale and scale > 0 and scale or 1
  local originX = (width - uiWidth * scale) / 2
  local originY = (height - uiHeight * scale) / 2
  local layerX = math.max(0, (uiWidth - GB_W) / 2)
  return {
    width = width, height = height,
    uiWidth = uiWidth, uiHeight = uiHeight,
    x = originX + layerX * scale, y = originY,
    scale = scale, layerX = layerX,
  }
end

local function battleLayerProjector(projector, renderer, width, height)
  if type(projector) ~= "function" then return nil end
  local viewport = battleLayerGeometry(renderer, width, height)
  return function(...)
    local x, y = projector(...)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return (x - viewport.x) / viewport.scale,
           (y - viewport.y) / viewport.scale
  end
end

-- Advanced arena providers may render above the final framebuffer resolution
-- for antialiasing, then resolve that pass to the window-sized surface they
-- return. Their view-projection coordinates therefore belong to the render
-- pass, not necessarily to the shown surface. Normalize those coordinates
-- before attachments are consumed by either the 160x144 move layer or the
-- direct world-surface particle pass.
local function shownSurfaceProjector(projector, renderWidth, renderHeight,
    surfaceWidth, surfaceHeight)
  if type(projector) ~= "function" then return nil end
  renderWidth, renderHeight = tonumber(renderWidth), tonumber(renderHeight)
  surfaceWidth, surfaceHeight = tonumber(surfaceWidth), tonumber(surfaceHeight)
  if not (renderWidth and renderHeight and surfaceWidth and surfaceHeight
      and renderWidth > 0 and renderHeight > 0
      and surfaceWidth > 0 and surfaceHeight > 0) then
    return projector
  end
  local sx, sy = surfaceWidth / renderWidth, surfaceHeight / renderHeight
  if math.abs(sx - 1) < 1e-9 and math.abs(sy - 1) < 1e-9 then return projector end
  return function(...)
    local x, y = projector(...)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x * sx, y * sy
  end
end

local function presentWorld(session, battle, surface)
  local renderer = battle and battle.game and battle.game.renderer
  if not (renderer and renderer.setWorldOverride and surface) then return false end
  renderer:setWorldOverride(surface)
  session.presented = true
  if not session.worldOverrideLogged then
    local ok, w, h = pcall(surface.getDimensions, surface)
    V.log:info("battle world override active: arena=%s surface=%s",
      tostring(session.ids.arena or "unknown"),
      ok and (tostring(w) .. "x" .. tostring(h)) or "unknown")
    session.worldOverrideLogged = true
  end
  return true
end

function Host.begin(battle, trainerPortraitsEnabled)
  Host.finish("replaced")
  if not battle then return false end
  local session = { battle = battle, context = contextFor(battle), providers = {},
                    ids = {}, failed = {} }
  Host.session = session
  if trainerPortraitsEnabled ~= false then
    session.trainerPortraits = TrainerPortraits.apply(battle)
  end
  battle.stadiumTrainerPortraitToken = session.trainerPortraits

  local arenaProvider = acquire(session, "arena")
  local arena
  if arenaProvider then
    local ok, value = invoke(session, "arena", arenaProvider, "arena")
    if ok and value ~= Providers.FALLBACK then arena = value end
    if value == Providers.FALLBACK and session.ids.arena ~= Providers.DEFAULT then
      arenaProvider = fallback(session, "arena")
      if arenaProvider then
        ok, value = invoke(session, "arena", arenaProvider, "arena")
        if ok and value ~= Providers.FALLBACK then arena = value end
      end
    end
  end
  session.context.arena = arena or defaultArena()
  session.providers.arena = arena and arenaProvider or nil
  if session.providers.arena then
    local ok, accepted = invoke(session, "arena", session.providers.arena,
      "begin", session.context.arena)
    if not ok or accepted == Providers.FALLBACK or accepted == false then
      builtinArena(session)
    end
  end

  local models = acquire(session, "models")
  session.providers.models = models
  if models then
    local ok, accepted = invoke(session, "models", models, "begin", session.context.arena)
    if not ok or accepted == Providers.FALLBACK or accepted == false then
      session.providers.models = nil
    end
  end
  for _, slot in ipairs(SERVICE_SLOTS) do
    local provider = acquire(session, slot)
    session.providers[slot] = provider
    if provider then
      local ok, accepted = invoke(session, slot, provider, "begin")
      if not ok or accepted == Providers.FALLBACK then session.providers[slot] = nil end
    end
  end
  session.render = session.providers.arena ~= nil or session.providers.models ~= nil
  V.log:info("battle presentation began: arena=%s models=%s encounter=%s",
    tostring(session.ids.arena or "engine"), tostring(session.ids.models or "engine"),
    tostring(session.context.encounter.kind or "unknown"))
  return true
end

function Host.update(dt)
  local session = Host.session
  if not session then return end
  TrainerPortraits.update(session.trainerPortraits)
  invoke(session, "arena", session.providers.arena, "update", dt, session.context.arena)
  invoke(session, "models", session.providers.models, "update", dt)
  if session.ids.camera == Providers.DEFAULT then
    CinematicsCompat.update(session.context, dt)
  end
  for _, slot in ipairs(SERVICE_SLOTS) do
    invoke(session, slot, session.providers[slot], "update", dt)
  end
end

function Host.event(name, payload)
  local session = Host.session
  if not session then return end
  if name == "battle.turn_started" or name == "battle.turn_ended" then
    session.context.phase = "passive"
  elseif name == "battle.move_used" then
    session.context.phase = "attack"
  elseif name == "battle.damage_dealt" then
    session.context.phase = "damage"
  elseif name == "battle.fainted" then
    session.context.phase = "faint"
  elseif name == "battle.battler_switched" then
    session.context.phase = "intro"
  elseif name == "battle.ended" then
    session.context.phase = "exit"
  end
  for _, slot in ipairs(SERVICE_SLOTS) do
    invoke(session, slot, session.providers[slot], "event", name, payload)
  end
end

function Host.call(slot, method, ...)
  local session = Host.session
  local provider = session and session.providers[slot]
  if not provider then return false, "no active " .. tostring(slot) .. " provider" end
  return invoke(session, slot, provider, method, ...)
end

function Host.coversSide(battle, side)
  local session = Host.session
  -- Never suppress the engine sprites until a Stadium surface has actually
  -- been handed to the renderer for this draw. This keeps the native battle
  -- usable if another UI mod replaces our draw hook or an arena render fails.
  if not (session and session.battle == battle and session.presented
      and not session.capturingNativePics
      and session.providers.models) then return false end
  if side ~= "player" and side ~= "enemy" then return false end
  local ok, covered = invoke(session, "models", session.providers.models, "covers", side)
  return ok and covered and true or false
end

function Host.draw(battle)
  local session = Host.session
  if not session then
    if not Host.noSessionLogged then
      V.log:warn("battle draw skipped: presentation session missing")
      Host.noSessionLogged = true
    end
    return false
  end
  if session.battle ~= battle then
    if not session.battleMismatchLogged then
      V.log:warn("battle draw skipped: active battle instance mismatch")
      session.battleMismatchLogged = true
    end
    return false
  end
  if not session.render then
    if not session.renderDisabledLogged then
      V.log:warn("battle draw skipped: no arena or model renderer active")
      session.renderDisabledLogged = true
    end
    return false
  end
  session.presented = false
  local renderer = battle and battle.game and battle.game.renderer
  local arenaProvider = session.providers.arena
  if arenaProvider and type(arenaProvider.render) == "function" then
    local pose, pitch = cameraPose(session)
    session.context.services.camera = { pose = pose, pitch = pitch }
    local function drawActors(world)
      world = world or {}
      local vp = world.vp
      if tonumber(world.groundY) then session.context.groundY = world.groundY end
      local renderWidth = tonumber(world.width)
      local renderHeight = tonumber(world.height)
      local projectWidth, projectHeight = renderWidth, renderHeight
      if not (projectWidth and projectHeight
          and projectWidth > 0 and projectHeight > 0) then
        projectWidth, projectHeight = pixelSize()
      end
      if type(world.project) == "function" then
        session.context.services.project = world.project
      elseif vp then
        session.context.services.project = function(x, y, z)
          return project(vp, projectWidth, projectHeight, x, y, z)
        end
      end
      session.context.services.renderSize = {
        width = renderWidth, height = renderHeight,
      }
      local surfaceWidth, surfaceHeight = pixelSize()
      local surfaceProjector = shownSurfaceProjector(
        session.context.services.project, projectWidth, projectHeight,
        surfaceWidth, surfaceHeight)
      local StadiumModels = V.require("StadiumModels")
      StadiumModels.setProjector(battleLayerProjector(
        surfaceProjector, renderer, surfaceWidth, surfaceHeight))
      if type(StadiumModels.setScreenProjector) == "function" then
        StadiumModels.setScreenProjector(surfaceProjector)
      end
      local models = session.providers.models
      if models and models.hostRender then
        if vp and Render.begin(vp) then
          invoke(session, "models", models, "drawWorld", 0)
          Render.finish()
        end
      else
        invoke(session, "models", models, "drawWorld", 0)
      end
    end
    local ok, surface = invoke(session, "arena", arenaProvider, "render",
      session.context.arena, drawActors)
    if ok and surface and surface ~= Providers.FALLBACK then
      if surface ~= true and presentWorld(session, battle, surface) then return true end
    end
    -- The advanced provider declined or failed after acquisition. Rebind the
    -- selected models to the built-in arena before drawing another stage;
    -- carrying world-map coordinates into Stadium's local court is invalid.
    invoke(session, "arena", arenaProvider, "finish", "render-fallback")
    if session.providers.models then
      invoke(session, "models", session.providers.models, "finish", "arena-fallback")
    end
    builtinArena(session)
    if session.providers.models then
      session.failed.models = nil
      local began, accepted = invoke(session, "models", session.providers.models,
        "begin", session.context.arena)
      if not began or accepted == Providers.FALLBACK or accepted == false then
        session.providers.models = nil
      end
    end
  end
  local width, height = pixelSize()
  local okCanvas, made = pcall(function()
    if not canvas or canvasW ~= width or canvasH ~= height then
      canvas = love.graphics.newCanvas(width, height, { dpiscale = 1 })
      canvasW, canvasH = width, height
    end
    return canvas
  end)
  if not okCanvas then
    V.log:error("battle presentation canvas failed: %s", tostring(made))
    return false
  end
  local prior = love.graphics.getCanvas()
  love.graphics.setCanvas({ canvas, depth = true })
  local clear = { 0, 0, 0, 1 }
  if session.providers.arena then
    local skyOk, sky = invoke(session, "arena", session.providers.arena,
      "sky", clear)
    if skyOk and type(sky) == "table" then clear = sky end
  end
  love.graphics.clear(clear[1] or 0, clear[2] or 0, clear[3] or 0,
    clear[4] == nil and 1 or clear[4], true, true)
  local vp = cameraFor(session, width, height)
  session.context.services.project = function(x, y, z)
    return project(vp, width, height, x, y, z)
  end
  session.context.services.renderSize = { width = width, height = height }
  local Models = V.require("StadiumModels")
  Models.setProjector(battleLayerProjector(
    session.context.services.project, renderer, width, height))
  if type(Models.setScreenProjector) == "function" then
    Models.setScreenProjector(session.context.services.project)
  end
  local models = session.providers.models
  if Render.begin(vp) then
    invoke(session, "arena", session.providers.arena, "drawWorld",
      session.context.arena, session.context.groundY)
    if models and models.hostRender then
      invoke(session, "models", models, "drawWorld", 0)
    end
    Render.finish()
  else
    invoke(session, "arena", session.providers.arena, "drawWorld",
      session.context.arena, session.context.groundY)
  end
  if models and not models.hostRender then
    -- External model providers own their rendering state. In particular,
    -- Dramaless cards must not inherit Stadium's mesh shader.
    invoke(session, "models", models, "drawWorld", 0)
  end
  love.graphics.setCanvas(prior)
  return presentWorld(session, battle, canvas)
end

function Host.finish(reason)
  local session = Host.session
  if not session then return end
  TrainerPortraits.restore(session.trainerPortraits)
  if session.battle then session.battle.stadiumTrainerPortraitToken = nil end
  invoke(session, "models", session.providers.models, "finish", reason or "ended")
  invoke(session, "arena", session.providers.arena, "finish", reason or "ended")
  for _, slot in ipairs(SERVICE_SLOTS) do
    invoke(session, slot, session.providers[slot], "finish", reason or "ended")
  end
  V.log:info("battle presentation finished: reason=%s", tostring(reason or "ended"))
  Host.session = nil
  Host.noSessionLogged = nil
end

function Host.invalidate()
  local session = Host.session
  if session then
    invoke(session, "arena", session.providers.arena, "invalidate")
    invoke(session, "models", session.providers.models, "invalidate")
    for _, slot in ipairs(SERVICE_SLOTS) do
      invoke(session, slot, session.providers[slot], "invalidate")
    end
  end
  Host.finish("invalidate")
  canvas = nil
  canvasW, canvasH = 0, 0
  Render.invalidate()
end

-- BattleState paints one opaque paper field before its HUD/text layers. A
-- world override must show through that UI canvas in both classic 160x144 and
-- wide 304x144 layouts; later full-field move flashes must remain visible.
-- The engine's legacy damage flash is different: it is an 0.85-alpha white
-- GB-sized rectangle. Dramaless already presents the hit on its arena actors,
-- and in borderless mode that old rectangle becomes a bright square surrounded
-- by the still-visible voxel world.
local function withoutBattleField(battle, fn)
  local g = love.graphics
  local rectangle = g.rectangle
  local fieldSuppressed = false
  local session = Host.session
  local arenaId = session and (session.ids.arena
    or (session.context.arena and session.context.arena.id))
  local dramalessArena = type(arenaId) == "string"
    and (arenaId:match("^DRAMALESS_SHAPE:") ~= nil
      or arenaId:match("^dramaless:") ~= nil)
  local stadiumArena = type(arenaId) == "string"
    and arenaId:match("^stadium:") ~= nil
  -- Any selected Stadium/external effects provider owns hit presentation for
  -- the active 3D scene. Do not key suppression to AnimPlayer.custom: the
  -- engine can advance or retire that flag before its independent fx.flash
  -- counter drains, which exposed a white frame between otherwise-correct
  -- overlays on Android.
  local stadiumCustomHit = session and session.presented
    and session.providers.effects ~= nil
  local fx = battle and battle.fx
  local suppressLegacyHitFlash = (dramalessArena or stadiumArena
    or stadiumCustomHit) and fx
    and tonumber(fx.flash) and fx.flash > 0
    and (tonumber(battle.frame) or 0) % 4 < 2
  local shaking = fx and (((tonumber(fx.shakeX) or 0) ~= 0)
    or ((tonumber(fx.shakeY) or 0) ~= 0)
    or ((tonumber(fx.shake) or 0) > 0))
  -- BattleState:drawZonePass repaints these SGB ATTR_BLK regions with opaque
  -- white before drawing its shifted background canvas. That is correct when
  -- the battle owns its paper background: the fill covers strips exposed by
  -- screen shake. With a 3D world override, however, the source canvas is
  -- deliberately transparent and alpha blending cannot erase the refill.
  -- The result is the white, block-shaped 160x144 framebuffer seen over the
  -- borderless arena on every impact. Suppress only the six authored battle
  -- zone fills while a real shake offset is active; the shifted HUD, text and
  -- animation sprites still draw from their source layers immediately after.
  local shakeZoneFills = {
    ["0:0:160:144"] = true,
    ["8:0:80:32"] = true,
    ["80:56:80:32"] = true,
    ["0:32:72:64"] = true,
    ["88:0:72:56"] = true,
    ["0:96:160:48"] = true,
  }
  g.rectangle = function(mode, x, y, w, h, ...)
    local r, green, b, a = g.getColor()
    local fullField = mode == "fill" and x == 0 and y == 0
      and h == GB_H and (w == GB_W or w == 304)
    if not fieldSuppressed and fullField and (a or 1) > .99 then
      fieldSuppressed = true
      local target = g.getCanvas()
      if target ~= nil and (target == battle.bgCanvas or target == battle.waveCanvas) then
        g.clear(0, 0, 0, 0)
      end
      return
    end
    local shakeZone = mode == "fill" and shaking
      and shakeZoneFills[table.concat({ x, y, w, h }, ":")]
    if fieldSuppressed and shakeZone
        and (r or 1) > .99 and (green or 1) > .99 and (b or 1) > .99
        and (a or 1) > .99 then
      return
    end
    -- BattleState's hit overlay is exactly white at alpha 0.85. Match that
    -- narrow signature so StadiumScreenFx washes/flashes still compose over
    -- the world, including on the same impact frame.
    if fieldSuppressed and suppressLegacyHitFlash and fullField
        and (r or 1) > .99 and (green or 1) > .99 and (b or 1) > .99
        and math.abs((a or 1) - .85) < .001 then
      return
    end
    return rectangle(mode, x, y, w, h, ...)
  end
  local ok, result = pcall(fn)
  g.rectangle = rectangle
  if not ok then error(result, 0) end
  return result
end

-- Read-only diagnostic/test seam. Providers should use context.services.camera.
function Host.cameraPose()
  if not Host.session then return nil end
  return cameraPose(Host.session)
end

-- Pure regression-test seam for the framebuffer-to-animation-layer mapping.
Host.battleLayerProjector = battleLayerProjector
Host.shownSurfaceProjector = shownSurfaceProjector

-- Live mapping shared by the model projector and the deferred battle VFX
-- pass. During BattleState:draw, surface is the full-resolution 3D world
-- canvas; after Renderer:endFrame it is nil but the geometry remains useful
-- to the screen-overlay hook. Recomputing it each call keeps moving cameras,
-- window resizes and Android orientation changes in the same coordinate
-- system for that rendered frame.
function Host.animationViewport()
  local session = Host.session
  local battle = session and session.battle
  local renderer = battle and battle.game and battle.game.renderer
  if not renderer then return nil end
  local width, height = pixelSize()
  local viewport = battleLayerGeometry(renderer, width, height)
  viewport.surface = renderer.worldOverride
  return viewport
end

function Host.install(force)
  local BattleState = require("src.battle.BattleState")
  if BattleState.draw == installedDraw
      and BattleState.drawPicsLayer == installedPicsLayer then return false end
  BattleState.stadiumBattleFxHostHook = true

  if BattleState.picImage ~= installedPicImage then
    local innerPicImage = BattleState.picImage
    installedPicImage = function(self, image)
      if TrainerPortraits.owns(self, image) then return image end
      return innerPicImage(self, image)
    end
    BattleState.picImage = installedPicImage
  end

  if BattleState.drawPicsLayer ~= installedPicsLayer then
    local innerPicsLayer = BattleState.drawPicsLayer
    installedPicsLayer = function(self, slide, sx, sy, onlySide, skipMenuClip)
      if onlySide == "player" or onlySide == "enemy" then
        if Host.coversSide(self, onlySide) then return end
        return innerPicsLayer(self, slide, sx, sy, onlySide, skipMenuClip)
      end
      local playerCovered = Host.coversSide(self, "player")
      local enemyCovered = Host.coversSide(self, "enemy")
      if playerCovered and enemyCovered then return end
      if playerCovered then onlySide = "enemy"
      elseif enemyCovered then onlySide = "player" end
      return innerPicsLayer(self, slide, sx, sy, onlySide, skipMenuClip)
    end
    BattleState.drawPicsLayer = installedPicsLayer
  end

  if BattleState.draw ~= installedDraw then
    local innerDraw = BattleState.draw
    installedDraw = function(self, ...)
    local args = { ... }
    local world = Host.draw(self)
    local result
    if world then
      self.letterboxWhite = false
      love.graphics.clear(0, 0, 0, 0)
      result = withoutBattleField(self, function()
        return innerDraw(self, unpack(args))
      end)
    else
      self.letterboxWhite = nil
      result = innerDraw(self, unpack(args))
    end
    local session = Host.session
    if session and session.battle == self then
      for _, slot in ipairs({ "hud", "overlay", "transitions" }) do
        invoke(session, slot, session.providers[slot], "drawScreen")
      end
    end
    return result
    end
    BattleState.draw = installedDraw
  end
  return true
end

-- A model provider may need the engine's own side-only pic renderer to build
-- a texture. Keep that exception scoped to the callback: native battle pics
-- remain suppressed for the actual UI composition whenever the selected
-- model provider covers them.
local function withNativeBattlePics(session, fn, ...)
  if type(fn) ~= "function" then return false, "capture callback is required" end
  session.capturingNativePics = true
  local results = { pcall(fn, ...) }
  session.capturingNativePics = nil
  if not results[1] then return false, results[2] end
  table.remove(results, 1)
  return true, unpack(results)
end

-- Sessions are created before external providers are acquired, so install
-- the capture service at begin-time where it can close over the right battle.
local innerContextFor = contextFor
contextFor = function(battle)
  local context = innerContextFor(battle)
  context.services.withNativeBattlePics = function(fn, ...)
    local session = Host.session
    if not (session and session.battle == battle) then
      return false, "battle presentation session is not active"
    end
    return withNativeBattlePics(session, fn, ...)
  end
  return context
end

return Host

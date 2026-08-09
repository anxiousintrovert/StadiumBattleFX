local Texture = require("lib.StadiumTexture")

-- CI/compile-only launches must fail in the console instead of waiting on
-- LÖVE's interactive error screen.
if os.getenv("STADIUM_FX_COMPILE_ONLY") == "1" then
  love.errorhandler = function(message)
    io.stderr:write(debug.traceback(tostring(message), 2), "\n")
    return function() return 1 end
  end
end

local function loadPlayer()
  local modules = { StadiumTexture = Texture }
  local namespace = {}
  function namespace.require(name)
    if modules[name] then return modules[name] end
    if name == "effects/ThunderShockSpec" then
      modules[name] = require("lib.effects.ThunderShockSpec")
      return modules[name]
    end
    error("unexpected self-test module: " .. tostring(name))
  end
  local chunk = assert(love.filesystem.load("lib/effects/ThunderShockPlayer.lua"))
  return chunk(namespace)
end

function love.load()
  for _, path in ipairs({
    "lib/StadiumAssets.lua",
    "lib/EffectCacheScreen.lua",
    "lib/StadiumRomPicker.lua",
    "lib/DramaticShapeState.lua",
    "lib/DramaticShapeAttachment.lua",
    "lib/DramaticShapeHit.lua",
    "lib/AttackCinematics.lua",
    "lib/FailureNotice.lua",
    "lib/effects/MoveSpecs.lua",
    "lib/effects/StadiumFidelityProfiles.lua",
    "lib/effects/StadiumTimingProfiles.lua",
    "lib/effects/StadiumRosterCalibration.lua",
    "lib/effects/AllMoveSpecs.lua",
    "lib/effects/StadiumMoveRoster.lua",
    "lib/effects/StadiumFxPlayer.lua",
    "lib/effects/StadiumAuthenticRenderer.lua",
    "lib/effects/GenericMoveRenderer.lua",
    "lib/effects/StadiumScreenFx.lua",
    "lib/effects/ThunderShockSpec.lua",
  }) do
    assert(love.filesystem.load(path), "runtime module did not compile: " .. path)
  end
  assert(love.filesystem.load("tests/test_dramatic_shape_state.lua"))()
  assert(love.filesystem.load("tests/test_dramatic_shape_attachment.lua"))()
  assert(love.filesystem.load("tests/test_dramatic_shape_hit.lua"))()
  assert(love.filesystem.load("tests/test_hit_timing.lua"))()
  assert(love.filesystem.load("tests/test_main_integration.lua"))()
  assert(love.filesystem.load("tests/test_camera_compat.lua"))()
  assert(love.filesystem.load("tests/test_attack_cinematics.lua"))()
  assert(love.filesystem.load("tests/test_full_roster.lua"))()
  assert(love.filesystem.load("tests/test_attack_speed.lua"))()
  assert(love.filesystem.load("tests/test_cache_directory.lua"))()
  assert(love.filesystem.load("tests/test_cache_subset.lua"))()
  assert(love.filesystem.load("tests/test_cache_free_fallback.lua"))()
  assert(love.filesystem.load("tests/test_player_fallback.lua"))()
  assert(love.filesystem.load("tests/test_roster_calibration.lua"))()
  assert(love.filesystem.load("tests/test_timing_profiles.lua"))()
  assert(love.filesystem.load("tests/test_screen_fx.lua"))()
  assert(love.filesystem.load("tests/test_stadium_fidelity.lua"))()
  if os.getenv("STADIUM_FX_COMPILE_ONLY") == "1" then
    print("ok runtime modules compile")
    love.event.quit(0)
    return
  end

  local asset, err = Texture.get()
  assert(asset, tostring(err))
  assert(asset.frames == 8, "wrong Thunder Shock frame count")
  assert(asset.frameWidth == 32 and asset.frameHeight == 96,
         "wrong Thunder Shock frame dimensions")
  assert(asset.image:getWidth() == 256 and asset.image:getHeight() == 96,
         "wrong Thunder Shock atlas dimensions")

  local Player = loadPlayer()
  local inner = { updates = 0, starts = {} }
  function inner:start(move) self.starts[#self.starts + 1] = move end
  function inner:update() self.updates = self.updates + 1 end
  function inner:isDone() return false end
  function inner:pollEffects()
    return { { sound = "THUNDERSHOCK" }, { effect = "SE_SHAKE_SCREEN" } }
  end
  function inner:draw() self.vanillaDrawn = true end
  function inner:release() self.released = true end
  local player = Player.new(inner, function() return true end)
  player:start("TACKLE", true)
  assert(not player.custom and inner.starts[1] == "TACKLE",
         "non-Thunder-Shock move was not delegated")
  player:start("THUNDERSHOCK", true)
  assert(player.custom and inner.starts[2] == "THUNDERSHOCK",
         "Thunder Shock adapter did not start")
  local events = player:pollEffects()
  assert(#events == 1 and events[1].sound == "THUNDERSHOCK",
         "custom player did not preserve only the original sound event")
  player:draw()
  for _ = 1, 100 do player:update() end
  assert(player:isDone(), "Thunder Shock did not complete at tick 100")
  player:release()
  assert(inner.released, "wrapped player was not released")

  local handlers = {}
  local optionValues = {}
  local mod = {
    path = "",
    exports = {},
    find = function() return nil end,
    read = function(_, path) return love.filesystem.read(path) end,
    options = {
      define = function(_, rows)
        for _, row in ipairs(rows) do optionValues[row.key] = row.default end
      end,
      get = function(_, key) return optionValues[key] end,
    },
    events = {
      on = function(_, name, fn) handlers[name] = fn end,
    },
    hooks = {
      wrap = function(_, name, fn) handlers["hook:" .. name] = fn end,
    },
    log = {
      info = function() end, warn = function() end, error = function() end,
    },
  }
  local modChunk = assert(love.filesystem.load("main.lua"))
  modChunk(mod)
  assert(mod.exports.version == "1.0.2", "wrong mod export version")
  assert(type(handlers["battle.started"]) == "function",
         "battle integration event was not registered")
  assert(type(handlers["hook:render.hud"]) == "function",
         "borderless screen compositor hook was not registered")
  assert(type(handlers["battle.damage_dealt"]) == "function",
         "hit-reaction event was not registered")
  assert(handlers["battle.fainted"] == nil,
         "unreleased faint-reaction event must remain disabled")
  local liveInner = {}
  function liveInner:start() end
  function liveInner:isDone() return true end
  function liveInner:pollEffects() return {} end
  handlers["battle.started"]({ battle = { animPlayer = liveInner } })
  local cacheStatus = mod.exports.textureStatus()
  assert(cacheStatus.ready and cacheStatus.assets == 36,
         "full Stadium 1 texture cache did not load")
  print("ok runtime Thunder Shock texture: " .. tostring(asset.path))
  print("ok runtime Stadium 1 cache: " .. tostring(cacheStatus.assets) .. " assets")
  love.event.quit(0)
end

return true

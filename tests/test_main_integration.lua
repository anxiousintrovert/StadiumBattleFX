local loader = loadfile or (love and love.filesystem and love.filesystem.load)
local handlers = {}
local values = {}
local schemas = {}
local handles = {}
local mod = {
  id = "STADIUM_BATTLE_FX",
  path = "",
  exports = {},
  find = function(a, b)
    local id = b or a
    return handles[id]
  end,
  read = function(_, path)
    local file = io and io.open and io.open(path, "rb")
    if file then
      local source = file:read("*a")
      file:close()
      return source
    end
    if love and love.filesystem then return love.filesystem.read(path) end
  end,
  options = {
    define = function(_, rows)
      for _, row in ipairs(rows) do
        values[row.key] = row.default
        schemas[row.key] = row
      end
    end,
    get = function(_, key) return values[key] end,
  },
  events = { on = function(_, name, fn) handlers[name] = fn end },
  hooks = { wrap = function(_, name, fn) handlers["hook:" .. name] = fn end },
  log = { info = function() end, warn = function() end, error = function() end },
}

assert(loader("main.lua"))(mod)
assert(mod.exports.version == "2.0.0")
assert(type(mod.exports.battles) == "table" and mod.exports.battles.version == 1,
       "StadiumBattleFX did not export provider API 1")
assert(type(mod.exports.battles.registerComponent) == "function"
       and type(mod.exports.battles.resolve) == "function",
       "provider registration/resolution methods were not exported")
assert(values.provider_arena == "stadium:default"
       and values.provider_models == "stadium:default"
       and values.provider_animations == "stadium:default",
       "modular presentation selectors did not default to Stadium")
assert(values.attack_speed == "100", "attack speed did not default to 100%")
assert(values.announcer_scope == "gym", "announcer scope did not default to Gym/Elite Four/Champion")
assert(#schemas.announcer_scope.choices == 3
       and schemas.announcer_scope.choices[1][2] == "gym"
       and schemas.announcer_scope.choices[2][2] == "trainer"
       and schemas.announcer_scope.choices[3][2] == "all",
       "announcer scope did not expose the three requested battle ranges")
assert(#schemas.attack_speed.choices == 11
       and schemas.attack_speed.choices[1][2] == "100"
       and schemas.attack_speed.choices[11][2] == "0",
       "attack speed did not expose the complete 100%-0% ladder")
assert(type(handlers["battle.move_used"]) == "function")
assert(type(handlers["battle.damage_dealt"]) == "function")
assert(type(handlers["battle.battler_switched"]) == "function")
assert(type(handlers["battle.status_inflicted"]) == "function")
assert(type(handlers["battle.fainted"]) == "function")
assert(type(mod.exports.announcerStatus) == "function")
assert(type(mod.exports.faintStatus) == "function")
assert(type(handlers["mods.loaded"]) == "function")
assert(type(handlers["hook:ui.options.rows"]) == "function",
  "cache import/rebuild option rows were not registered")
local optionRows = handlers["hook:ui.options.rows"](
  function(_, rows) return rows end, {}, {})
assert(optionRows[#optionRows - 2].id == "STADIUM_BATTLE_FX:stadiumRom"
    and optionRows[#optionRows - 1].id == "STADIUM_BATTLE_FX:refreshCache"
    and optionRows[#optionRows].id == "STADIUM_BATTLE_FX:exportLog",
  "cache and log action rows were not appended")

-- Battle Cinematics loads after Stadium's supported renderer and wraps that
-- renderer's shared BattleCam table. The final mod-load event must consume the
-- official hook without requiring any changes to the BC package.
local wrappedCamera = {
  __bcStandaloneDW3Wrapped = true,
  rigFor = function() return {} end,
  rig = function()
    return { eye = { 1, 2, 3 }, focus = { 0, 0, 0 }, fov = 0.5 }
  end,
}
handles.DRAMALESS_SHAPE = {
  version = "2.0.0",
  exports = { lib = { require = function(name)
    assert(name == "BattleCam")
    return wrappedCamera
  end } },
}
handles.BATTLE_CINEMATICS = {
  version = "0.7.96",
  exports = { version = "0.7.96" },
}
handlers["mods.loaded"]()
local cameraEntries = mod.exports.battles:componentList("camera")
assert(#cameraEntries == 1
    and cameraEntries[1].id == "BATTLE_CINEMATICS:camera"
    and cameraEntries[1].label == "BATTLE CINEMATICS",
  "mods.loaded did not register Battle Cinematics in the camera catalog")
local cameraChoices = {}
for _, choice in ipairs(schemas.provider_camera.choices) do
  cameraChoices[choice[2]] = choice[1]
end
assert(cameraChoices["BATTLE_CINEMATICS:camera"] == "BATTLE CINEMATICS",
  "Battle Cinematics did not appear in the BTL CAMERA option list")

local movePayload, damagePayload
local player = {
  setMoveContext = function(_, payload) movePayload = payload end,
  recordDamage = function(_, payload) damagePayload = payload end,
}
local battle = { animPlayer = player }
handlers["battle.move_used"]({ battle = battle, move = { index = 84 } })
handlers["battle.damage_dealt"]({ battle = battle, damage = 12, typeMult = 20 })
assert(movePayload and movePayload.move.index == 84)
assert(damagePayload and damagePayload.damage == 12 and damagePayload.typeMult == 20)

local faintBattle = { player = {}, enemy = {}, kind = "trainer" }
handlers["battle.fainted"]({ battle = faintBattle, battler = faintBattle.player })
local faintStatus = mod.exports.faintStatus()
assert(faintStatus.requests == 1,
       "player faint was not forwarded to the local Stadium model runtime")
print("ok 2.0.0 runtime event wiring")

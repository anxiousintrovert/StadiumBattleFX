local loader = love and love.filesystem and love.filesystem.load or loadfile
local handlers = {}
local values = {}
local schemas = {}
local companion
local mod = {
  path = "",
  exports = {},
  find = function(id)
    if id == "DRAMALESS_SHAPE" then return companion end
    return nil
  end,
  read = function(_, path)
    if love and love.filesystem then return love.filesystem.read(path) end
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
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
assert(mod.exports.version == "1.0.9")
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
assert(type(handlers["hook:ui.options.rows"]) == "function",
  "cache import/rebuild option rows were not registered")
local optionRows = handlers["hook:ui.options.rows"](
  function(_, rows) return rows end, {}, {})
assert(optionRows[#optionRows - 2].id == "STADIUM_BATTLE_FX:stadiumRom"
    and optionRows[#optionRows - 1].id == "STADIUM_BATTLE_FX:refreshCache"
    and optionRows[#optionRows].id == "STADIUM_BATTLE_FX:exportLog",
  "cache and log action rows were not appended")

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

local faintCalls = {}
companion = {
  exports = {
    lib = {
      require = function(name)
        assert(name == "Stadium")
        return {
          faint = function(side, disposition)
            faintCalls[#faintCalls + 1] = { side, disposition }
            return true
          end,
        }
      end,
    },
  },
}
local faintBattle = { player = {}, enemy = {}, kind = "trainer" }
handlers["battle.fainted"]({ battle = faintBattle, battler = faintBattle.player })
assert(#faintCalls == 1 and faintCalls[1][1] == "player"
       and faintCalls[1][2] == "recall",
       "player faint was not forwarded to Dramaless Shape")
print("ok 1.0.8 runtime event wiring")

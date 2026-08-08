local loader = love and love.filesystem and love.filesystem.load or loadfile
local handlers = {}
local values = {}
local mod = {
  path = "",
  exports = {},
  find = function() return nil end,
  read = function(_, path)
    if love and love.filesystem then return love.filesystem.read(path) end
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
  end,
  options = {
    define = function(_, rows)
      for _, row in ipairs(rows) do values[row.key] = row.default end
    end,
    get = function(_, key) return values[key] end,
  },
  events = { on = function(_, name, fn) handlers[name] = fn end },
  hooks = { wrap = function(_, name, fn) handlers["hook:" .. name] = fn end },
  log = { info = function() end, warn = function() end, error = function() end },
}

assert(loader("main.lua"))(mod)
assert(mod.exports.version == "1.0.0")
assert(type(handlers["battle.move_used"]) == "function")
assert(type(handlers["battle.damage_dealt"]) == "function")
assert(type(handlers["battle.battler_switched"]) == "function")
assert(type(handlers["battle.status_inflicted"]) == "function")
assert(type(handlers["battle.fainted"]) == "function")
assert(type(mod.exports.announcerStatus) == "function")

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
print("ok 1.0.0 runtime event wiring")

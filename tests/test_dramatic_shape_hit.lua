local loader = love and love.filesystem and love.filesystem.load or loadfile
local accepted = true
local calls = {}
local Hit = assert(loader("lib/DramaticShapeHit.lua"))({
  require = function(name)
    assert(name == "BattleHost")
    return { call = function(_, method, side, effectiveness)
      calls[#calls + 1] = { method, side, effectiveness }
      if accepted then return true, true end
      return false, "no active models provider"
    end }
  end,
})

assert(Hit.effectiveness(5) == "resisted")
assert(Hit.effectiveness(10) == "neutral")
assert(Hit.effectiveness(20) == "super")
assert(Hit.request(nil, "enemy", "super"))
assert(calls[1][1] == "hit" and calls[1][2] == "enemy" and calls[1][3] == "super")
accepted = false
local ok, err = Hit.request(nil, "player", "neutral")
assert(not ok and err:find("no active", 1, true))
print("ok selected model-provider hit bridge")

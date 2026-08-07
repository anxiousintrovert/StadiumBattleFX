local loader = love and love.filesystem and love.filesystem.load or loadfile
local Hit = assert(loader("lib/DramaticShapeHit.lua"))()

assert(Hit.effectiveness(5) == "resisted")
assert(Hit.effectiveness(10) == "neutral")
assert(Hit.effectiveness(20) == "super")

local calls = {}
local companion = function()
  return { exports = { lib = { require = function(name)
    assert(name == "Stadium")
    return { hit = function(side, effectiveness)
      calls[#calls + 1] = { side, effectiveness }
    end }
  end } } }
end

assert(Hit.request(companion, "enemy", "super"))
assert(#calls == 1 and calls[1][1] == "enemy" and calls[1][2] == "super")
local status = Hit.status()
assert(status.supported and status.requests == 1 and status.accepted == 1)

local ok, err = Hit.request(function()
  return { exports = { lib = { require = function() return {} end } } }
end, "player", "neutral")
assert(not ok and err:find("Stadium.hit", 1, true))
print("ok dramatic shape public hit bridge")

local loader = love and love.filesystem and love.filesystem.load or loadfile
local Faint = assert(loader("lib/DramaticShapeFaint.lua"))()

assert(Faint.disposition({ kind = "wild" }, { isPlayer = false }) == "collapse")
assert(Faint.disposition({ kind = "wild" }, { isPlayer = true }) == "recall")
assert(Faint.disposition({ kind = "trainer" }, { isPlayer = false }) == "recall")
assert(Faint.disposition({ kind = "link" }, { isPlayer = false }) == "recall")

local calls = {}
local companion = function()
  return { exports = { lib = { require = function(name)
    assert(name == "Stadium")
    return { faint = function(side, disposition)
      calls[#calls + 1] = { side, disposition }
    end }
  end } } }
end

assert(Faint.request(companion, "enemy", "collapse"))
assert(#calls == 1 and calls[1][1] == "enemy" and calls[1][2] == "collapse")
local status = Faint.status()
assert(status.supported and status.requests == 1 and status.accepted == 1)

local ok, err = Faint.request(function()
  return { exports = { lib = { require = function() return {} end } } }
end, "player", "recall")
assert(not ok and err:find("Stadium.faint", 1, true))
print("ok dramatic shape public faint bridge")

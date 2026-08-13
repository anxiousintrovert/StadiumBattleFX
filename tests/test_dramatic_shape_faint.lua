local loader = love and love.filesystem and love.filesystem.load or loadfile
local accepted = true
local calls = {}
local Faint = assert(loader("lib/DramaticShapeFaint.lua"))({
  require = function(name)
    assert(name == "BattleHost")
    return { call = function(_, method, side, disposition)
      calls[#calls + 1] = { method, side, disposition }
      if accepted then return true, true end
      return false, "no active models provider"
    end }
  end,
})

assert(Faint.disposition({ kind = "wild" }, { isPlayer = false }) == "collapse")
assert(Faint.disposition({ kind = "wild" }, { isPlayer = true }) == "recall")
assert(Faint.disposition({ kind = "trainer" }, { isPlayer = false }) == "recall")
assert(Faint.request(nil, "enemy", "collapse"))
assert(calls[1][1] == "faint" and calls[1][2] == "enemy")
accepted = false
local ok, err = Faint.request(nil, "player", "recall")
assert(not ok and err:find("no active", 1, true))
print("ok selected model-provider faint bridge")

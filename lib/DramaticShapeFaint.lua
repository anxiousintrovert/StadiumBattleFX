-- Optional bridge to Dramaless Shape's public Stadium faint-disposition API.
-- The request is made when Gen1Recomp records the faint; Dramaless Shape
-- remains responsible for waiting for the HP drain and animating its model.

local Faint = {}

local state = { supported = false, requests = 0, accepted = 0, lastError = nil }

local function stadiumModule(companion)
  local found = companion and companion()
  local exports = found and found.exports
  local lib = exports and exports.lib
  if not (lib and type(lib.require) == "function") then
    return nil, "Dramaless Shape library is unavailable"
  end
  local ok, Stadium = pcall(lib.require, "Stadium")
  if not ok or type(Stadium) ~= "table" then
    return nil, "Dramaless Shape Stadium module is unavailable"
  end
  if type(Stadium.faint) ~= "function" then
    return nil, "installed Dramaless Shape does not export Stadium.faint"
  end
  return Stadium
end

-- The enemy in a wild encounter owns no Poke Ball and collapses in place.
-- Every player Pokemon, and enemy Pokemon in trainer/link battles, is owned
-- by a trainer and returns to its ball.
function Faint.disposition(battle, battler)
  if battle and battle.kind == "wild" and battler and not battler.isPlayer then
    return "collapse"
  end
  return "recall"
end

function Faint.request(companion, side, disposition)
  state.requests = state.requests + 1
  local Stadium, err = stadiumModule(companion)
  if not Stadium then
    state.supported = false
    state.lastError = err
    return false, err
  end

  state.supported = true
  local ok, accepted = pcall(Stadium.faint, side, disposition)
  if not ok then
    state.lastError = tostring(accepted)
    return false, state.lastError
  end
  if accepted == false then
    state.lastError = "Dramaless Shape declined the faint reaction"
    return false, state.lastError
  end
  state.accepted = state.accepted + 1
  state.lastError = nil
  return true
end

function Faint.status()
  return {
    supported = state.supported,
    requests = state.requests,
    accepted = state.accepted,
    lastError = state.lastError,
  }
end

return Faint

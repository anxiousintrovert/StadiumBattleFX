-- Compatibility-named bridge to StadiumBattleFX's own faint-disposition API.

local V = ...

local Faint = {}

local state = { supported = false, requests = 0, accepted = 0, lastError = nil }

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
  local ok, accepted = V.require("BattleHost").call(
    "models", "faint", side, disposition)
  if not ok then
    state.supported = false
    state.lastError = tostring(accepted)
    return false, state.lastError
  end

  state.supported = true
  if accepted == false then
    state.lastError = "Stadium model provider declined the faint reaction"
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

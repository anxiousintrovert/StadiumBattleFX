-- Compatibility-named bridge to StadiumBattleFX's own hit-reaction API.

local V = ...

local Hit = {}

local state = {
  supported = false,
  requests = 0,
  accepted = 0,
  lastError = nil,
}

function Hit.effectiveness(typeMult)
  typeMult = tonumber(typeMult) or 10
  if typeMult < 10 then return "resisted" end
  if typeMult > 10 then return "super" end
  return "neutral"
end

function Hit.request(companion, side, effectiveness)
  state.requests = state.requests + 1
  local ok, accepted = V.require("BattleHost").call(
    "models", "hit", side, effectiveness)
  if not ok then
    state.supported = false
    state.lastError = tostring(accepted)
    return false, state.lastError
  end

  state.supported = true
  if accepted == false then
    state.lastError = "Stadium model provider declined the hit reaction"
    return false, state.lastError
  end

  state.accepted = state.accepted + 1
  state.lastError = nil
  return true
end

function Hit.status()
  return {
    supported = state.supported,
    requests = state.requests,
    accepted = state.accepted,
    lastError = state.lastError,
  }
end

return Hit

-- Bridge to Dramaless Shape's public Stadium hit-reaction API.
-- This module never reaches into the companion's private session and never
-- writes to its installation or cache.

local Hit = {}

local state = {
  supported = false,
  requests = 0,
  accepted = 0,
  lastError = nil,
}

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
  if type(Stadium.hit) ~= "function" then
    return nil, "installed Dramaless Shape does not export Stadium.hit"
  end
  return Stadium
end

function Hit.effectiveness(typeMult)
  typeMult = tonumber(typeMult) or 10
  if typeMult < 10 then return "resisted" end
  if typeMult > 10 then return "super" end
  return "neutral"
end

function Hit.request(companion, side, effectiveness)
  state.requests = state.requests + 1
  local Stadium, err = stadiumModule(companion)
  if not Stadium then
    state.supported = false
    state.lastError = err
    return false, err
  end

  state.supported = true
  local ok, accepted = pcall(Stadium.hit, side, effectiveness)
  if not ok then
    state.lastError = tostring(accepted)
    return false, state.lastError
  end
  if accepted == false then
    state.lastError = "Dramaless Shape declined the hit reaction"
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

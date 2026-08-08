-- Read-only bridge to Dramaless Shape's projected Stadium attachment API.
-- The companion owns the model, pose, matrices, and camera projection; this
-- module only asks for the final point and falls back cleanly when unavailable.

local Attachment = {}

local state = {
  supported = false,
  requests = 0,
  resolved = 0,
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
  if type(Stadium.attachment) ~= "function" then
    return nil, "installed Dramaless Shape does not export Stadium.attachment"
  end
  return Stadium
end

function Attachment.position(companion, side, tag)
  state.requests = state.requests + 1
  local Stadium, err = stadiumModule(companion)
  if not Stadium then
    state.supported = false
    state.lastError = err
    return nil
  end

  state.supported = true
  local fn = tag == 0xFF and Stadium.center or Stadium.attachment
  if type(fn) ~= "function" then
    state.lastError = tag == 0xFF
      and "installed Dramaless Shape does not export Stadium.center"
      or nil
    return nil
  end
  local ok, x, y = pcall(fn, side, tag or 0x64)
  if not ok then
    state.lastError = tostring(x)
    return nil
  end
  if type(x) ~= "number" or type(y) ~= "number" then
    -- A hidden model or unavailable pose is an ordinary per-frame fallback,
    -- not an integration error.
    state.lastError = nil
    return nil
  end

  state.resolved = state.resolved + 1
  state.lastError = nil
  return x, y
end

-- Resolve the source battle table's species-specific attachment bytes. Older
-- companion builds simply lack this API and retain the established 0x64
-- fallback in the caller.
function Attachment.tags(companion, side, moveId, stage)
  local Stadium = stadiumModule(companion)
  if not (Stadium and type(Stadium.attachmentTags) == "function") then
    return nil
  end
  local ok, a, b = pcall(Stadium.attachmentTags, side, moveId, stage)
  if not ok then return nil end
  return tonumber(a), tonumber(b)
end

function Attachment.status()
  return {
    supported = state.supported,
    requests = state.requests,
    resolved = state.resolved,
    lastError = state.lastError,
  }
end

return Attachment

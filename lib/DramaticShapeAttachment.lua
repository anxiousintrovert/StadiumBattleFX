-- Compatibility-named bridge to StadiumBattleFX's own model attachments.

local V = ...

local Attachment = {}

local state = {
  supported = false,
  requests = 0,
  resolved = 0,
  lastError = nil,
}

function Attachment.position(companion, side, tag)
  state.requests = state.requests + 1
  local Host = V.require("BattleHost")
  local method = tag == 0xFF and "center" or "attachment"
  local ok, x, y = Host.call("models", method, side, tag or 0x64)
  if not ok then
    state.supported = false
    state.lastError = tostring(x)
    return nil
  end

  state.supported = true
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

-- Raw full-render-surface attachment projection. This is intentionally a
-- separate provider method from position(): callers drawing on the final 3D
-- surface must not accidentally mix it with logical battle-layer values.
function Attachment.screenPosition(companion, side, tag)
  state.requests = state.requests + 1
  local Host = V.require("BattleHost")
  local method = tag == 0xFF and "screenCenter" or "screenAttachment"
  local ok, x, y = Host.call("models", method, side, tag or 0x64)
  if not ok then
    state.supported = false
    state.lastError = tostring(x)
    return nil
  end
  state.supported = true
  if type(x) ~= "number" or type(y) ~= "number" then
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
  local ok, a, b = V.require("BattleHost").call(
    "models", "attachmentTags", side, moveId, stage)
  if not ok then return nil end
  return tonumber(a), tonumber(b)
end

function Attachment.moveSync(companion, side, moveId)
  local ok, row = V.require("BattleHost").call(
    "models", "moveSync", side, moveId)
  if not ok or type(row) ~= "table" then return nil end
  return row
end

function Attachment.synchronizeMove(companion, side, moveId, effectTick)
  local ok, value = V.require("BattleHost").call(
    "models", "synchronizeMove", side, moveId, effectTick)
  return ok and value == true
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

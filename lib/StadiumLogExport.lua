-- Sandbox-safe diagnostic snapshot action. The log remains available through
-- mod.storage and mod.exports; mods cannot write an arbitrary desktop path.

local V = ...
local Export = {}
local last = { state = "SAVE", message = nil }

local function result(state, message)
  last = { state = state, message = message }
  return state == "SAVED", message
end

function Export.available()
  return V.mod and V.mod.storage ~= nil
end

function Export.status()
  return last.state, last.message
end

function Export.export()
  if not Export.available() then
    return result("UNAVAILABLE", "Mod storage is unavailable.")
  end
  local ok, code, message = V.log:flush()
  if not ok then
    return result("FAILED", tostring(message or code or "Could not save diagnostics."))
  end
  return result("SAVED", "Diagnostic snapshot saved for this playthrough.")
end

function Export.row()
  return {
    id = "STADIUM_BATTLE_FX:exportLog", label = "SAVE DIAGNOSTIC SNAPSHOT",
    value = function()
      if not Export.available() then return "UNAVAILABLE" end
      return last.state
    end,
    step = function() return Export.export() end,
  }
end

return Export

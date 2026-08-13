-- API-1 adapter around StadiumBattleFX's extracted Stadium model runtime.

local V = ...
local Models = V.require("StadiumModels")
local Install = V.require("StadiumInstall")

-- The built-in model runtime is drawn inside StadiumRender. External model
-- providers own their renderer; forcing Stadium's shader over them breaks
-- Dramaless's native cards inside its active Voxel3D pass.
local Provider = { id = "STADIUM_BATTLE_FX:models", hostRender = true }

function Provider:available()
  return Install.available() and Models.enabled()
end

function Provider:install() return Models.install() end
function Provider:begin(context, arena) return Models.begin(arena or (context and context.arena)) end
function Provider:finish() return Models.finish() end
function Provider:update(context, dt)
  return Models.update(dt, context and context.battle, context and context.groundY or 0)
end
function Provider:covers(context, side) return Models.covers(context and context.battle, side) end
function Provider:drawWorld(context, pull) return Models.draw(pull) end
function Provider:cast(context, shadowMap) return Models.cast(shadowMap) end
function Provider:attachment(context, side, tag) return Models.attachment(side, tag) end
function Provider:screenAttachment(context, side, tag)
  return Models.screenAttachment(side, tag)
end
function Provider:attachmentTags(context, side, moveId, stage)
  return Models.attachmentTags(side, moveId, stage)
end
function Provider:moveSync(context, side, moveId) return Models.moveSync(side, moveId) end
function Provider:synchronizeMove(context, side, moveId, effectTick)
  return Models.synchronizeMove(side, moveId, effectTick)
end
function Provider:center(context, side) return Models.center(side) end
function Provider:screenCenter(context, side) return Models.screenCenter(side) end
function Provider:showing(context, side) return Models.showing(side) end
function Provider:footprint(context, side) return Models.footprint(side) end
function Provider:hit(context, side, effectiveness) return Models.hit(side, effectiveness) end
function Provider:faint(context, side, disposition) return Models.faint(side, disposition) end
function Provider:invalidate() return Models.invalidate() end

return Provider

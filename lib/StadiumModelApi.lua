-- Public, versioned Stadium model actor service.
--
-- Consumers acquire isolated actors instead of importing StadiumPack,
-- StadiumMon, StadiumRig, StadiumRender, or Stadium 2 cache internals. The
-- service owns source resolution and renderer cleanup; the consumer owns each
-- returned actor and must release it.

local V = ...
local Pack = V.require("StadiumPack")
local Mon = V.require("StadiumMon")
local Render = V.require("StadiumRender")
local Install = V.require("StadiumInstall")
local Stadium2 = V.require("stadium2/model_pack_api")
local Stadium2Importer = V.require("stadium2/importer")

local Api = {
  version = 1,
  speciesCount = 151,
  STADIUM1 = "stadium1",
  STADIUM2 = "stadium2",
  SELECTED = "selected",
}

local Actor = {}
Actor.__index = Actor

local function speciesNumber(value)
  local species = math.floor(tonumber(value) or 0)
  if species < 1 or species > Api.speciesCount then return nil end
  return species
end

local function variantName(value)
  return value == "shiny" and "shiny" or "normal"
end

local function sourceName(value)
  if value == Api.STADIUM1 or value == Api.STADIUM2
      or value == Api.SELECTED then return value end
  return nil
end

local function stadium2Available()
  local ok, available = pcall(Stadium2Importer.available, Api.speciesCount)
  return ok and available and true or false
end

function Api.sources()
  return {
    { id = Api.STADIUM1, label = "POKEMON STADIUM" },
    { id = Api.STADIUM2, label = "POKEMON STADIUM 2" },
    { id = Api.SELECTED, label = "SBFX SELECTED MODEL PACK" },
  }
end

function Api.available(source, species)
  source = sourceName(source)
  if not source then return false end
  if species ~= nil then
    species = speciesNumber(species)
    if not species then return false end
  end
  local ok, installed = pcall(Install.available)
  if not (ok and installed) then return false end
  if species then
    local packOk, present = pcall(Pack.available, species)
    if not (packOk and present) then return false end
  end
  if source == Api.STADIUM2 then return stadium2Available() end
  return true
end

local function modelFor(source, species, variant)
  if source == Api.SELECTED then return Pack.load(species, variant) end
  local base = Pack.loadBase(species)
  if not base or source == Api.STADIUM1 then return base end
  if not stadium2Available() then return nil, "Stadium 2 model pack unavailable" end
  return Stadium2.hybridModel(species, variant, base)
end

function Api.acquire(source, species, variant, options)
  source = sourceName(source)
  species = speciesNumber(species)
  variant = variantName(variant)
  if not source then return nil, "unknown Stadium model source" end
  if not species then return nil, "species out of Gen 1 range" end
  local ok, model, err = pcall(modelFor, source, species, variant)
  if not ok then return nil, tostring(model) end
  if not model then return nil, tostring(err or "Stadium model unavailable") end
  local side = type(options) == "table" and options.side or nil
  if side ~= "player" and side ~= "enemy" then side = "external" end
  local mon = Mon.new(side)
  if not mon:setModel(species, variant, model) then
    mon:release()
    return nil, "Stadium model could not create a renderable rig"
  end
  return setmetatable({
    source = source,
    species = species,
    variant = variant,
    _mon = mon,
    _dirty = true,
    _released = false,
  }, Actor)
end

local function live(self)
  return getmetatable(self) == Actor and not self._released and self._mon
end

function Actor:update(dt)
  local mon = live(self)
  if not mon then return false end
  mon:update(math.max(0, tonumber(dt) or 0))
  self._dirty = true
  return true
end

function Actor:play(state)
  local mon = live(self)
  if not mon then return false end
  local accepted = mon:request(tostring(state or "idle")) and true or false
  if accepted then self._dirty = true end
  return accepted
end

function Actor:attack(moveId)
  local mon = live(self)
  if not mon then return false end
  local accepted = mon:attack(math.floor(tonumber(moveId) or 0)) and true or false
  if accepted then self._dirty = true end
  return accepted
end

function Actor:seekAttack(moveId, effectTick)
  local mon = live(self)
  if not mon then return false end
  local accepted = mon:seekAttack(math.floor(tonumber(moveId) or 0), effectTick)
    and true or false
  if accepted then self._dirty = true end
  return accepted
end

function Actor:hit()
  local mon = live(self)
  if not mon then return false end
  local accepted = mon:request("hit") and true or false
  if accepted then self._dirty = true end
  return accepted
end

function Actor:faint(disposition)
  local mon = live(self)
  if not mon then return false end
  local accepted = mon:faint(disposition) and true or false
  if accepted then self._dirty = true end
  return accepted
end

function Actor:sync(moveId)
  local mon = live(self)
  return mon and mon:sync(math.floor(tonumber(moveId) or 0)) or nil
end

function Actor:matrix(x, groundY, z, faceX, faceZ)
  local mon = live(self)
  return mon and mon:matrix(tonumber(x) or 0, tonumber(groundY) or 0,
    tonumber(z) or 0, tonumber(faceX), tonumber(faceZ)) or nil
end

function Actor:worldHeight()
  local mon = live(self)
  return mon and mon:worldHeight() or nil
end

function Actor:worldRadius()
  local mon = live(self)
  return mon and mon:worldRadius() or nil
end

function Actor:build()
  local mon = live(self)
  if not mon then return false end
  local built = mon:build() and true or false
  if built then self._dirty = false end
  return built
end

function Actor:draw(matrix, pull)
  local mon = live(self)
  if not (mon and mon.rig and matrix) then return false end
  if self._dirty and not self:build() then return false end
  mon.rig:draw(matrix, tonumber(pull) or 0)
  return true
end

function Actor:cast(shadowMap, matrix)
  local mon = live(self)
  if not (mon and mon.rig and shadowMap and matrix) then return false end
  if self._dirty and not self:build() then return false end
  mon.rig:caster(shadowMap, matrix)
  return true
end

function Actor:attachment(tag)
  local mon = live(self)
  local bone = math.floor(tonumber(tag) or -1)
  if not (mon and mon.rig and bone >= 0 and bone ~= 0xFF) then return nil end
  return mon.rig:attachment(bone)
end

function Actor:moveAttachmentTags(moveId)
  local mon = live(self)
  moveId = math.floor(tonumber(moveId) or 0)
  local model = mon and mon.model
  if not (model and moveId >= 1 and moveId <= 165) then return nil end
  return model.moveAttachA and model.moveAttachA[moveId] or nil,
         model.moveAttachB and model.moveAttachB[moveId] or nil
end

function Actor:release()
  if self._released then return false end
  self._released = true
  local ok = true
  if self._mon then ok = pcall(self._mon.release, self._mon) end
  self._mon = nil
  return ok and true or false
end

local function graphicsState()
  local g = love and love.graphics
  if not g then return nil end
  local state = {}
  local function get(fn)
    if type(fn) ~= "function" then return nil end
    local values = { pcall(fn) }
    if not values[1] then return nil end
    table.remove(values, 1)
    return unpack(values)
  end
  state.shader = get(g.getShader)
  state.depth, state.depthWrite = get(g.getDepthMode)
  state.cull = get(g.getMeshCullMode)
  state.blend, state.alpha = get(g.getBlendMode)
  local r, green, b, a = get(g.getColor)
  if r ~= nil then state.color = { r, green, b, a } end
  return state
end

local function restoreGraphics(state)
  local g = love and love.graphics
  if not (g and state) then return end
  if g.setShader then pcall(g.setShader, state.shader) end
  if g.setDepthMode and state.depth then
    pcall(g.setDepthMode, state.depth, state.depthWrite)
  end
  if g.setMeshCullMode and state.cull then pcall(g.setMeshCullMode, state.cull) end
  if g.setBlendMode and state.blend then
    pcall(g.setBlendMode, state.blend, state.alpha)
  end
  if g.setColor and state.color then pcall(g.setColor, unpack(state.color)) end
end

function Api.withRenderer(vp, callback, ...)
  if type(vp) ~= "table" then return false, "row-major view-projection required" end
  if type(callback) ~= "function" then return false, "render callback required" end
  local state = graphicsState()
  local beginOk, began = pcall(Render.begin, vp)
  if not (beginOk and began) then
    restoreGraphics(state)
    return false, beginOk and "Stadium renderer unavailable" or tostring(began)
  end
  local results = { pcall(callback, ...) }
  local finishOk, finishErr = pcall(Render.finish)
  restoreGraphics(state)
  if not results[1] then return false, results[2] end
  if not finishOk then return false, finishErr end
  table.remove(results, 1)
  return true, unpack(results)
end

function Api.draw(actor, vp, matrix, pull)
  if getmetatable(actor) ~= Actor then return false, "Stadium actor required" end
  return Api.withRenderer(vp, function()
    assert(actor:draw(matrix, pull), "Stadium actor draw failed")
    return true
  end)
end

Api.Actor = Actor

return Api

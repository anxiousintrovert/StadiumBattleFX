local loader = love and love.filesystem and love.filesystem.load or loadfile

local base = { id = "stadium1", moveAttachA = { [84] = 0x64 },
  moveAttachB = { [84] = 0xFF } }
local selected = { id = "selected", moveAttachA = {}, moveAttachB = {} }
local hybrid = { id = "stadium2", moveAttachA = {}, moveAttachB = {} }
local released, draws, casts = 0, 0, 0
local began, finished = 0, 0

local Pack = {
  available = function(species) return species == 25 end,
  loadBase = function(species) return species == 25 and base or nil end,
  load = function(species) return species == 25 and selected or nil end,
}
local function newMon(side)
  local mon = { side = side, state = "idle", time = 0 }
  mon.rig = {
    release = function() released = released + 1 end,
    draw = function(_, matrix, pull)
      assert(matrix.id == "matrix" and pull == 3)
      draws = draws + 1
    end,
    caster = function(_, shadow, matrix)
      assert(shadow.id == "shadow" and matrix.id == "matrix")
      casts = casts + 1
    end,
    attachment = function(_, tag) return tag, tag + 1, tag + 2 end,
  }
  function mon:setModel(species, variant, model)
    self.species, self.variant, self.model = species, variant, model
    return true
  end
  function mon:update(dt) self.time = self.time + dt end
  function mon:request(state) self.state = state return true end
  function mon:attack(move) self.move = move return move == 84 end
  function mon:seekAttack(move, tick) return move == 84 and tick == 12 end
  function mon:faint(disposition) self.disposition = disposition return true end
  function mon:sync(move) return move == 84 and 7 or nil, { move } end
  function mon:matrix() return { id = "matrix" } end
  function mon:worldHeight() return 24 end
  function mon:worldRadius() return 8 end
  function mon:build() return true end
  function mon:release() self.rig:release() end
  return mon
end

local shader, depth, depthWrite = "caller-shader", "less", false
local cull, blend, alpha = "back", "add", "alphamultiply"
local color = { 0.1, 0.2, 0.3, 0.4 }
love = love or {}
love.graphics = {
  getShader = function() return shader end,
  setShader = function(value) shader = value end,
  getDepthMode = function() return depth, depthWrite end,
  setDepthMode = function(a, b) depth, depthWrite = a, b end,
  getMeshCullMode = function() return cull end,
  setMeshCullMode = function(value) cull = value end,
  getBlendMode = function() return blend, alpha end,
  setBlendMode = function(a, b) blend, alpha = a, b end,
  getColor = function() return unpack(color) end,
  setColor = function(...) color = { ... } end,
}

local Render = {
  begin = function(vp)
    assert(vp.id == "vp")
    began = began + 1
    shader, depth, depthWrite, cull, blend = "stadium", "lequal", true, "none", "alpha"
    return true
  end,
  finish = function()
    finished = finished + 1
    shader, depth, depthWrite = nil, nil, nil
  end,
}

local modules = {
  StadiumPack = Pack,
  StadiumMon = { new = newMon },
  StadiumRender = Render,
  StadiumInstall = { available = function() return true end },
  ["stadium2/model_pack_api"] = {
    hybridModel = function(species, variant, gotBase)
      assert(species == 25 and variant == "shiny" and gotBase == base)
      return hybrid
    end,
  },
  ["stadium2/importer"] = { available = function(count) return count == 151 end },
}
local Api = assert(loader("lib/StadiumModelApi.lua"))({
  require = function(name) return assert(modules[name], name) end,
})

assert(Api.version == 1 and Api.speciesCount == 151)
local sources = Api.sources()
assert(#sources == 3 and sources[1].id == "stadium1"
    and sources[2].id == "stadium2" and sources[3].id == "selected")
sources[1].id = "mutated"
assert(Api.sources()[1].id == "stadium1", "source metadata was not copied")
assert(Api.available("stadium1", 25) and Api.available("stadium2", 25))
assert(not Api.available("stadium1", 0) and not Api.available("unknown", 25))

local actor = assert(Api.acquire(Api.STADIUM2, 25, "shiny", { side = "enemy" }))
assert(actor.source == "stadium2" and actor.variant == "shiny")
assert(actor._mon.model == hybrid and actor._mon.side == "enemy")
assert(actor:update(0.5) and actor:attack(84) and actor:seekAttack(84, 12))
assert(actor:hit() and actor:faint("collapse"))
assert(actor:worldHeight() == 24 and actor:worldRadius() == 8)
local matrix = actor:matrix(1, 2, 3, 0, 1)
assert(actor:draw(matrix, 3) and draws == 1)
assert(actor:cast({ id = "shadow" }, matrix) and casts == 1)
local x, y, z = actor:attachment(0x64)
assert(x == 0x64 and y == 0x65 and z == 0x66)

local ok, answer = Api.withRenderer({ id = "vp" }, function() return "done" end)
assert(ok and answer == "done" and began == 1 and finished == 1)
assert(shader == "caller-shader" and depth == "less" and depthWrite == false
    and cull == "back" and blend == "add" and color[1] == 0.1,
  "scoped Stadium renderer did not restore caller graphics state")
local failed, err = Api.withRenderer({ id = "vp" }, function() error("expected") end)
assert(not failed and tostring(err):match("expected") and began == 2 and finished == 2)
assert(shader == "caller-shader", "error path did not restore the caller shader")

assert(actor:release() and not actor:release() and released == 1)
assert(not actor:update(1) and not actor:draw(matrix, 3))

local selectedActor = assert(Api.acquire(Api.SELECTED, 25, "normal"))
assert(selectedActor._mon.model == selected)
selectedActor:release()
local stadium1Actor = assert(Api.acquire(Api.STADIUM1, 25, "normal"))
assert(stadium1Actor._mon.model == base)
stadium1Actor:release()

print("ok public Stadium model actor API")

local loader = love and love.filesystem and love.filesystem.load or loadfile

local culls = {}
local shader = {
  send = function() end,
}

love = {
  graphics = {
    newShader = function() return shader end,
    setDepthMode = function() end,
    setBlendMode = function() end,
    setColor = function() end,
    setShader = function() end,
    setMeshCullMode = function(mode) culls[#culls + 1] = mode end,
  },
}

local Render = assert(loader("lib/StadiumRender.lua"))({
  require = function(name)
    assert(name == "Mat4")
    return assert(loader("lib/Mat4.lua"))({})
  end,
})

assert(Render.begin({ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }))
Render.cull(true)
Render.cull(false)
Render.finish()

assert(culls[1] == "none", "native pass must begin unculled")
assert(culls[2] == "back", "native back-cull state was not applied")
assert(culls[3] == "none", "two-sided native material was culled")

print("ok native Stadium cull material state")

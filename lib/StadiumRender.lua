-- Narrow renderer for Stadium battle-model meshes.
--
-- Deliberately not a copy of Dramaless Voxel3D: Stadium models need textured
-- skinned meshes, depth testing, additive materials and row-major matrices.
-- They do not need voxel grids, terrain, day/night, glass masks, water,
-- world-curvature, shadows, or VR.

local V = ...
local Mat4 = V.require("Mat4")

local Render = {
  FORMAT = {
    { "VertexPosition", "float", 3 },
    { "VertexTexCoord", "float", 2 },
    { "VertexShade", "float", 1 },
  },
}

local shader, active = nil, false
local IDENTITY = Mat4.identity()

local VERTEX = [[
uniform mat4 vp;
uniform mat4 model;
attribute float VertexShade;
varying float shade;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  shade = VertexShade;
  return vp * model * vertex_position;
}
]]

local PIXEL = [[
varying float shade;
vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
  vec4 texel = Texel(texture, uv);
  if (texel.a < 0.01) discard;
  return vec4(texel.rgb * max(shade, 0.12), texel.a) * color;
}
]]

function Render.available()
  return love and love.graphics and type(love.graphics.newShader) == "function"
end

function Render.newMesh(first, second, ...)
  if not Render.available() then return nil, "graphics unavailable" end
  if first == Render.FORMAT then
    return love.graphics.newMesh(first, second, ...)
  end
  local mesh = love.graphics.newMesh(Render.FORMAT, first, "triangles", "static")
  if type(second) == "table" and #second > 0 then mesh:setVertexMap(second) end
  return mesh
end

function Render.begin(vp)
  if not (Render.available() and vp) then return false end
  if not shader then
    local ok, made = pcall(love.graphics.newShader, VERTEX, PIXEL)
    if not ok then
      if V.log then V.log:error("Stadium model shader failed: %s", tostring(made)) end
      return false
    end
    shader = made
  end
  active = true
  love.graphics.setDepthMode("lequal", true)
  love.graphics.setMeshCullMode("none")
  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setShader(shader)
  pcall(shader.send, shader, "vp", "row", vp)
  return true
end

function Render.finish()
  if not active then return end
  active = false
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setColor(1, 1, 1, 1)
end

function Render.draw(mesh, texture, model)
  if not (active and shader and mesh) then return end
  if texture then mesh:setTexture(texture) end
  pcall(shader.send, shader, "model", "row", model or IDENTITY)
  love.graphics.draw(mesh)
end

function Render.blend(mode)
  if not active then return end
  if mode == "add" then
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setDepthMode("lequal", false)
  else
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setDepthMode("lequal", true)
  end
end

-- Compatibility no-ops for the extracted StadiumRig. These features belonged
-- to Dramaless's voxel-world shader and intentionally do not exist here.
function Render.seams() end
function Render.glass() end

function Render.invalidate()
  shader, active = nil, false
end

return Render

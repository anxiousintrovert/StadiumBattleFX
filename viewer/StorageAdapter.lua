-- Developer-viewer adapter. This file is not shipped in the mod package.

local Adapter = { records = {} }

function Adapter.read(key) return Adapter.records[key] end
function Adapter.write(key, value) Adapter.records[key] = value; return true end
function Adapter.bytes(key)
  local value = Adapter.records[key]
  return type(value) == "table" and value.bytes or nil
end
function Adapter.writeBytes(key, bytes, fields)
  local value = fields or {}
  value.bytes = bytes
  return Adapter.write(key, value)
end
function Adapter.bundled(path)
  local ok, bytes = pcall(love.filesystem.read, path)
  return ok and bytes or nil
end
function Adapter.bundledRom()
  for _, path in ipairs({
    "baseroms/baserom.z64", "baseroms/baserom.n64", "baseroms/baserom.v64",
    "baseroms/Pokemon Stadium (USA).z64",
  }) do
    if Adapter.bundled(path) then return path, Adapter.bundled(path) end
  end
end
function Adapter.game() return {} end
function Adapter.active() return true end
function Adapter.setGame(game) return game end

return Adapter

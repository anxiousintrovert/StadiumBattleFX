-- Persistent, player-exportable diagnostics for StadiumBattleFX.
-- Entries are deliberately event based: no per-frame writes or Pokemon data.

local V = ...
local Log = {}
Log.__index = Log

local PATH = "stadium_battle_fx/stadium_battle_fx.log"
local MAX_LINES = 1200

local function clean(value)
  return tostring(value or "nil"):gsub("[\r\n\t]+", " "):gsub("%s+", " ")
end

local function now()
  if os and os.date then return os.date("!%Y-%m-%dT%H:%M:%SZ") end
  return "runtime"
end

local function format(message, ...)
  if select("#", ...) == 0 then return clean(message) end
  local ok, value = pcall(string.format, tostring(message), ...)
  return clean(ok and value or message)
end

function Log.new(host)
  local self = setmetatable({ host = host, lines = {} }, Log)
  local fs = love and love.filesystem
  if fs and fs.read and fs.getInfo and fs.getInfo(PATH, "file") then
    local ok, text = pcall(fs.read, PATH)
    if ok and type(text) == "string" then
      for line in text:gmatch("[^\r\n]+") do self.lines[#self.lines + 1] = line end
    end
  end
  self:info("session started; StadiumBattleFX %s", tostring(V.mod.exports.version or "unknown"))
  return self
end

function Log:flush()
  local fs = love and love.filesystem
  if not (fs and fs.createDirectory and fs.write) then return false end
  if fs.createDirectory("stadium_battle_fx") == false then return false end
  return pcall(fs.write, PATH, table.concat(self.lines, "\n") .. "\n")
end

function Log:record(level, message, ...)
  local line = ("%s [%s] %s"):format(now(), level, format(message, ...))
  self.lines[#self.lines + 1] = line
  while #self.lines > MAX_LINES do table.remove(self.lines, 1) end
  self:flush()
  local fn = self.host and self.host[level:lower()]
  if type(fn) == "function" then pcall(fn, self.host, "%s", line) end
  return line
end

function Log:info(message, ...) return self:record("INFO", message, ...) end
function Log:warn(message, ...) return self:record("WARN", message, ...) end
function Log:error(message, ...) return self:record("ERROR", message, ...) end

function Log:contents()
  return table.concat(self.lines, "\n") .. "\n"
end

function Log:stage(path)
  local fs = love and love.filesystem
  if not (fs and fs.write) then return false, "filesystem unavailable" end
  local ok, wrote = pcall(fs.write, path, self:contents())
  if not (ok and wrote ~= false) then return false, "could not stage log export" end
  return true
end

return Log

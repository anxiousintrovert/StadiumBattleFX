-- Persistent, player-exportable diagnostics for StadiumBattleFX.
-- Entries are deliberately event based: no per-frame writes or Pokemon data.

local V = ...
local Storage = V.require("ModStorage")
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
  self:info("session started; StadiumBattleFX %s", tostring(V.mod.exports.version or "unknown"))
  self:event("runtime", "environment", {
    api = V.mod and V.mod.api or "unknown",
  })
  return self
end

function Log:loadStored()
  if self.loaded or not Storage.game() then return self.loaded end
  local record = Storage.read("diagnostics/log")
  if type(record) == "table" and type(record.lines) == "table" then
    local current = self.lines
    self.lines = {}
    for _, line in ipairs(record.lines) do
      if type(line) == "string" then self.lines[#self.lines + 1] = line end
    end
    for _, line in ipairs(current) do self.lines[#self.lines + 1] = line end
  end
  self.loaded = true
  return true
end

function Log:flush()
  if not self:loadStored() then return false end
  return Storage.write("diagnostics/log", { format = 1, lines = self.lines })
end

function Log:record(level, message, ...)
  self:loadStored()
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

-- Stable structured line for cross-mod diagnostics. Keys are sorted so logs
-- from two machines can be diffed and parsed by a developer or an LLM.
function Log:event(scope, name, fields)
  local parts = {}
  for key, value in pairs(type(fields) == "table" and fields or {}) do
    parts[#parts + 1] = clean(key) .. "=" .. clean(value)
  end
  table.sort(parts)
  local suffix = #parts > 0 and (" " .. table.concat(parts, " ")) or ""
  return self:info("[%s] %s%s", clean(scope), clean(name), suffix)
end

function Log:scope(scope)
  local parent = self
  return {
    info = function(_, message, ...) return parent:info("[%s] " .. message, scope, ...) end,
    warn = function(_, message, ...) return parent:warn("[%s] " .. message, scope, ...) end,
    error = function(_, message, ...) return parent:error("[%s] " .. message, scope, ...) end,
    event = function(_, name, fields) return parent:event(scope, name, fields) end,
  }
end

function Log:contents()
  return table.concat(self.lines, "\n") .. "\n"
end

function Log:stage(path)
  return self:flush()
end

return Log

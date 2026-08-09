-- Player-owned Pokemon Stadium ROM importer for the effect cache.
-- Desktop uses the host OS picker; Android uses Gen1Recomp's SAF bridge.

local V = ...
local Assets = V.require("StadiumAssets")
local CacheScreen = V.require("EffectCacheScreen")
local Picker = {}

local PICKED = "picked_stadium.z64"

local function osName()
  local ok, value = pcall(function() return love.system.getOS() end)
  return ok and value or nil
end

local function nativePicker()
  return love and love.system and type(love.system.pickFile) == "function"
end

function Picker.available()
  if osName() == "Android" then return nativePicker() end
  return io and io.popen and io.open and true or false
end

local function commandOutput(command)
  local ok, pipe = pcall(io.popen, command)
  if not (ok and pipe) then return nil end
  local readOk, value = pcall(pipe.read, pipe, "*a")
  pcall(pipe.close, pipe)
  value = readOk and type(value) == "string" and value:gsub("^%s+", ""):gsub("%s+$", "") or nil
  return value ~= "" and value or nil
end

local function chooseDesktop()
  local name = osName()
  if name == "Windows" then
    return commandOutput([[powershell -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms;$d=New-Object System.Windows.Forms.OpenFileDialog;$d.Title='Choose Pokemon Stadium (US) 1.0';$d.Filter='Nintendo 64 ROM (*.z64;*.n64;*.v64)|*.z64;*.n64;*.v64';if($d.ShowDialog() -eq 'OK'){[Console]::OutputEncoding=[Text.Encoding]::UTF8;[Console]::Write($d.FileName)}"]])
  elseif name == "OS X" then
    return commandOutput([[osascript -e 'POSIX path of (choose file with prompt "Choose Pokemon Stadium (US) 1.0" of type {"z64", "n64", "v64"})' 2>/dev/null]])
  elseif name == "Linux" then
    return commandOutput([[zenity --file-selection --title="Choose Pokemon Stadium (US) 1.0" --file-filter="Nintendo 64 ROM | *.z64 *.n64 *.v64" 2>/dev/null]])
  end
end

local function nameFor(path)
  local name = type(path) == "string" and path:match("[^/\\]+$")
  if not (name and name:lower():match("%.[znv]64$")) then
    return nil, "choose a .z64, .n64, or .v64 ROM"
  end
  return name:gsub("[%z\1-\31]", "_"):gsub("[<>:\"|?*]", "_")
end

local function store(bytes, source)
  local f = love and love.filesystem
  local _, err = nameFor(source)
  if err then return nil, err end
  local valid, validationErr = Assets.validateRom(bytes)
  if not valid then return nil, validationErr end
  if not (f and f.createDirectory and f.write) then return nil, "filesystem unavailable" end
  if f.createDirectory("baseroms") == false then return nil, "could not create baseroms" end
  -- This is the preferred discovery name, so importing always replaces the
  -- exact ROM later cache refreshes will use (even beside older loose files).
  local path = "baseroms/baserom.z64"
  if f.write(path, bytes) == false then return nil, "could not save ROM" end
  return path
end

local function start(game, bytes, source)
  local path, err = store(bytes, source)
  if not path then return nil, err end
  if game and game.stack then game.stack:push(CacheScreen.new(game, true)) end
  return true
end

function Picker.import(game)
  if osName() == "Android" then
    if not nativePicker() then return false end
    local ok, shown = pcall(love.system.pickFile, "stadium")
    return ok and shown or false
  end
  if not Picker.available() then return false end
  local path = chooseDesktop()
  if not path then return false end
  local file = io.open(path, "rb")
  if not file then return false end
  local bytes = file:read("*a")
  file:close()
  return start(game, bytes, path)
end

-- Android returns from its SAF activity later.  The platform bridge writes
-- this file in LOVE's writable root for the dedicated "stadium" request.
function Picker.poll(game)
  local f = love and love.filesystem
  if not (f and f.getInfo and f.read) then return false end
  if not f.getInfo(PICKED, "file") then return false end
  local bytes = f.read(PICKED)
  pcall(f.remove, PICKED)
  if type(bytes) ~= "string" or #bytes == 0 then return false end
  return start(game, bytes, PICKED) and true or false
end

function Picker.importRow()
  return {
    id = "STADIUM_BATTLE_FX:stadiumRom", label = "STADIUM ROM",
    value = function()
      return Assets.findRom() and "REPLACE" or "IMPORT"
    end,
    step = function(game) Picker.import(game); return true end,
  }
end

function Picker.refreshRow()
  return {
    id = "STADIUM_BATTLE_FX:refreshCache", label = "REFRESH FX CACHE",
    value = function()
      local state = Assets.status().state
      return state == "building" and "BUILDING" or "REBUILD"
    end,
    step = function(game)
      if game and game.stack then game.stack:push(CacheScreen.new(game, true)) end
      return true
    end,
  }
end

return Picker

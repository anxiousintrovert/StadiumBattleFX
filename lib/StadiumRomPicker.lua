-- Player-owned Pokemon Stadium ROM importer. The native Android picker writes
-- its result to LOVE's writable root; desktop pickers return a host path. Both
-- paths validate the same cartridge and copy it into this installed mod's
-- baseroms folder, so later reads still go through mod:read.

local V = ...
local Assets = V.require("StadiumAssets")
local ArenaAssets = V.require("StadiumArenaAssets")
local TrainerPortraits = V.require("StadiumTrainerPortraits")
local CacheScreen = V.require("EffectCacheScreen")
local Picker = {}

local PICKED = "picked_stadium.z64"
local LEGACY_PICKED = "picked_rom.gb"
local BASEROM = "baseroms/baserom.z64"
local pickerPending = false
local stagedRetry = nil

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
  value = readOk and type(value) == "string"
    and value:gsub("^%s+", ""):gsub("%s+$", "") or nil
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

local function validName(path, staged)
  local name = type(path) == "string" and path:match("[^/\\]+$")
  local lower = name and name:lower()
  if not (lower and (lower:match("%.[znv]64$")
      or (staged and lower == LEGACY_PICKED))) then
    return nil, "choose a .z64, .n64, or .v64 ROM"
  end
  return true
end

local function installedPath(relative)
  local root = V.mod and V.mod.path
  if type(root) ~= "string" or root == "" then
    return nil, "installed mod path unavailable"
  end
  root = root:gsub("\\", "/"):gsub("/+$", "")
  if not root:match("^mods/[^/]+$") or root:find("..", 1, true) then
    return nil, "installed mod path is invalid"
  end
  return root .. "/" .. relative
end

local function store(bytes, source, staged)
  local f = love and love.filesystem
  local _, nameErr = validName(source, staged)
  if nameErr then return nil, nameErr end
  local valid, validationErr = Assets.validateRom(bytes)
  if not valid then return nil, validationErr end
  if not (f and f.createDirectory and f.write) then
    return nil, "filesystem unavailable"
  end

  local dir, dirErr = installedPath("baseroms")
  if not dir then return nil, dirErr end
  local path, pathErr = installedPath(BASEROM)
  if not path then return nil, pathErr end
  if f.createDirectory(dir) == false then
    return nil, "could not create the mod baseroms folder"
  end
  local wrote, writeErr = f.write(path, bytes)
  if wrote == false or wrote == nil then
    return nil, "could not save ROM: " .. tostring(writeErr or "write failed")
  end
  V.log:info("[rom] imported verified Stadium ROM into %s", path)
  return path
end

local function start(game, bytes, source, staged)
  local path, err = store(bytes, source, staged)
  if not path then
    V.log:warn("[rom] import failed: %s", tostring(err))
    return nil, err
  end
  if game and game.stack then game.stack:push(CacheScreen.new(game, true)) end
  return true
end

function Picker.import(game)
  if osName() == "Android" then
    if not nativePicker() then return false end
    local ok, shown = pcall(love.system.pickFile, "stadium")
    pickerPending = ok and shown or false
    return pickerPending
  end
  if not Picker.available() then return false end
  local path = chooseDesktop()
  if not path then return false end
  local file = io.open(path, "rb")
  if not file then return false end
  local bytes = file:read("*a")
  file:close()
  return start(game, bytes, path) and true or false
end

-- Android's Storage Access Framework returns asynchronously. The native
-- "stadium" picker stages its result under this dedicated filename; consume
-- it once, copy it into mods/STADIUM_BATTLE_FX/baseroms, then rebuild caches.
function Picker.poll(game)
  local f = love and love.filesystem
  if not (f and f.getInfo and f.read) then return false end
  local staged = stagedRetry or (f.getInfo(PICKED, "file") and PICKED or nil)
  -- Gen1Recomp builds predating the dedicated Stadium destination map an
  -- unknown picker kind to picked_rom.gb. Only consume that legacy name while
  -- this module has an outstanding Stadium request; cartridge validation then
  -- prevents a Game Boy ROM from ever replacing the installed Stadium ROM.
  if not staged and pickerPending and f.getInfo(LEGACY_PICKED, "file") then
    staged = LEGACY_PICKED
  end
  if not staged then return false end
  pickerPending = false
  local bytes = f.read(staged)
  if type(bytes) ~= "string" or #bytes == 0 then
    stagedRetry = nil
    return false
  end
  local ok = start(game, bytes, staged, true) and true or false
  -- Keep a valid staged pick until after it has safely landed in the mod. If
  -- installation fails (read-only portable tree, full disk), the player can
  -- retry after fixing the destination without reopening the document picker.
  -- Rejected files are removed so they cannot be re-hashed every frame.
  if f.remove then
    local valid = ok or Assets.validateRom(bytes)
    if ok or not valid then
      stagedRetry = nil
      pcall(f.remove, staged)
    else
      stagedRetry = staged
    end
  end
  return ok
end

function Picker.importRow()
  return {
    id = "STADIUM_BATTLE_FX:stadiumRom", label = "STADIUM ROM",
    value = function() return Assets.findRom() and "REPLACE" or "IMPORT" end,
    step = function(game) Picker.import(game); return true end,
  }
end

function Picker.refreshRow()
  return {
    id = "STADIUM_BATTLE_FX:refreshCache", label = "REFRESH FX CACHE",
    value = function()
      local effects = Assets.status().state
      local arenas = ArenaAssets.status().state
      local trainers = TrainerPortraits.status().state
      return (effects == "building" or arenas == "building"
        or trainers == "building") and "BUILDING" or "REBUILD"
    end,
    step = function(game)
      if game and game.stack then game.stack:push(CacheScreen.new(game, true)) end
      return true
    end,
  }
end

Picker._store = store
Picker._installedPath = installedPath

return Picker

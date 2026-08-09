-- Platform export action for the StadiumBattleFX diagnostic log.

local V = ...
local Logger = V.require("StadiumLog")
local Export = {}
local STAGED = "pending_stadium_battle_fx_log.txt"
local SUGGESTED = "StadiumBattleFX-log.txt"

local function osName()
  local ok, value = pcall(function() return love.system.getOS() end)
  return ok and value or nil
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
  if osName() == "Windows" then
    return commandOutput([[powershell -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms;$d=New-Object System.Windows.Forms.SaveFileDialog;$d.Title='Export StadiumBattleFX diagnostic log';$d.FileName='StadiumBattleFX-log.txt';$d.Filter='Text log (*.txt)|*.txt';if($d.ShowDialog() -eq 'OK'){[Console]::OutputEncoding=[Text.Encoding]::UTF8;[Console]::Write($d.FileName)}"]])
  elseif osName() == "OS X" then
    return commandOutput([[osascript -e 'POSIX path of (choose file name with prompt "Export StadiumBattleFX diagnostic log" default name "StadiumBattleFX-log.txt")' 2>/dev/null]])
  elseif osName() == "Linux" then
    return commandOutput([[zenity --file-selection --save --confirm-overwrite --filename="StadiumBattleFX-log.txt" --title="Export StadiumBattleFX diagnostic log" 2>/dev/null]])
  end
end

function Export.available()
  if osName() == "Android" then
    return love and love.system and type(love.system.exportFile) == "function"
  end
  return io and io.open and io.popen and true or false
end

function Export.export()
  local logger = V.log
  if osName() == "Android" then
    if not Export.available() then
      logger:warn("log export unavailable: this Gen1Recomp build lacks love.system.exportFile")
      return false
    end
    local ok, err = logger:stage(STAGED)
    if not ok then logger:error("log export staging failed: %s", err); return false end
    local opened, shown = pcall(love.system.exportFile, STAGED, SUGGESTED)
    if not (opened and shown) then logger:error("Android log export picker could not open") end
    return opened and shown or false
  end
  local path = chooseDesktop()
  if not path then return false end
  local file = io.open(path, "wb")
  if not file then logger:error("log export could not write selected desktop path"); return false end
  file:write(logger:contents())
  file:close()
  logger:info("diagnostic log exported to desktop file picker")
  return true
end

function Export.row()
  return {
    id = "STADIUM_BATTLE_FX:exportLog", label = "EXPORT ANIMATION LOG",
    value = function() return Export.available() and "EXPORT" or "UNAVAILABLE" end,
    step = function() Export.export(); return true end,
  }
end

return Export

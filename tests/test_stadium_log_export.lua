local savedIo = io
local savedLove = love
local written

io = {
  popen = function()
    return {
      read = function() return "C:/Users/Trainer/Desktop/StadiumBattleFX-log.txt\n" end,
      close = function() return true end,
    }
  end,
  open = function()
    return {
      write = function(_, value) written = value; return true end,
      close = function() return true end,
    }
  end,
}
love = {
  system = { getOS = function() return "Windows" end },
}

local messages = {}
local namespace = {
  log = {
    contents = function() return "diagnostic payload\n" end,
    info = function(_, message, value) messages[#messages + 1] = { message, value } end,
    warn = function() end,
    error = function(_, message, value) messages[#messages + 1] = { message, value } end,
  },
  require = function(name)
    assert(name == "StadiumLog")
    return {}
  end,
}

local Export = assert(love.filesystem.load("lib/StadiumLogExport.lua"))(namespace)
local row = Export.row()
assert(row.value() == "EXPORT")
assert(row.step() == true, "successful export should report success")
assert(written == "diagnostic payload\n", "log contents were not written")
assert(row.value() == "SAVED", "successful export status was not visible")
assert(Export.status() == "SAVED")

io.open = function() return nil end
assert(row.step() == false, "failed export must not report success")
assert(row.value() == "FAILED", "failed export status was not visible")

io = savedIo
love = savedLove
return true

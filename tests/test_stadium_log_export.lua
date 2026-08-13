local flushed = 0
local namespace = {
  mod = { storage = {} },
  log = {
    flush = function()
      flushed = flushed + 1
      return true
    end,
  },
}

local Export = assert(loadfile("lib/StadiumLogExport.lua"))(namespace)
local row = Export.row()
assert(row.value() == "SAVE")
assert(row.step() == true, "successful snapshot should report success")
assert(flushed == 1, "snapshot should flush the diagnostic log")
assert(row.value() == "SAVED", "successful snapshot status was not visible")
assert(Export.status() == "SAVED")

namespace.log.flush = function() return false, "write_failed", "disk full" end
assert(row.step() == false, "failed snapshot must not report success")
assert(row.value() == "FAILED", "failed snapshot status was not visible")

return true

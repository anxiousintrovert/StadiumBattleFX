-- Minimal console runner for repository Lua tests under a stock LÖVE build.
function love.load(args)
  -- Tests deliberately prefer loadfile so paths resolve from the repository
  -- working directory rather than this tiny LÖVE application's source root.
  love.filesystem.load = nil
  local path
  for _, value in ipairs(args or {}) do
    if type(value) == "string" and value:match("%.lua$") then path = value end
  end
  for _, value in ipairs(arg or {}) do
    if type(value) == "string" and value:match("%.lua$") then path = value end
  end
  local ok, err = pcall(function()
    assert(path, "pass a Lua test path")
    local chunk, loadErr = loadfile(path)
    assert(chunk, loadErr)
    chunk()
  end)
  if not ok then
    io.stderr:write(tostring(err), "\n")
    love.event.quit(1)
    return
  end
  love.event.quit(0)
end

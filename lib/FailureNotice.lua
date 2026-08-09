-- Short, screen-space diagnostic shown when a Stadium move falls back.

local Notice = {}
local visible
local DURATION = 9

local function clean(value, limit)
  local text = tostring(value or "unknown error")
    :gsub("[\r\n\t]+", " "):gsub("%s+", " ")
  if #text > limit then text = text:sub(1, limit - 3) .. "..." end
  return text
end

function Notice.show(subject, reason)
  local title = clean(subject or "STADIUM FX", 42)
  local detail = clean(reason, 150)
  local key = title .. "\0" .. detail
  if visible and visible.key == key then
    visible.count = visible.count + 1
    visible.remaining = DURATION
    return
  end
  visible = {
    key = key, title = title, detail = detail,
    count = 1, remaining = DURATION,
  }
end

function Notice.update(dt)
  if not visible then return end
  visible.remaining = visible.remaining - math.max(0, tonumber(dt) or 0)
  if visible.remaining <= 0 then visible = nil end
end

function Notice.draw(viewport)
  if not visible then return false end
  local g = love and love.graphics
  if not (g and g.rectangle and g.print) then return false end
  local windowWidth = viewport and tonumber(viewport.width)
    or (g.getWidth and g.getWidth()) or 800
  local x, y = 10, 10
  local width = math.max(220, math.min(680, windowWidth - x * 2))
  local oldBlend, oldAlpha = g.getBlendMode()
  local r, green, b, a = g.getColor()
  local oldLine = g.getLineWidth and g.getLineWidth() or 1
  g.setBlendMode("alpha", "alphamultiply")
  g.setColor(0.10, 0.02, 0.02, 0.94)
  g.rectangle("fill", x, y, width, 54, 4, 4)
  g.setColor(1, 0.34, 0.26, 1)
  if g.setLineWidth then g.setLineWidth(2) end
  g.rectangle("line", x, y, width, 54, 4, 4)
  g.setColor(1, 0.84, 0.78, 1)
  local suffix = visible.count > 1 and ("  x" .. visible.count) or ""
  g.print("STADIUM FX FALLBACK - " .. visible.title .. suffix, x + 8, y + 6)
  g.setColor(1, 1, 1, 1)
  if g.printf then
    g.printf(visible.detail, x + 8, y + 25, width - 16, "left")
  else
    g.print(visible.detail, x + 8, y + 25)
  end
  if g.setLineWidth then g.setLineWidth(oldLine) end
  g.setColor(r or 1, green or 1, b or 1, a or 1)
  g.setBlendMode(oldBlend or "alpha", oldAlpha)
  return true
end

function Notice.clear() visible = nil end
function Notice.status() return visible end

return Notice

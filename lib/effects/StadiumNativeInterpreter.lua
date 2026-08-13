-- Frame-exact interpreter for fragment 62's normalized scheduler records.
-- It owns timing only: callback-specific transform/render ports consume the
-- emitted records without reimplementing cursor or repeat behavior.

local Interpreter = {}

local function append(out, programs, tick, channel)
  if tick < 0 then return end
  for programIndex, program in ipairs(programs or {}) do
    for eventIndex, event in ipairs(program.events or {}) do
      local repeats = tonumber(event.repeats) or 1
      local interval = tonumber(event.interval) or 0
      if repeats == 0x7F or repeats < 0 then
        repeats = interval > 0 and math.floor((tick - event.at) / interval) + 1 or 1
      end
      for repeatIndex = 0, math.max(0, repeats - 1) do
        local born = event.at + interval * repeatIndex
        if tick >= born then
          out[#out + 1] = {
            channel = channel,
            program = program,
            programIndex = programIndex,
            event = event,
            eventIndex = eventIndex,
            repeatIndex = repeatIndex,
            born = born,
            age = tick - born,
          }
        end
      end
    end
  end
end

function Interpreter.active(spec, tick, lifetime, alternate)
  local native = spec and spec.nativePrograms
  if not native then return {} end
  tick = tonumber(tick) or 0
  lifetime = math.max(0, tonumber(lifetime) or 0)
  local out = {}
  local primary = alternate and native.alternate or native.primary
  if alternate and #primary == 0 then primary = native.primary end
  append(out, primary, tick, alternate and "alternate" or "primary")
  append(out, native.impact, tick - (tonumber(spec.impactAt) or 0), "impact")
  if lifetime > 0 then
    local write = 1
    for read = 1, #out do
      if out[read].age < lifetime then
        out[write] = out[read]
        write = write + 1
      end
    end
    for index = #out, write, -1 do out[index] = nil end
  end
  return out
end

function Interpreter.births(spec, previousTick, tick, alternate)
  local active = Interpreter.active(spec, tick, 0, alternate)
  previousTick = tonumber(previousTick) or -1
  local out = {}
  for _, emission in ipairs(active) do
    local globalBorn = emission.born
    if emission.channel == "impact" then
      globalBorn = globalBorn + (tonumber(spec.impactAt) or 0)
    end
    if globalBorn > previousTick and globalBorn <= tick then
      out[#out + 1] = emission
    end
  end
  return out
end

return Interpreter

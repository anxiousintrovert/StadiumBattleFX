local loader = love and love.filesystem and love.filesystem.load or loadfile

local spec = { id = 84, key = "THUNDER_SHOCK", kind = "generic", duration = 30,
  impactAt = 15, assets = {} }
local modules = {
  ["effects/MoveSpecs"] = { get = function() return spec end },
  StadiumAssets = { has = function() return true end, get = function() end },
  ["effects/ThunderShockSpec"] = {},
  DramaticShapeState = { read = function() return {} end },
  DramaticShapeAttachment = {
    tags = function(_, _, _, stage)
      return stage == "primary" and 0x0D or 0x09,
             stage == "primary" and 0x0E or 0x0A
    end,
    position = function() end,
  },
  DramaticShapeHit = { effectiveness = function() end, request = function() end },
  ["effects/GenericMoveRenderer"] = {},
  ["effects/StadiumAuthenticRenderer"] = { draw = function() return false end },
  ["effects/StadiumScreenFx"] = { activate = function() end, clear = function() end },
  AttackCinematics = { stop = function() end, start = function() end, setTick = function() end },
}

local Player = assert(loader("lib/effects/StadiumFxPlayer.lua"))({
  require = function(name) return assert(modules[name], name) end,
})
local player = Player.new({}, function() return true end)
player.spec, player.attackerIsPlayer = spec, true

local passes = player:attachmentPasses()
assert(#passes == 3)
assert(passes[1].attacker == 0x0D and passes[1].target == 0x09)
assert(passes[2].attacker == 0x0E and passes[2].target == 0x09
  and passes[2].secondary)
assert(passes[3].attacker == 0x0D and passes[3].target == 0x0A
  and passes[3].secondary)

player.attachmentPass = passes[2]
assert(player:attachmentTag("attacker") == 0x0E)
assert(player:attachmentTag("target") == 0x09)
player.attachmentPass = nil

local rendered = {}
modules["effects/GenericMoveRenderer"].draw = function(active)
  local pass = active.attachmentPass
  rendered[#rendered + 1] = { pass.attacker, pass.target, pass.secondary }
end
player.custom, player.assetsReady = true, false
player:draw()
assert(#rendered == 3, "secondary attachment passes were not rendered")
assert(rendered[1][1] == 0x0D and rendered[1][2] == 0x09)
assert(rendered[2][1] == 0x0E and rendered[2][2] == 0x09 and rendered[2][3])
assert(rendered[3][1] == 0x0D and rendered[3][2] == 0x0A and rendered[3][3])
print("ok Stadium secondary attachment passes")

local loader = love and love.filesystem and love.filesystem.load or loadfile

local spec = { id = 62, key = "AURORA_BEAM", kind = "generic",
  duration = 50, impactAt = 25, assets = {} }
local requested = {}
local modules = {
  ["effects/MoveSpecs"] = { get = function() return spec end },
  StadiumAssets = { has = function() return true end, get = function() end },
  ["effects/ThunderShockSpec"] = {},
  DramaticShapeState = { read = function()
    return { attackerShowing = true, targetShowing = true }
  end },
  DramaticShapeAttachment = {
    screenPosition = function(_, side, tag)
      requested[#requested + 1] = { side, tag }
      if side == "player" then return 120, 600 end
      if side == "enemy" then return 1500, 270 end
    end,
    position = function() error("logical attachment path must not be used") end,
  },
  DramaticShapeHit = { effectiveness = function() end, request = function() end },
  ["effects/GenericMoveRenderer"] = { draw = function(active)
    local ax, ay = active:anchor("attacker")
    local tx, ty = active:anchor("target")
    assert(ax == 16 and ay == 80,
      "player attack source was not bound to the player model screen bone")
    assert(tx == 200 and ty == 36,
      "player attack target was not bound to the enemy model screen bone")
  end },
  ["effects/StadiumAuthenticRenderer"] = { draw = function() return false end },
  ["effects/StadiumScreenFx"] = {
    activate = function() end, clear = function() end,
    beginAnchored = function() return {
      screen = true, scale = 7.5, width = 1920, height = 1080,
    } end,
    endAnchored = function() end,
  },
  AttackCinematics = { stop = function() end, start = function() end,
    setTick = function() end },
}

local hostLove = love
love = { graphics = {
  push = function() end, pop = function() end, origin = function() end,
  setShader = function() end, setScissor = function() end,
  setBlendMode = function() end,
} }

local Player = assert(loader("lib/effects/StadiumFxPlayer.lua"))({
  require = function(name) return assert(modules[name], name) end,
})
local player = Player.new({}, function() return true end)
player.spec, player.custom, player.assetsReady = spec, true, false
player.attackerIsPlayer = true
player.context = {
  user = { isPlayer = true }, target = { isPlayer = false },
}
player:draw()
assert(requested[1][1] == "player" and requested[2][1] == "enemy",
  "attacker and defender provider sides were reversed")

-- A one-frame provider miss holds the role's last live camera projection and
-- never substitutes a fixed Game Boy/player-side location.
modules.DramaticShapeAttachment.screenPosition = function() return nil end
player.anchoredRedirect = {
  screen = true, scale = 7.5, width = 1920, height = 1080,
}
local heldX, heldY = player:anchor("attacker")
assert(heldX == 16 and heldY == 80,
  "temporary projection miss did not hold the last live attacker bone")
player.anchoredRedirect = nil

love = hostLove
print("ok player attacks bind directly to live player/enemy screen bones")

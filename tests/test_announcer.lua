local hostLove = _G.love

local completeMarker = '{"clip_count":823,"content_sha256":"test"}'

local function wav()
  local samples = string.char(0, 0, 255, 127, 0, 128)
  local function le16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
  local function le32(n)
    return string.char(n % 256, math.floor(n / 256) % 256,
      math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
  end
  return "RIFF" .. le32(36 + #samples) .. "WAVEfmt " .. le32(16)
    .. le16(1) .. le16(1) .. le32(16000) .. le32(32000)
    .. le16(2) .. le16(16) .. "data" .. le32(#samples) .. samples
end

local function memoryFilesystem()
  local files, dirs = {}, {}
  return {
    getInfo = function(path, kind)
      local file = files[path]
      if file and (not kind or kind == "file") then return { type = "file" } end
      if dirs[path] and (not kind or kind == "directory") then return { type = "directory" } end
      return nil
    end,
    createDirectory = function(path) dirs[path] = true; return true end,
    read = function(path) return files[path] end,
    write = function(path, value) files[path] = value; return true end,
    remove = function(path) files[path] = nil; return true end,
    newFileData = function(bytes, name) return { bytes = bytes, name = name } end,
  }
end

local function source()
  local self = { playing = false, stopped = false }
  function self:play() self.playing = true end
  function self:stop() self.playing = false; self.stopped = true end
  function self:isPlaying() return self.playing end
  return self
end

local function loadAnnouncer(opts)
  opts = opts or {}
  local played = {}
  _G.love = {
    filesystem = opts.filesystem or (hostLove and hostLove.filesystem),
    event = hostLove and hostLove.event,
    audio = {
      newSource = function(path, kind)
        if opts.missing and type(path) == "string" and path:match(opts.missing) then
          error("missing clip")
        end
        local item = source()
        item.path, item.kind = path, kind
        played[#played + 1] = item
        return item
      end,
    },
    sound = {
      newSoundData = function(samples, rate, bits, channels)
        local item = { samples = samples, rate = rate, bits = bits,
          channels = channels, values = {} }
        function item:setSample(index, value) self.values[index] = value end
        return item
      end,
    },
  }
  local values = {
    announcer = opts.enabled ~= false,
    announcer_scope = opts.scope or "gym",
  }
  local mod = {
    game = {},
    path = "mounted/STADIUM_BATTLE_FX",
    read = function(_, path)
      if path == "assets/announcer/voicepack.json" and opts.pack ~= false then
        return completeMarker
      end
      if opts.sourceClips and path:match("^assets/announcer/%d%d%d%.wav$") then
        return wav()
      end
      return nil
    end,
    assets = {
      path = function(_, relative) return "mounted/STADIUM_BATTLE_FX/" .. relative end,
    },
    options = { get = function(_, key) return values[key] end },
    log = { info = function() end },
  }
  local records = opts.records or {}
  mod.storage = {
    read = function(_, _, key) return records[key] end,
    write = function(_, _, key, value) records[key] = value; return true end,
    delete = function(_, _, key) records[key] = nil; return true end,
  }
  local loader = love and love.filesystem and love.filesystem.load or loadfile
  local chunk = assert(loader("lib/Announcer.lua"))
  local namespace = { mod = mod }
  function namespace.require(name)
    assert(name == "ModStorage")
    return assert(loader("lib/ModStorage.lua"))(namespace)
  end
  return chunk(namespace), played
end

local function battle(oppClass, partyIndex)
  return {
    oppClass = oppClass,
    partyIndex = partyIndex or 1,
    data = { pokemon = {
      BULBASAUR = { dex = 1 },
      RATTATA = { dex = 19 },
      MODMON = { dex = 152 },
    } },
    player = { isPlayer = true, mon = { species = "BULBASAUR" } },
    enemy = { isPlayer = false, mon = { species = "RATTATA" } },
  }
end

-- The selector broadens the same announcer bank without changing the legacy
-- default: Gym/Elite Four/Champion remains the only scope with boss intros.
do
  local trainer = battle("OPP_YOUNGSTER")
  trainer.kind = "trainer"
  local wild = battle(nil)
  wild.kind = "wild"

  local gym = loadAnnouncer({ scope = "gym" })
  local trainers = loadAnnouncer({ scope = "trainer" })
  local trainerWild = loadAnnouncer({ scope = "trainer" })
  local all = loadAnnouncer({ scope = "all" })
  assert(gym.beginBattle(trainer) == false)
  assert(trainers.beginBattle(trainer) == true)
  assert(trainerWild.beginBattle(wild) == false)
  assert(all.beginBattle(wild) == true)
end

-- A personalized package is only an import source. Once imported, a later
-- voice-free update reads the save-data copy instead of requiring a second ZIP.
do
  local records = {}
  local announcer, played = loadAnnouncer({ records = records, sourceClips = true })
  assert(announcer.cachePending())
  assert(announcer.beginCache())
  while announcer.stepCache() do end
  assert(announcer.cacheStatus().ready)
  assert(announcer.beginBattle(battle("OPP_BROCK")) == true)
  assert(announcer.status().source == "cache")
  assert(type(played[1].path) == "table" and played[1].path.samples == 3)

  local updated, afterUpdate = loadAnnouncer({ records = records, pack = false })
  assert(updated.beginBattle(battle("OPP_MISTY")) == true)
  assert(updated.status().source == "cache")
  assert(#afterUpdate == 1)
end

-- A complete pack starts the leader intro. Species names stay pending until
-- their own send-out text is gone and that side has actually entered.
do
  local announcer, played = loadAnnouncer()
  local expected = {
    OPP_BROCK = 223, OPP_MISTY = 224, OPP_LT_SURGE = 225,
    OPP_ERIKA = 226, OPP_KOGA = 227, OPP_SABRINA = 228,
    OPP_BLAINE = 229, OPP_GIOVANNI = 230, OPP_LORELEI = 231,
    OPP_BRUNO = 232, OPP_AGATHA = 233, OPP_LANCE = 234,
    OPP_RIVAL3 = 235,
  }
  for trainer, clip in pairs(expected) do
    assert(announcer.INTRO[trainer] and announcer.INTRO[trainer].clip == clip)
  end
  local b = battle("OPP_BROCK")
  b.current = { text = "intro" }
  b.enemySendingOut, b.sendingOut = true, true
  assert(announcer.beginBattle(b) == true)
  assert(announcer.status().current == 223)
  assert(played[1].path:match("assets/announcer/223%.wav$"))
  assert(announcer.status().queued == 0)
  assert(announcer.status().pendingActions == 2)

  -- The enemy enters first. Its name cannot play while the text box is up.
  announcer.update(0.1)
  assert(announcer.status().pendingActions == 2)
  -- A completed automatic page remains painted through msgHold on current
  -- Gen1Recomp builds, but it must not block the completed send-out cue.
  b.current, b.msgHold, b.enemySendingOut = nil, true, false
  played[1].playing = false
  announcer.update(0.2)
  announcer.update(0.2)
  assert(announcer.status().current == 387) -- 368 + Rattata dex 19
  assert(played[2].path:match("assets/announcer/387%.wav$"))
  assert(announcer.status().pendingActions == 1)

  -- The player's name follows only after the player's separate send-out.
  b.current = { text = "Go!" }
  announcer.update(0.1)
  b.current, b.msgHold, b.sendingOut = nil, true, false
  played[2].playing = false
  announcer.update(0.2)
  announcer.update(0.2)
  assert(announcer.status().current == 369) -- 368 + Bulbasaur dex 1
  assert(announcer.status().pendingActions == 0)

  -- Move speech waits for the animation edge, damage for the HP drain,
  -- status for its cleared message, and faint speech for the visible faint.
  b.current = { text = "used THUNDER SHOCK" }
  assert(announcer.moveUsed({ battle = b,
    move = { id = "THUNDER_SHOCK", index = 84 } }))
  announcer.update(0)
  assert(announcer.status().pendingActions == 1)
  b.current, b.animPlaying, b.animName = nil, true, "THUNDER_SHOCK"
  announcer.update(0)
  assert(announcer.status().pendingActions == 0)

  b.enemy.shownHP = 20
  assert(announcer.damageDealt({ battle = b, target = b.enemy, typeMult = 20 }))
  announcer.update(0)
  assert(announcer.status().pendingActions == 1)
  b.enemy.draining = true
  announcer.update(0)
  assert(announcer.status().pendingActions == 0)
  b.enemy.draining, b.animPlaying = nil, false

  assert(announcer.statusInflicted({ battle = b, target = b.enemy, status = "PAR" }))
  b.current = { text = "paralyzed" }
  announcer.update(0)
  b.current = nil
  announcer.update(0)
  assert(announcer.status().pendingActions == 0)

  b.enemy.mon.hp = 0
  b.enemy.shownHP = 0
  b.enemy.fainted = false
  assert(announcer.fainted({ battle = b, battler = b.enemy }))
  announcer.update(0)
  assert(announcer.status().pendingActions == 1,
    "faint call released before the visible faint began")
  b.enemy.fainted = true
  announcer.update(0)
  assert(announcer.status().pendingActions == 0)
end

-- A switch event is emitted before Gen1Recomp inserts its withdrawal/send-out
-- text. The switch call and species sentence therefore wait for that text and
-- the entry animation, then play in action -> Pokemon order.
do
  local announcer, played = loadAnnouncer()
  local b = battle("OPP_BROCK")
  b.current = { text = "opening send-outs" }
  b.enemySendingOut, b.sendingOut = true, true
  assert(announcer.beginBattle(b))
  announcer.update(0)
  b.current, b.enemySendingOut, b.sendingOut = nil, false, false
  announcer.update(0)
  while announcer.status().current or announcer.status().queued > 0 do
    if played[#played] then played[#played].playing = false end
    announcer.update(1)
  end
  announcer.update(1)

  local outgoing = b.player
  local incoming = { isPlayer = true, mon = { species = "RATTATA", hp = 12 } }
  b.player = incoming
  assert(announcer.battlerSwitched({ battle = b, side = { index = 1 },
    battler = incoming, previous = outgoing }))
  b.current, b.sendingOut = { text = "Go! RATTATA!" }, true
  announcer.update(0)
  assert(announcer.status().pendingActions == 1)
  b.current, b.sendingOut = nil, false
  announcer.update(0)
  assert(announcer.status().pendingActions == 0)
  assert(announcer.status().current == 245)
  assert(played[#played].path:match("assets/announcer/245%.wav$"))
  assert(announcer.status().queued == 1) -- Rattata's 387 sentence follows
end

-- battler_switched is also the engine's send-out event after a knockout (and
-- for the opening send-outs in link battles). Those are replacements, not a
-- trainer choosing to change Pokemon, so they announce only the incoming
-- species. The authoritative payload side selects the correct voluntary line.
do
  local function readyAnnouncer()
    local announcer, played = loadAnnouncer()
    local b = battle("OPP_BROCK")
    b.current = { text = "opening send-outs" }
    b.enemySendingOut, b.sendingOut = true, true
    assert(announcer.beginBattle(b))
    announcer.update(0)
    b.current, b.enemySendingOut, b.sendingOut = nil, false, false
    announcer.update(0)
    while announcer.status().current or announcer.status().queued > 0 do
      if played[#played] then played[#played].playing = false end
      announcer.update(1)
    end
    announcer.update(1)
    return announcer, played, b
  end

  -- An opponent voluntarily withdrawing a healthy Pokemon uses clip 253.
  local announcer, played, b = readyAnnouncer()
  local outgoing = b.enemy
  outgoing.mon.hp = 10
  local incoming = { isPlayer = false, mon = { species = "BULBASAUR", hp = 10 } }
  b.enemy = incoming
  assert(announcer.battlerSwitched({ battle = b, side = { index = 2 },
    battler = incoming, previous = outgoing }))
  b.current, b.enemySendingOut = { text = "sent out" }, true
  announcer.update(0)
  b.current, b.enemySendingOut = nil, false
  announcer.update(0)
  assert(announcer.status().current == 253,
    "opponent voluntary switch did not use the opponent line")
  assert(played[#played].path:match("assets/announcer/253%.wav$"))

  -- A fainted Pokemon's forced replacement must not use any change line.
  announcer, played, b = readyAnnouncer()
  outgoing = b.enemy
  outgoing.mon.hp = 0
  incoming = { isPlayer = false, mon = { species = "BULBASAUR", hp = 10 } }
  b.enemy = incoming
  assert(announcer.battlerSwitched({ battle = b, side = { index = 2 },
    battler = incoming, previous = outgoing }))
  b.current, b.enemySendingOut = { text = "sent out" }, true
  announcer.update(0)
  b.current, b.enemySendingOut = nil, false
  announcer.update(0)
  assert(announcer.status().current == 369,
    "forced replacement incorrectly announced a trainer change")
  assert(played[#played].path:match("assets/announcer/369%.wav$"))
  assert(announcer.status().queued == 0)

  -- Re-wrapping the same party Pokemon for an opening link send-out is also
  -- not a change, even though that Pokemon is healthy.
  announcer, played, b = readyAnnouncer()
  local mon = b.enemy.mon
  outgoing = b.enemy
  incoming = { isPlayer = false, mon = mon }
  b.enemy = incoming
  assert(announcer.battlerSwitched({ battle = b, side = { index = 2 },
    battler = incoming, previous = outgoing }))
  b.current, b.enemySendingOut = { text = "sent out" }, true
  announcer.update(0)
  b.current, b.enemySendingOut = nil, false
  announcer.update(0)
  assert(announcer.status().current == 387,
    "opening send-out incorrectly announced a trainer change")
  assert(played[#played].path:match("assets/announcer/387%.wav$"))
end

-- Flow commentary becomes eligible only after several moves and waits for an
-- idle gap. It is ambient priority, so the next real event stops it.
do
  local announcer, played = loadAnnouncer()
  local b = battle("OPP_BROCK")
  b.current = { text = "send out" }
  b.enemySendingOut, b.sendingOut = true, true
  assert(announcer.beginBattle(b))
  announcer.update(0)
  b.current, b.enemySendingOut, b.sendingOut = nil, false, false
  announcer.update(0)
  for _ = 1, 4 do
    announcer.moveUsed({ battle = b, move = { id = "THUNDER_SHOCK", index = 84 } })
    b.animPlaying, b.animName = true, "THUNDER_SHOCK"
    announcer.update(0)
    b.animPlaying = false
  end
  assert(announcer.status().flowPending == true)

  -- An incoming move must be able to interrupt an ambient call immediately.
  -- The exact commentary clip is intentionally not asserted; its rotation is
  -- an implementation detail, while its priority behavior is the contract.
  while announcer.status().current or announcer.status().queued > 0 do
    local current = played[#played]
    if current then current.playing = false end
    announcer.update(1)
  end
  announcer.update(1)
  assert(announcer.status().current ~= nil, "flow commentary did not start after an idle gap")
  assert(announcer.moveUsed({ battle = b, move = { id = "THUNDERBOLT", index = 85 } }))
  b.animPlaying, b.animName = true, "THUNDERBOLT"
  announcer.update(0)
  assert(announcer.status().current == 668, "move call did not interrupt flow commentary")
end

-- The three true idle lines only run while BattleState itself owns a player
-- decision. Input, cursor movement, overlays, and action phases reset/pause
-- the timer, and a prompt is emitted at most once per untouched decision.
do
  local announcer, played = loadAnnouncer()
  local b = battle("OPP_BROCK")
  b.phase = "messages"
  b.current = { text = "send out" }
  b.enemySendingOut, b.sendingOut = true, true
  b.menuIndex = 1
  local game = { input = { pressQueue = {} }, stack = {} }
  function game.stack:top() return b end
  b.game = game
  assert(announcer.beginBattle(b))
  announcer.update(0, game)
  b.current, b.enemySendingOut, b.sendingOut = nil, false, false

  while announcer.status().current or announcer.status().queued > 0
        or announcer.status().pendingActions > 0 do
    local current = played[#played]
    if current then current.playing = false end
    announcer.update(1, game)
  end
  announcer.update(1, game) -- clear the final inter-clip gap

  b.phase = "menu"
  announcer.update(9, game)
  assert(announcer.status().current == nil, "idle prompt fired too early")
  game.input.pressQueue = { "right" }
  announcer.update(2, game)
  game.input.pressQueue = {}
  announcer.update(9.9, game)
  assert(announcer.status().current == nil, "input did not reset idle timing")
  announcer.update(0.2, game)
  assert(announcer.status().current == 749, "first trainer-idle line was not used")
  assert(announcer.status().decisionPrompted == true)

  played[#played].playing = false
  announcer.update(20, game)
  announcer.update(1, game)
  assert(announcer.status().current == nil,
    "untouched decision repeated its idle prompt")

  b.menuIndex = 2
  announcer.update(0, game)
  announcer.update(announcer.DECISION_IDLE_SECONDS + 0.1, game)
  assert(announcer.status().current == 750,
    "new cursor activity did not arm the next idle line")

  played[#played].playing = false
  b.phase = "messages"
  announcer.update(20, game)
  assert(announcer.status().current == nil,
    "idle prompt fired outside a player decision phase")

  b.phase = "menu"
  game.stack.top = function() return {} end
  announcer.update(20, game)
  assert(announcer.status().current == nil,
    "idle prompt fired while an overlay owned input")
end

-- No builder output is a supported empty state: no source is constructed and
-- the rest of StadiumBattleFX can continue normally.
do
  local announcer, played = loadAnnouncer({ pack = false })
  assert(announcer.beginBattle(battle("OPP_MISTY")) == false)
  assert(#played == 0)
  assert(announcer.status().packReady == false)
end

-- A partial/corrupt pack skips only the bad clip. Here Brock's intro is
-- absent, so playback advances directly to Rattata's name.
do
  local announcer, played = loadAnnouncer({ missing = "223%.wav$" })
  local b = battle("OPP_BROCK")
  b.current = { text = "send out" }
  b.enemySendingOut = true
  assert(announcer.beginBattle(b) == true)
  assert(announcer.status().current == nil)
  announcer.update(0)
  b.current, b.enemySendingOut = nil, false
  announcer.update(0)
  assert(announcer.status().current == 387)
  assert(#played == 1 and played[1].path:match("387%.wav$"))
end


-- Giovanni is scoped to his Viridian Gym party, not the two Rocket battles.
do
  local announcer = loadAnnouncer()
  assert(announcer.beginBattle(battle("OPP_GIOVANNI", 2)) == false)
  assert(announcer.beginBattle(battle("OPP_GIOVANNI", 3)) == true)
  assert(announcer.status().intro == 230)
end


-- Ordinary trainers never activate the announcer. Mod-added species outside
-- the Gen I dex silently skip their name while keeping an eligible intro.
do
  local announcer = loadAnnouncer()
  assert(announcer.beginBattle(battle("OPP_YOUNGSTER")) == false)
  local b = battle("OPP_LORELEI")
  b.enemy.mon.species = "MODMON"
  assert(announcer.beginBattle(b) == true)
  assert(announcer.status().intro == 231)
  assert(announcer.status().queued == 0)
  assert(announcer.status().pendingActions == 1) -- only Bulbasaur can be named
end

_G.love = hostLove
print("ok announcer optional pack and Gym/Elite Four routing")
if hostLove and hostLove.event then hostLove.event.quit() end

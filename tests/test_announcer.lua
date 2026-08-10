local hostLove = _G.love

local completeMarker = '{"clip_count":823,"content_sha256":"test"}'

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
        if opts.missing and path:match(opts.missing) then error("missing clip") end
        local item = source()
        item.path, item.kind = path, kind
        played[#played + 1] = item
        return item
      end,
    },
  }
  local values = {
    announcer = opts.enabled ~= false,
    announcer_scope = opts.scope or "gym",
  }
  local mod = {
    path = "mounted/STADIUM_BATTLE_FX",
    read = function(_, path)
      if path == "assets/announcer/voicepack.json" and opts.pack ~= false then
        return completeMarker
      end
      if opts.sourceClips and path:match("^assets/announcer/%d%d%d%.wav$") then
        return string.rep("w", 45)
      end
      return nil
    end,
    assets = {
      path = function(_, relative) return "mounted/STADIUM_BATTLE_FX/" .. relative end,
    },
    options = { get = function(_, key) return values[key] end },
    log = { info = function() end },
  }
  local loader = love and love.filesystem and love.filesystem.load or loadfile
  local chunk = assert(loader("lib/Announcer.lua"))
  return chunk({ mod = mod }), played
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

  assert(loadAnnouncer({ scope = "gym" }):beginBattle(trainer) == false)
  assert(loadAnnouncer({ scope = "trainer" }):beginBattle(trainer) == true)
  assert(loadAnnouncer({ scope = "trainer" }):beginBattle(wild) == false)
  assert(loadAnnouncer({ scope = "all" }):beginBattle(wild) == true)
end

-- A personalized package is only an import source. Once imported, a later
-- voice-free update reads the save-data copy instead of requiring a second ZIP.
do
  local filesystem = memoryFilesystem()
  local announcer, played = loadAnnouncer({ filesystem = filesystem, sourceClips = true })
  assert(announcer.beginBattle(battle("OPP_BROCK")) == true)
  assert(announcer.status().source == "cache")
  assert(played[1].path:match("stadium_battle_fx/announcer/v1/223%.wav$"))

  local updated, afterUpdate = loadAnnouncer({ filesystem = filesystem, pack = false })
  assert(updated.beginBattle(battle("OPP_MISTY")) == true)
  assert(updated.status().source == "cache")
  assert(#afterUpdate == 1)
end

-- A complete pack starts the leader intro, then both Pokedex-ordered species
-- sentences. The module resolves paths inside its own mounted ZIP.
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
  assert(announcer.beginBattle(b) == true)
  assert(announcer.status().current == 223)
  assert(played[1].path:match("assets/announcer/223%.wav$"))
  assert(announcer.status().queued == 2)
  played[1].playing = false
  announcer.update(0.2)
  announcer.update(0.2)
  assert(announcer.status().current == 387) -- 368 + Rattata dex 19
  assert(played[2].path:match("assets/announcer/387%.wav$"))

  assert(announcer.moveUsed({ battle = b, move = { index = 84 } }))
  assert(announcer.damageDealt({ battle = b, typeMult = 20 }))
  assert(announcer.statusInflicted({ battle = b, status = "PAR" }))
  local queuedBeforeFaint = announcer.status().queued
  b.enemy.mon.hp = 0
  b.enemy.shownHP = 12
  assert(announcer.fainted({ battle = b, battler = b.enemy }))
  assert(announcer.status().pendingFaints == true)
  assert(announcer.status().queued == queuedBeforeFaint,
    "faint call was queued before the displayed HP reached zero")
  assert(announcer.status().current == 387,
    "faint call started before the displayed HP reached zero")
  b.enemy.shownHP = 0
  announcer.update(0)
  assert(announcer.status().pendingFaints == false)
  assert(announcer.status().queued == queuedBeforeFaint + 1,
    "faint call was not queued after the displayed HP reached zero")
end

-- Flow commentary becomes eligible only after several moves and waits for an
-- idle gap. It is ambient priority, so the next real event stops it.
do
  local announcer, played = loadAnnouncer()
  local b = battle("OPP_BROCK")
  assert(announcer.beginBattle(b))
  for _ = 1, 4 do announcer.moveUsed({ battle = b, move = { index = 84 } }) end
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
  assert(announcer.moveUsed({ battle = b, move = { index = 85 } }))
  assert(announcer.status().current == 668, "move call did not interrupt flow commentary")
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
  assert(announcer.beginBattle(battle("OPP_BROCK")) == true)
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
  assert(announcer.status().queued == 1) -- only Bulbasaur follows the intro
end

_G.love = hostLove
print("ok announcer optional pack and Gym/Elite Four routing")
if hostLove and hostLove.event then hostLove.event.quit() end

local hostLove = _G.love

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
    filesystem = hostLove and hostLove.filesystem,
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
  local values = { announcer = opts.enabled ~= false }
  local mod = {
    path = "mounted/STADIUM_BATTLE_FX",
    read = function(_, path)
      if path == "assets/announcer/voicepack.json" and opts.pack ~= false then
        return "{}"
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
  assert(announcer.fainted({ battle = b, battler = b.enemy }))
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

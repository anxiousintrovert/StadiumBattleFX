-- Optional Pokemon Stadium announcer playback for Gym Leader and Elite Four
-- battles. Voice files are never part of the public mod: the local Windows
-- builder injects assets/announcer/voicepack.json and numbered WAVs into a
-- personalized copy of the release ZIP. On first use that pack is imported
-- into save data, so later voice-free updates retain the local audio.

local namespace = ...
local mod = namespace.mod

local Announcer = {}

local VOICE_ROOT = "assets/announcer"
local PACK_MARKER = VOICE_ROOT .. "/voicepack.json"
local CACHE_DIR = "stadium_battle_fx/announcer/v1"
local CACHE_MARKER = CACHE_DIR .. "/cache.info"
local CACHE_FORMAT = "SFXA1"
local CLIP_COUNT = 823
local GAP_SECONDS = 0.12
local MAX_QUEUE = 8

local PRIORITY = {
  ambient = 10,
  move = 20,
  damage = 40,
  status = 55,
  sendout = 70,
  faint = 80,
  result = 90,
  intro = 100,
}

-- Pokemon Stadium's Gym Leader Castle clips 223..235. Giovanni's trainer
-- class is also used in the Rocket Hideout and Silph Co.; only party 3 is
-- the Viridian Gym battle. OPP_RIVAL3 is exclusively the Champion here.
local INTRO = {
  OPP_BROCK = { clip = 223 },
  OPP_MISTY = { clip = 224 },
  OPP_LT_SURGE = { clip = 225 },
  OPP_ERIKA = { clip = 226 },
  OPP_KOGA = { clip = 227 },
  OPP_SABRINA = { clip = 228 },
  OPP_BLAINE = { clip = 229 },
  OPP_GIOVANNI = { clip = 230, party = 3 },
  OPP_LORELEI = { clip = 231 },
  OPP_BRUNO = { clip = 232 },
  OPP_AGATHA = { clip = 233 },
  OPP_LANCE = { clip = 234 },
  OPP_RIVAL3 = { clip = 235, champion = true },
}

local STATUS_CLIP = {
  SLP = 285,
  FRZ = 286,
  PAR = 287,
  PSN = 301,
  BRN = 346,
}

local state = {
  battle = nil,
  intro = nil,
  champion = false,
  current = nil,
  currentIndex = nil,
  queue = {},
  gap = 0,
  packChecked = false,
  packReady = false,
  packSource = nil,
  cacheError = nil,
  missing = {},
  warnedMissingPack = false,
}

local function enabled()
  return not (mod.options and mod.options.get)
      or mod.options:get("announcer") ~= false
end

local function isFile(path)
  local f = love and love.filesystem
  if not (f and f.getInfo) then return false end
  local ok, info = pcall(f.getInfo, path, "file")
  return ok and info and true or false
end

local function ensureDirectory(path)
  local f = love and love.filesystem
  if not (f and f.createDirectory) then return false, "filesystem unavailable" end
  local current = ""
  for part in path:gmatch("[^/]+") do
    current = current == "" and part or current .. "/" .. part
    if not isFile(current) then
      local ok, made, err = pcall(f.createDirectory, current)
      if not (ok and made) then
        local visible = false
        if f.getInfo then
          local exists, info = pcall(f.getInfo, current, "directory")
          visible = exists and info and true or false
        end
        if not visible then return false, tostring(err or made) end
      end
    end
  end
  return true
end

local function checksum(bytes)
  local a, b = 1, 0
  for i = 1, #bytes do
    a = (a + bytes:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

local function cacheClip(index)
  return ("%s/%03d.wav"):format(CACHE_DIR, index)
end

local function cacheReady(expectedStamp)
  local f = love and love.filesystem
  if not (f and f.read) or not isFile(CACHE_MARKER) then return false end
  local ok, marker = pcall(f.read, CACHE_MARKER)
  local stamp = ok and type(marker) == "string" and marker:match("^" .. CACHE_FORMAT .. " (%d+)\n")
  if not stamp or (expectedStamp and tonumber(stamp) ~= expectedStamp) then
    return false
  end
  for index = 0, CLIP_COUNT - 1 do
    if not isFile(cacheClip(index)) then return false end
  end
  return true
end

local function sourceMarker()
  local ok, marker = pcall(mod.read, mod, PACK_MARKER)
  if not (ok and type(marker) == "string" and #marker > 0) then return nil end
  -- The builder writes a complete 823-clip manifest. This guards against
  -- accidentally caching an arbitrary or interrupted package.
  if not marker:match('"clip_count"%s*:%s*823') then return nil end
  return marker
end

local function importPack(marker)
  local f = love and love.filesystem
  if not (f and f.write) then return false, "filesystem unavailable" end
  local made, makeErr = ensureDirectory(CACHE_DIR)
  if not made then return false, makeErr end
  -- Invalidate an older cache before replacing its clips. The completed marker
  -- is written last, so an interrupted import cannot be mistaken for a pack.
  local invalidated, result, err = pcall(f.write, CACHE_MARKER, CACHE_FORMAT .. " PENDING\n")
  if not (invalidated and result) then return false, tostring(err or result) end
  for index = 0, CLIP_COUNT - 1 do
    local relative = ("%s/%03d.wav"):format(VOICE_ROOT, index)
    local ok, bytes = pcall(mod.read, mod, relative)
    if not (ok and type(bytes) == "string" and #bytes > 44) then
      return false, "voice pack is missing clip " .. tostring(index)
    end
    local wrote, result, err = pcall(f.write, cacheClip(index), bytes)
    if not (wrote and result) then return false, tostring(err or result) end
  end
  local saved, result, err = pcall(f.write, CACHE_MARKER,
    CACHE_FORMAT .. " " .. checksum(marker) .. "\n" .. marker)
  if not (saved and result) then return false, tostring(err or result) end
  return true
end

local function stopSource(source)
  if source and source.stop then pcall(source.stop, source) end
end

local function resetPlayback()
  stopSource(state.current)
  state.current = nil
  state.currentIndex = nil
  state.queue = {}
  state.gap = 0
end

local function packReady()
  if state.packChecked then return state.packReady end
  state.packChecked = true
  local marker = sourceMarker()
  if cacheReady(marker and checksum(marker) or nil) then
    state.packReady, state.packSource = true, "cache"
    return true
  end
  if not marker then return false end
  local imported, err = importPack(marker)
  if imported and cacheReady() then
    state.packReady, state.packSource = true, "cache"
  else
    -- The mounted personalized ZIP is still a usable, non-persistent fallback
    -- when save storage is unavailable.
    state.packReady, state.packSource, state.cacheError = true, "package", err
  end
  return state.packReady
end

local function clipRelative(index)
  return ("%s/%03d.wav"):format(VOICE_ROOT, index)
end

local function clipPath(index)
  if state.packSource == "cache" then return cacheClip(index) end
  local relative = clipRelative(index)
  if mod.assets and mod.assets.path then
    return mod.assets:path(relative)
  end
  return tostring(mod.path or "") .. "/" .. relative
end

local function loadSource(index)
  if state.missing[index] then return nil end
  if not (love and love.audio and love.audio.newSource) then return nil end
  local ok, source = pcall(love.audio.newSource, clipPath(index), "static")
  if not ok or not source then
    state.missing[index] = true
    return nil
  end
  return source
end

local function startNext()
  if state.current or state.gap > 0 then return end
  while #state.queue > 0 do
    local item = table.remove(state.queue, 1)
    local source = loadSource(item.index)
    if source then
      local ok = pcall(source.play, source)
      if ok then
        state.current = source
        state.currentIndex = item.index
        return
      end
      state.missing[item.index] = true
    end
  end
end

local function alreadyQueued(index, key)
  if state.currentIndex == index then return true end
  for _, item in ipairs(state.queue) do
    if item.index == index or (key and item.key == key) then return true end
  end
  return false
end

local function enqueue(index, priority, key)
  if type(index) ~= "number" or index < 0 or index > 822 then return false end
  if not enabled() then return false end
  if not packReady() or alreadyQueued(index, key) then return false end
  local item = { index = index, priority = priority or 0, key = key }
  if #state.queue >= MAX_QUEUE then
    local lowest, lowestPriority = 1, state.queue[1].priority
    for i = 2, #state.queue do
      if state.queue[i].priority < lowestPriority then
        lowest, lowestPriority = i, state.queue[i].priority
      end
    end
    if item.priority <= lowestPriority then return false end
    table.remove(state.queue, lowest)
  end
  local inserted = false
  for i, queued in ipairs(state.queue) do
    if item.priority > queued.priority then
      table.insert(state.queue, i, item)
      inserted = true
      break
    end
  end
  if not inserted then state.queue[#state.queue + 1] = item end
  startNext()
  return true
end

local function introFor(battle)
  if not battle then return nil end
  local intro = INTRO[battle.oppClass]
  if not intro then return nil end
  if intro.party and intro.party ~= (battle.partyIndex or 1) then return nil end
  return intro
end

local function dexFor(battle, battler)
  local species = battler and battler.mon and battler.mon.species
  local pokemon = battle and battle.data and battle.data.pokemon
  local def = species and pokemon and pokemon[species]
  local dex = def and tonumber(def.dex)
  if not dex or dex < 1 or dex > 151 then return nil end
  return dex
end

local function announceBattler(battle, battler, key)
  local dex = dexFor(battle, battler)
  if not dex then return false end
  -- Full "Oh! It's [Pokemon]!" bank, in Pokedex order.
  return enqueue(368 + dex, PRIORITY.sendout, key)
end

function Announcer.beginBattle(battle)
  resetPlayback()
  state.battle = nil
  state.intro = nil
  state.champion = false
  if not enabled() then return false end
  local intro = introFor(battle)
  if not intro then return false end
  if not packReady() then
    local logger = namespace.log or mod.log
    if not state.warnedMissingPack and logger and logger.info then
      state.warnedMissingPack = true
      logger:info("optional Stadium announcer voice pack not installed; battle audio unchanged")
    end
    return false
  end
  state.battle = battle
  state.intro = intro.clip
  state.champion = intro.champion or false
  enqueue(intro.clip, PRIORITY.intro, "encounter_intro")
  -- Announce both initial combatants. Missing or mod-added species are simply
  -- skipped; they never disable the rest of the voice pack.
  announceBattler(battle, battle.enemy, "initial_enemy")
  announceBattler(battle, battle.player, "initial_player")
  return true
end

function Announcer.battlerSwitched(payload)
  local battle = payload and payload.battle
  if battle ~= state.battle then return false end
  return announceBattler(battle, payload.battler,
    payload.battler and payload.battler.isPlayer and "player_sendout" or "enemy_sendout")
end

function Announcer.moveUsed(payload)
  local battle = payload and payload.battle
  if battle ~= state.battle then return false end
  local moveIndex = payload.move and tonumber(payload.move.index)
  if not moveIndex or moveIndex < 1 or moveIndex > 165 then return false end
  return enqueue(583 + moveIndex, PRIORITY.move, "move:" .. tostring(moveIndex))
end

function Announcer.damageDealt(payload)
  if not payload or payload.battle ~= state.battle then return false end
  if payload.crit then return enqueue(312, PRIORITY.damage, "damage_reaction") end
  local mult = tonumber(payload.typeMult)
  if mult and mult > 10 then
    return enqueue(262, PRIORITY.damage, "damage_reaction")
  elseif mult and mult < 10 then
    return enqueue(319, PRIORITY.damage, "damage_reaction")
  end
  return false
end

function Announcer.statusInflicted(payload)
  if not payload or payload.battle ~= state.battle then return false end
  return enqueue(STATUS_CLIP[payload.status], PRIORITY.status,
    "status:" .. tostring(payload.status))
end

function Announcer.fainted(payload)
  if not payload or payload.battle ~= state.battle then return false end
  return enqueue(351, PRIORITY.faint, "faint")
end

function Announcer.finishBattle(payload)
  local battle = payload and payload.battle
  if battle ~= state.battle then return false end
  local won = payload.result == "win"
  local champion = state.champion
  resetPlayback()
  state.battle = nil
  state.intro = nil
  state.champion = false
  if not won or not enabled() or not packReady() then return false end
  enqueue(champion and 366 or 365, PRIORITY.result, "battle_result")
  return true
end

function Announcer.update(dt)
  if not enabled() then
    if state.current or #state.queue > 0 then resetPlayback() end
    return
  end
  if state.current then
    local ok, playing = pcall(state.current.isPlaying, state.current)
    if not ok or not playing then
      state.current = nil
      state.currentIndex = nil
      state.gap = GAP_SECONDS
    end
  elseif state.gap > 0 then
    state.gap = math.max(0, state.gap - (tonumber(dt) or 0))
  end
  startNext()
end

function Announcer.stop()
  resetPlayback()
  state.battle = nil
  state.intro = nil
  state.champion = false
end

function Announcer.status()
  return {
    packReady = packReady(),
    source = state.packSource,
    cachePath = CACHE_DIR,
    cacheError = state.cacheError,
    active = state.battle ~= nil,
    intro = state.intro,
    current = state.currentIndex,
    queued = #state.queue,
    missing = state.missing,
  }
end

Announcer.INTRO = INTRO
Announcer.PRIORITY = PRIORITY
Announcer.clipRelative = clipRelative
Announcer.introFor = introFor

return Announcer

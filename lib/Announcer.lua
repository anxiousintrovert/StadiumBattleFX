-- Optional Pokemon Stadium announcer playback for Gym Leader and Elite Four
-- battles. Voice files are never part of the public mod: the local Windows
-- builder injects assets/announcer/voicepack.json and numbered WAVs into a
-- personalized copy of the release ZIP. On first use that pack is imported
-- into save data, so later voice-free updates retain the local audio.

local namespace = ...
local mod = namespace.mod
local Storage = namespace.storage or (namespace.require and namespace.require("ModStorage"))

local Announcer = {}

local VOICE_ROOT = "assets/announcer"
local PACK_MARKER = VOICE_ROOT .. "/voicepack.json"
local CACHE_DIR = "stadium_battle_fx/announcer/v1"
local CACHE_MARKER = CACHE_DIR .. "/cache.info"
local CACHE_FORMAT = "SFXA1"
local CLIP_COUNT = 823
local GAP_SECONDS = 0.12
local MAX_QUEUE = 8
local FLOW_IDLE_SECONDS = 0.8
local FLOW_EVERY_MOVES = 2
local FLOW = { 756, 762, 780, 790, 814, 820 }
local FIRST_MOVE = { 181, 182 }
local SWITCH_PLAYER = { 245, 247, 248, 251 }
local SWITCH_ENEMY = { 253 }
local SUPER_EFFECTIVE = { 261, 262, 267 }
local NOT_EFFECTIVE = { 270, 317, 319 }
local CRITICAL = { 311, 312 }
local FAINT = { 349, 351, 357, 358 }
local DECISION_IDLE_SECONDS = 10
-- Stadium has three lines specifically for a trainer who leaves the command
-- menu sitting. Keep these separate from generic battle-flow commentary so
-- they only fire while the game is genuinely waiting for the player.
local DECISION_IDLE = { 749, 750, 751 }

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
  currentPriority = nil,
  queue = {},
  gap = 0,
  idle = 0,
  flowMoves = 0,
  flowPending = false,
  flowIndex = 0,
  decisionIdle = 0,
  decisionFingerprint = nil,
  decisionPrompted = false,
  decisionIndex = 0,
  pendingFaints = {},
  pendingActions = {},
  rotations = {},
  moveCount = 0,
  packChecked = false,
  packReady = false,
  packSource = nil,
  cacheError = nil,
  missing = {},
  warnedMissingPack = false,
  cacheJob = nil,
  cacheProgress = { state = "idle", done = 0, total = CLIP_COUNT },
}

local function enabled()
  return not (mod.options and mod.options.get)
      or mod.options:get("announcer") ~= false
end

-- Keep the original Gym/Elite Four/Champion behavior as the default for old
-- saves.  Wider scopes still use the same complete voice bank; ordinary
-- trainers and wild Pokemon simply have no dedicated entrance line.
local function scope()
  if not (mod.options and mod.options.get) then return "gym" end
  local value = mod.options:get("announcer_scope")
  if value == "all" or value == "trainer" then return value end
  return "gym"
end

local function isTrainerBattle(battle)
  -- `wild` is the engine's explicit non-trainer battle kind. Treat an absent
  -- kind as a trainer battle too so older engine payloads remain compatible.
  return battle and battle.kind ~= "wild"
end

local function eligible(battle, intro)
  local selected = scope()
  if selected == "all" then return battle ~= nil end
  if selected == "trainer" then return isTrainerBattle(battle) end
  return intro ~= nil
end

local function sourceMarker()
  local ok, marker = pcall(mod.read, mod, PACK_MARKER)
  if not (ok and type(marker) == "string" and #marker > 0) then return nil end
  -- The builder writes a complete 823-clip manifest. This guards against
  -- accidentally caching an arbitrary or interrupted package.
  if not marker:match('"clip_count"%s*:%s*823') then return nil end
  return marker
end

local function checksum(bytes)
  local a, b = 1, 0
  for i = 1, #bytes do
    a = (a + bytes:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

local function clipKey(index)
  return ("announcer/clips/%03d"):format(index)
end

local function cachedPack(expected)
  if not Storage then return false end
  local record = Storage.read("announcer/cache")
  if type(record) ~= "table" or record.format ~= CACHE_FORMAT
      or record.count ~= CLIP_COUNT then return false end
  return not expected or record.source == checksum(expected)
end

local function stopSource(source)
  if source and source.stop then pcall(source.stop, source) end
end

local function resetPlayback()
  stopSource(state.current)
  state.current = nil
  state.currentIndex = nil
  state.currentPriority = nil
  state.queue = {}
  state.gap = 0
  state.idle = 0
  state.flowMoves = 0
  state.flowPending = false
  state.decisionIdle = 0
  state.decisionFingerprint = nil
  state.decisionPrompted = false
  state.pendingFaints = {}
  state.pendingActions = {}
  state.rotations = {}
  state.moveCount = 0
end

local function packReady()
  if state.packChecked then return state.packReady end
  -- mod.storage needs an active playthrough. A status query during mod load
  -- must not permanently memoize the pack as missing before input.step hands
  -- us the live Game.
  if Storage and Storage.active and not Storage.active() then return false end
  state.packChecked = true
  local marker = sourceMarker()
  if cachedPack(marker) then
    state.packReady, state.packSource, state.cacheError = true, "cache", nil
    return true
  end
  if not marker then return false end
  -- The combined cache screen imports the bank incrementally. Until then the
  -- personalized package remains directly playable without a frame-length
  -- 823-file copy at battle start.
  state.packReady, state.packSource, state.cacheError = true, "package", nil
  return state.packReady
end

function Announcer.cachePending()
  if not Storage or (Storage.active and not Storage.active()) then return false end
  local marker = sourceMarker()
  return marker ~= nil and not cachedPack(marker)
end

function Announcer.beginCache(force)
  local marker = sourceMarker()
  if not marker then return false, "optional announcer pack is not installed" end
  if not force and cachedPack(marker) then
    state.cacheProgress.state, state.cacheProgress.done = "done", CLIP_COUNT
    return true
  end
  state.cacheJob = { marker = marker, index = 0 }
  state.cacheProgress.state, state.cacheProgress.done = "building", 0
  state.cacheProgress.error, state.cacheProgress.current = nil, "VOICE 000/823"
  return true
end

function Announcer.stepCache()
  local job = state.cacheJob
  if not job then return false end
  local index = job.index
  local ok, bytes = pcall(mod.read, mod, ("%s/%03d.wav"):format(VOICE_ROOT, index))
  if not (ok and type(bytes) == "string" and #bytes > 44) then
    state.cacheProgress.state = "failed"
    state.cacheProgress.error = "voice pack is missing clip " .. tostring(index)
    state.cacheJob = nil
    return false
  end
  local wrote, code, message = Storage.writeBytes(clipKey(index), bytes)
  if not wrote then
    state.cacheProgress.state = "failed"
    state.cacheProgress.error = tostring(message or code or "voice cache write failed")
    state.cacheJob = nil
    return false
  end
  job.index = index + 1
  state.cacheProgress.done = job.index
  state.cacheProgress.current = ("VOICE %03d/823"):format(job.index)
  if job.index < CLIP_COUNT then return true end
  wrote, code, message = Storage.write("announcer/cache", {
    format = CACHE_FORMAT, count = CLIP_COUNT, source = checksum(job.marker),
  })
  if not wrote then
    state.cacheProgress.state = "failed"
    state.cacheProgress.error = tostring(message or code or "voice marker write failed")
  else
    state.cacheProgress.state, state.cacheProgress.current = "done", "READY"
    state.packChecked, state.packReady, state.packSource = true, true, "cache"
  end
  state.cacheJob = nil
  return false
end

function Announcer.cacheStatus()
  return {
    state = state.cacheProgress.state,
    done = state.cacheProgress.done,
    total = CLIP_COUNT,
    current = state.cacheProgress.current,
    error = state.cacheProgress.error,
    ready = cachedPack(sourceMarker()),
    installed = sourceMarker() ~= nil,
  }
end

function Announcer.cancelCache()
  state.cacheJob = nil
  if state.cacheProgress.state == "building" then
    state.cacheProgress.state, state.cacheProgress.done = "idle", 0
  end
end

local function clipRelative(index)
  return ("%s/%03d.wav"):format(VOICE_ROOT, index)
end

local function clipPath(index)
  local relative = clipRelative(index)
  if mod.assets and mod.assets.path then
    return mod.assets:path(relative)
  end
  return tostring(mod.path or "") .. "/" .. relative
end

local function cachedSoundData(bytes)
  if not (love and love.sound and love.sound.newSoundData) then
    return nil, "sound data API unavailable"
  end
  if type(bytes) ~= "string" or bytes:sub(1, 4) ~= "RIFF"
      or bytes:sub(9, 12) ~= "WAVE" then return nil, "invalid WAV" end
  local function u16(at)
    local a, b = bytes:byte(at, at + 1)
    return a and b and (a + b * 256) or nil
  end
  local function u32(at)
    local a, b, c, d = bytes:byte(at, at + 3)
    return a and d and (a + b * 256 + c * 65536 + d * 16777216) or nil
  end
  local at, channels, rate, bits, dataAt, dataSize = 13
  while at + 7 <= #bytes do
    local kind, size = bytes:sub(at, at + 3), u32(at + 4)
    if not size or at + 7 + size > #bytes then return nil, "truncated WAV" end
    if kind == "fmt " and size >= 16 then
      local encoding = u16(at + 8)
      channels, rate, bits = u16(at + 10), u32(at + 12), u16(at + 22)
      if encoding ~= 1 then return nil, "unsupported WAV encoding" end
    elseif kind == "data" then
      dataAt, dataSize = at + 8, size
    end
    at = at + 8 + size + (size % 2)
  end
  if channels ~= 1 or rate ~= 16000 or bits ~= 16 or not dataAt then
    return nil, "expected mono 16-bit 16000 Hz WAV"
  end
  local samples = math.floor(dataSize / 2)
  local ok, sound = pcall(love.sound.newSoundData, samples, rate, bits, channels)
  if not (ok and sound) then return nil, tostring(sound) end
  for index = 0, samples - 1 do
    local lo, hi = bytes:byte(dataAt + index * 2, dataAt + index * 2 + 1)
    local value = lo + hi * 256
    if value >= 32768 then value = value - 65536 end
    sound:setSample(index, math.max(-1, value / 32768))
  end
  return sound
end

local function loadSource(index)
  if state.missing[index] then return nil end
  if not (love and love.audio and love.audio.newSource) then return nil end
  local input = clipPath(index)
  if state.packSource == "cache" and Storage then
    local bytes = Storage.bytes(clipKey(index))
    if type(bytes) ~= "string" then state.missing[index] = true return nil end
    input = cachedSoundData(bytes)
    if not input then state.missing[index] = true return nil end
  end
  local ok, source = pcall(love.audio.newSource, input, "static")
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
        state.currentPriority = item.priority
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
  -- Commentary is deliberately disposable. A new battle event interrupts it
  -- rather than leaving a move, faint, or switch waiting behind flavor text.
  if state.current and state.currentPriority == PRIORITY.ambient
      and (priority or 0) > PRIORITY.ambient then
    stopSource(state.current)
    state.current = nil
    state.currentIndex = nil
    state.currentPriority = nil
    state.gap = 0
  end
  local item = { index = index, priority = priority or 0, key = key }
  -- Once a later, more important visible beat has arrived, older lower-level
  -- speech is stale. Do not let a move name play after its damage reaction or
  -- a switch call play after a knockout merely because audio was busy.
  for i = #state.queue, 1, -1 do
    if state.queue[i].priority < item.priority then table.remove(state.queue, i) end
  end
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

local faintReady

local function rotate(name, clips)
  local at = (state.rotations[name] or 0) % #clips + 1
  state.rotations[name] = at
  return clips[at]
end

local function textVisible(battle)
  local current = battle and battle.current
  return (current and current.text) or (battle and battle.msgHold) or false
end

local function sideFor(battle, battler, eventSide)
  if eventSide and tonumber(eventSide.index) == 1 then return "player" end
  if eventSide and tonumber(eventSide.index) == 2 then return "enemy" end
  if not (battle and battler) then return nil end
  if battler == battle.player or battler.isPlayer then return "player" end
  if battler == battle.enemy then return "enemy" end
  return nil
end

-- Gen1Recomp uses battler_switched for every replacement, including opening
-- link-battle send-outs and the Pokemon that enters after a knockout. Only a
-- living Pokemon being withdrawn is a trainer-initiated change. The broader
-- events still get the incoming species call, but must not claim that either
-- trainer chose to change Pokemon.
local function trainerChangedPokemon(payload)
  local previous = payload and payload.previous
  local battler = payload and payload.battler
  if not (previous and battler) or previous == battler then return false end
  if previous.mon and battler.mon and previous.mon == battler.mon then
    return false
  end
  local hp = previous.mon and tonumber(previous.mon.hp)
  if hp == nil then hp = tonumber(previous.shownHP) end
  return hp == nil or hp > 0
end

local function sideBattler(battle, side)
  return battle and battle[side]
end

local function sideSending(battle, side)
  if not battle then return false end
  return side == "player" and battle.sendingOut or battle.enemySendingOut
end

local function deferAction(action)
  if not action or not action.key then return false end
  for i = #state.pendingActions, 1, -1 do
    if state.pendingActions[i].key == action.key then
      table.remove(state.pendingActions, i)
    end
  end
  action.age = 0
  state.pendingActions[#state.pendingActions + 1] = action
  return true
end

local function sendoutReady(action)
  local battle = action.battle
  if battle ~= state.battle
     or sideBattler(battle, action.side) ~= action.battler then
    return nil
  end
  local text = textVisible(battle)
  local sending = sideSending(battle, action.side)
  if text then action.seenText = true end
  if sending then action.seenSending = true end
  if text or sending then return false end
  if action.requireSending then return action.seenSending and true or false end
  return (action.seenSending or action.seenText) and true or false
end

local function messageReady(action)
  if action.battle ~= state.battle then return nil end
  if textVisible(action.battle) then action.seenBusy = true return false end
  return action.seenBusy and true or false
end

local function moveReady(action)
  local battle = action.battle
  if battle ~= state.battle then return nil end
  if battle.animPlaying and battle.animName == action.anim then return true end
  -- With battle animations disabled there is no animation edge. In that
  -- case the cleared move text is the visible action boundary.
  return messageReady(action)
end

local function damageReady(action)
  if action.battle ~= state.battle then return nil end
  local target = action.target
  if not target then return true end
  if target.draining then return true end
  local shown = tonumber(target.shownHP)
  return shown and action.shownHP and shown ~= action.shownHP or false
end

local function faintActionReady(action)
  if action.battle ~= state.battle then return nil end
  return faintReady(action.battler) and action.battler.fainted and true or false
end

local function releaseAction(action)
  if action.switchClip then
    enqueue(action.switchClip, PRIORITY.sendout, action.key .. ":switch")
  end
  if action.firstMove then
    enqueue(action.firstMove, PRIORITY.move, action.key .. ":first")
  end
  return enqueue(action.clip, action.priority, action.key)
end

local function playReadyActions(dt)
  local i = 1
  while i <= #state.pendingActions do
    local action = state.pendingActions[i]
    action.age = action.age + math.max(0, tonumber(dt) or 0)
    local ready = action.ready(action)
    if ready == nil or action.age > 30 then
      table.remove(state.pendingActions, i)
    elseif ready then
      table.remove(state.pendingActions, i)
      releaseAction(action)
    else
      i = i + 1
    end
  end
end

local function noteMoveForFlow()
  state.flowMoves = state.flowMoves + 1
  if state.flowMoves >= FLOW_EVERY_MOVES then
    state.flowMoves = 0
    state.flowPending = true
  end
end

local function startFlowCommentary()
  if not state.flowPending or state.current or #state.queue > 0
     or #state.pendingActions > 0 or state.gap > 0 then
    return false
  end
  state.flowPending = false
  state.flowIndex = state.flowIndex % #FLOW + 1
  return enqueue(FLOW[state.flowIndex], PRIORITY.ambient, "battle_flow")
end

local function gameInputPending(game)
  local queue = game and game.input and game.input.pressQueue
  return type(queue) == "table" and #queue > 0
end

local function decisionFingerprint(game)
  local battle = state.battle
  if not battle or battle.demo or battle.safari then return nil end

  -- A party, bag, choice box, or pause screen can leave BattleState.phase at
  -- `menu` while another state owns input. Do not heckle the player there.
  local liveGame = game or battle.game
  local stack = liveGame and liveGame.stack
  if stack and type(stack.top) == "function" then
    local ok, top = pcall(stack.top, stack)
    if ok and top ~= battle then return nil end
  end

  local phase = battle.phase
  if phase == "menu" then
    local hp = battle.player and battle.player.mon and tonumber(battle.player.mon.hp)
    if hp and hp <= 0 then return nil end -- replacement menu opens next tick
    return phase .. ":" .. tostring(battle.menuIndex or 1)
  elseif phase == "moveSelect" then
    return phase .. ":" .. tostring(battle.moveIndex or 1)
      .. ":" .. tostring(battle.moveSwapIndex or "")
  elseif phase == "mimicSelect" then
    return phase .. ":" .. tostring(battle.mimicIndex or 1)
  end
  return nil
end

local function updateDecisionIdle(dt, game)
  local fingerprint = decisionFingerprint(game)
  if not fingerprint then
    state.decisionIdle = 0
    state.decisionFingerprint = nil
    state.decisionPrompted = false
    return
  end

  local active = gameInputPending(game or (state.battle and state.battle.game))
  if active or fingerprint ~= state.decisionFingerprint then
    state.decisionIdle = 0
    state.decisionPrompted = false
  end
  state.decisionFingerprint = fingerprint
  if active or state.decisionPrompted then return end

  state.decisionIdle = state.decisionIdle + math.max(0, tonumber(dt) or 0)
  if state.decisionIdle < DECISION_IDLE_SECONDS then return end
  -- Do not queue a stale prompt behind an introduction or battle event. Once
  -- the announcer is quiet, the same still-idle decision can claim the gap.
  if state.current or #state.queue > 0 or #state.pendingActions > 0
     or state.gap > 0 then return end
  state.decisionIndex = state.decisionIndex % #DECISION_IDLE + 1
  if enqueue(DECISION_IDLE[state.decisionIndex], PRIORITY.ambient, "decision_idle") then
    state.decisionPrompted = true
  end
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

function Announcer.beginBattle(battle)
  resetPlayback()
  state.battle = nil
  state.intro = nil
  state.champion = false
  if not enabled() then return false end
  local intro = introFor(battle)
  if not eligible(battle, intro) then return false end
  if not packReady() then
    local logger = namespace.log or mod.log
    if not state.warnedMissingPack and logger and logger.info then
      state.warnedMissingPack = true
      logger:info("optional Stadium announcer voice pack not installed; battle audio unchanged")
    end
    return false
  end
  state.battle = battle
  state.intro = intro and intro.clip or nil
  state.champion = intro and intro.champion or false
  if intro then enqueue(intro.clip, PRIORITY.intro, "encounter_intro") end
  -- The battle event is emitted while Gen1Recomp is still BUILDING its intro
  -- queue. Keep both names pending until each side's send-out text has been
  -- dismissed and its entry flag has dropped.
  for _, side in ipairs({ "enemy", "player" }) do
    local battler = battle[side]
    local dex = dexFor(battle, battler)
    if dex then
      deferAction({ battle = battle, battler = battler, side = side,
        clip = 368 + dex, priority = PRIORITY.sendout,
        key = "initial_" .. side, ready = sendoutReady,
        requireSending = true,
        seenText = textVisible(battle),
        seenSending = sideSending(battle, side) and true or false })
    end
  end
  return true
end

function Announcer.battlerSwitched(payload)
  local battle = payload and payload.battle
  if battle ~= state.battle then return false end
  local battler = payload.battler
  local side = sideFor(battle, battler, payload.side)
  local dex = dexFor(battle, battler)
  if not (side and dex) then return false end
  return deferAction({ battle = battle, battler = battler, side = side,
    clip = 368 + dex, priority = PRIORITY.sendout,
    switchClip = trainerChangedPokemon(payload)
      and rotate(side .. "_switch",
        side == "player" and SWITCH_PLAYER or SWITCH_ENEMY) or nil,
    key = side .. "_sendout", ready = sendoutReady,
    seenText = textVisible(battle),
    seenSending = sideSending(battle, side) and true or false })
end

function Announcer.moveUsed(payload)
  local battle = payload and payload.battle
  if battle ~= state.battle then return false end
  local moveIndex = payload.move and tonumber(payload.move.index)
  if not moveIndex or moveIndex < 1 or moveIndex > 165 then return false end
  state.moveCount = state.moveCount + 1
  local queued = deferAction({ battle = battle, anim = payload.move.id,
    clip = 583 + moveIndex, priority = PRIORITY.move,
    firstMove = state.moveCount == 1 and rotate("first_move", FIRST_MOVE) or nil,
    key = "move:" .. tostring(state.moveCount), ready = moveReady,
    seenBusy = textVisible(battle) })
  noteMoveForFlow()
  return queued
end

function Announcer.damageDealt(payload)
  if not payload or payload.battle ~= state.battle then return false end
  local clip
  if payload.crit then clip = rotate("critical", CRITICAL) end
  local mult = tonumber(payload.typeMult)
  if not clip and mult and mult > 10 then
    clip = rotate("super_effective", SUPER_EFFECTIVE)
  elseif not clip and mult and mult < 10 then
    clip = rotate("not_effective", NOT_EFFECTIVE)
  end
  if not clip then return false end
  return deferAction({ battle = payload.battle, target = payload.target,
    shownHP = payload.target and tonumber(payload.target.shownHP),
    clip = clip, priority = PRIORITY.damage,
    key = "damage_reaction", ready = damageReady })
end

function Announcer.statusInflicted(payload)
  if not payload or payload.battle ~= state.battle then return false end
  local clip = STATUS_CLIP[payload.status]
  if not clip then return false end
  return deferAction({ battle = payload.battle, clip = clip,
    priority = PRIORITY.status, key = "status:" .. tostring(payload.status),
    ready = messageReady, seenBusy = textVisible(payload.battle) })
end

-- `battle.fainted` is emitted when the battle logic sets a Pokemon's real HP
-- to zero.  The UI drains `shownHP` afterwards, so wait for that displayed
-- value before playing the Stadium knockout call.
faintReady = function(battler)
  if not battler then return false end
  if battler.shownHP ~= nil then
    return tonumber(battler.shownHP) and tonumber(battler.shownHP) <= 0
  end
  local mon = battler.mon
  return mon and tonumber(mon.hp) and tonumber(mon.hp) <= 0
end

function Announcer.fainted(payload)
  local battler = payload and payload.battler
  if not battler or payload.battle ~= state.battle then return false end
  return deferAction({ battle = payload.battle, battler = battler,
    clip = rotate("faint", FAINT), priority = PRIORITY.faint,
    key = "faint:" .. tostring(battler), ready = faintActionReady })
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

function Announcer.update(dt, game)
  if not enabled() then
    if state.current or #state.queue > 0 then resetPlayback() end
    return
  end
  if state.current then
    local ok, playing = pcall(state.current.isPlaying, state.current)
    if not ok or not playing then
      state.current = nil
      state.currentIndex = nil
      state.currentPriority = nil
      state.gap = GAP_SECONDS
    end
  elseif state.gap > 0 then
    state.gap = math.max(0, state.gap - (tonumber(dt) or 0))
  end
  playReadyActions(dt)
  updateDecisionIdle(dt, game)
  if not state.current and #state.queue == 0
     and #state.pendingActions == 0 and state.gap <= 0 then
    state.idle = state.idle + math.max(0, tonumber(dt) or 0)
    if state.idle >= FLOW_IDLE_SECONDS then
      state.idle = 0
      startFlowCommentary()
    end
  else
    state.idle = 0
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
    pendingFaints = next(state.pendingFaints) ~= nil,
    pendingActions = #state.pendingActions,
    flowPending = state.flowPending,
    decisionIdle = state.decisionIdle,
    decisionPrompted = state.decisionPrompted,
    missing = state.missing,
  }
end

Announcer.INTRO = INTRO
Announcer.PRIORITY = PRIORITY
Announcer.DECISION_IDLE = DECISION_IDLE
Announcer.DECISION_IDLE_SECONDS = DECISION_IDLE_SECONDS
Announcer.clipRelative = clipRelative
Announcer.introFor = introFor
Announcer.scope = scope
Announcer.eligible = eligible

return Announcer

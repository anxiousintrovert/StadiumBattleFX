-- End-to-end Gen1Recomp driver for StadiumBattleFX's first supported move.
-- Run from Gen1Recomp through POKEPORT_DRIVER so this exercises the actual
-- mod loader, BattleState event, move queue, and rendering path.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local dir = os.getenv("SHOT_DIR") or "runtime-shots"

  local function logStatus(label, battle)
    local player = battle and battle.animPlayer
    U.log(label,
      "phase=" .. tostring(battle and battle.phase),
      "anim=" .. tostring(battle and battle.animPlaying),
      "adapter=" .. tostring(player and player.custom ~= nil),
      "custom=" .. tostring(player and player.custom),
      "tick=" .. tostring(player and player.tick),
      "particles=" .. tostring(player and player.particles and #player.particles))
  end

  for _, entry in ipairs((game.modStatus and game.modStatus.available) or {}) do
    U.log("mod", entry.id, "enabled=" .. tostring(entry.enabled),
      "state=" .. tostring(entry.state), "error=" .. tostring(entry.error))
  end
  for _, err in ipairs((game.modStatus and game.modStatus.errors) or {}) do
    U.log("mod-error", tostring(err))
  end

  game.save.options.animations = true
  local Pokemon = require("src.pokemon.Pokemon")
  local pikachu = Pokemon.new(game.data, "PIKACHU", 12)
  pikachu.moves = { { id = "THUNDERSHOCK", pp = 30 } }
  game.save.party = { pikachu }

  U.teleport(game, "ROUTE_4", 18, 6, "down")
  local ow = game.overworld
  -- Dramatic Shapes may put its one-time Stadium extraction screen above the
  -- overworld here. Let that real companion-mod path finish before creating
  -- the battle; a clean cache takes roughly ten seconds on desktop.
  for _ = 1, 1800 do
    if game.stack:top() == ow then break end
    U.wait(1)
  end
  assert(game.stack:top() == ow, "overworld remained covered before battle")
  local BattleState = require("src.battle.BattleState")
  local battle = BattleState.newWild(game, "ZUBAT", 8)
  battle.onFinish = function() end
  ow:pushBattle(battle)

  -- Advance every message but stop before a menu press can spill into FIGHT.
  for _ = 1, 500 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(2)
  end
  assert(battle.phase == "menu", "battle never reached the command menu")
  logStatus("at-menu", battle)
  assert(U.shot(game, dir .. "/00_menu.png"))

  U.tap(game, "a") -- FIGHT
  for _ = 1, 120 do
    if battle.phase == "moveSelect" then break end
    U.wait(1)
  end
  assert(battle.phase == "moveSelect", "battle never reached move selection")
  U.log("selected-move", tostring(battle.player.curMoves[1].id))
  assert(U.shot(game, dir .. "/01_moves.png"))

  U.tap(game, "a") -- THUNDERSHOCK
  for _ = 1, 360 do
    if battle.animPlaying then break end
    if battle.phase == "messages" then U.tap(game, "a") else U.wait(1) end
  end
  assert(battle.animPlaying, "Thunder Shock animation never started")
  logStatus("anim-start", battle)

  local captures = {
    { 1, "02_tick01.png" },
    { 12, "03_tick12.png" },
    { 36, "04_tick36.png" },
    { 45, "05_tick45.png" },
    { 52, "06_tick52.png" },
    { 76, "07_tick76.png" },
  }
  for _, capture in ipairs(captures) do
    while battle.animPlaying and (battle.animPlayer.tick or 0) < capture[1] do
      U.wait(1)
    end
    logStatus("capture-" .. capture[1], battle)
    assert(U.shot(game, dir .. "/" .. capture[2]))
  end

  while battle.animPlaying do U.wait(1) end
  logStatus("anim-complete", battle)
  assert(U.shot(game, dir .. "/08_after.png"))
end

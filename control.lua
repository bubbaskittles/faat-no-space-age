-- F.A.A.T. (No DLC)
-- Based on Fish Addicts Anonymous Timer by Orbital917, used under the MIT License.
-- https://mods.factorio.com/mod/fish-addicts-anonymous-timer
--
-- Changes in this fork:
--   * No Space Age dependency.
--   * Timer state lives in `storage`, so it is saved with the game
--     (optional carryover between loads, and no multiplayer desyncs from local state).
--   * Optional lockout: once time runs out the save stays locked until /faat-unlock.

local TICKS_PER_SECOND = 60
local TICKS_PER_MINUTE = 60 * TICKS_PER_SECOND
local END_BUFFER_TICKS = 2 * TICKS_PER_SECOND     -- when remaining time drops to this, the session ends
local CLOSE_DELAY_TICKS = 3 * TICKS_PER_SECOND    -- save after 1 second, close after 3
local LOCKED_GRACE_TICKS = 30 * TICKS_PER_SECOND  -- time to type /faat-unlock on a locked save
local MEMORIAL_SURFACE = "addiction-timer-memorial"

local YELLOW = {r=1, g=0.8, b=0}
local BLUE = {r=0, g=0.8, b=1}
local RED = {r=1, g=0, b=0}
local ORANGE = {r=1, g=0.5, b=0}
local WHITE = {r=1, g=1, b=1}

-- Not saved. Only used to notice a fresh load in single player and to avoid
-- running the session start twice in the same tick.
local loaded_from_save = false
local last_session_start_tick = nil

local function setting(name)
  return settings.global[name].value
end

local function target_ticks()
  return setting("addiction-timer-minutes") * TICKS_PER_MINUTE
end

-- Only call from events/commands: it may write to storage.
local function state()
  storage.memorial_dates = storage.memorial_dates or {}
  storage.faat = storage.faat or {}
  local s = storage.faat
  s.played_ticks = s.played_ticks or 0
  s.last_tick = s.last_tick or game.tick
  return s
end

local function format_time(ticks)
  local total_seconds = math.max(0, math.ceil(ticks / TICKS_PER_SECOND))
  return string.format("%d minutes, %d seconds", math.floor(total_seconds / 60), total_seconds % 60)
end

local function get_day_identifier()
  -- Game-time "day": 24 hours of game ticks. Factorio mods cannot read the real date.
  local ticks_per_day = 60 * 60 * 60 * 24
  return "day_" .. math.floor(game.tick / ticks_per_day)
end

local function create_fish_memorial_surface()
  local surface = game.get_surface(MEMORIAL_SURFACE)
  if not surface then
    -- A small all-water surface that players never visit
    surface = game.create_surface(MEMORIAL_SURFACE, {
      width = 64,
      height = 64,
      peaceful_mode = true,
      water = 1,
      starting_area = "none",
      property_expression_names = {
        elevation = "0",
        temperature = "15",
        moisture = "1",
        aux = "0",
        cliffiness = "0",
        enemy_base_intensity = "0",
        enemy_base_frequency = "0"
      }
    })
    surface.peaceful_mode = true
    surface.freeze_daytime = true
    surface.daytime = 0.5
  end
  return surface
end

local function place_memorial_fish()
  local today_id = get_day_identifier()
  local surface = create_fish_memorial_surface()

  local water_tiles = surface.find_tiles_filtered{
    name = {"water", "deepwater", "water-green", "deepwater-green"},
    area = {{-16, -16}, {16, 16}}
  }
  if #water_tiles > 0 then
    local tile = water_tiles[math.random(#water_tiles)]
    surface.create_entity{name = "fish", position = {tile.position.x + 0.5, tile.position.y + 0.5}}
  end

  local fish_count = surface.count_entities_filtered{name = "fish"}
  storage.memorial_dates[today_id] = true
  game.print("Memorial fish placed for " .. today_id .. ". Total sessions ended: " .. fish_count, BLUE)
end

local function close_game(reason)
  game.print("Goodbye!", WHITE)
  if game.is_multiplayer() then
    for _, player in pairs(game.connected_players) do
      game.kick_player(player, reason)
    end
  end
  -- Mods have no API to quit the game, so (like the original mod) we stop it with a deliberate script error.
  error("F.A.A.T.: " .. reason .. ". The factory must rest.")
end

-- Runs once each time the game starts: new game, mod added to a save, or a save is loaded.
local function on_session_start()
  loaded_from_save = false -- on_singleplayer_init may already have handled this load
  if last_session_start_tick == game.tick then return end
  last_session_start_tick = game.tick

  local s = state()
  s.close_at = nil
  s.save_pending = false
  s.disabled = false
  s.last_tick = game.tick

  if s.locked then
    if setting("faat-lockout") then
      game.print("This save is locked: the addiction timer ran out. The factory must rest.", ORANGE)
      game.print("Closing in 30 seconds. When your day is over, type /faat-unlock to start a new day.", ORANGE)
      s.close_at = game.tick + LOCKED_GRACE_TICKS
      return
    end
    -- Lockout was switched off since the save was locked: treat it as a new day.
    s.locked = false
    s.played_ticks = 0
    s.warned = false
  end

  if not setting("faat-carryover") then
    s.played_ticks = 0
    s.warned = false
  end

  game.print("Addiction timer enabled: game will save and close in " .. format_time(target_ticks() - s.played_ticks) .. ".", YELLOW)
  game.print("A memorial fish will be placed when the session ends.", BLUE)
end

local function end_session(s)
  place_memorial_fish()
  if setting("faat-lockout") then
    s.locked = true
  else
    s.played_ticks = 0 -- next load starts a fresh timer
  end
  s.warned = false
  -- Save on the next pass (so the lock is already in the save), then close.
  s.save_pending = true
  s.close_at = game.tick + CLOSE_DELAY_TICKS
end

local function on_second()
  if loaded_from_save then
    loaded_from_save = false
    -- In multiplayer, on_load also runs on every joining client, so only trust it in single player.
    -- Multiplayer hosts use on_multiplayer_init instead.
    if not game.is_multiplayer() then on_session_start() end
  end

  local s = state()
  local now = game.tick

  if s.close_at then
    if s.save_pending then
      s.save_pending = false
      game.auto_save("addiction-timer-" .. get_day_identifier() .. "-" .. now)
    end
    local left = s.close_at - now
    if left <= 0 then
      close_game(s.locked and "This save is locked" or "Session time limit reached")
    end
    local secs = math.ceil(left / TICKS_PER_SECOND)
    if secs <= 10 or secs % 10 == 0 then
      game.print("Addiction timer closing in " .. secs .. " seconds...", RED)
    end
    return
  end

  local delta = now - s.last_tick
  s.last_tick = now
  if s.disabled then return end
  s.played_ticks = s.played_ticks + math.max(0, delta)

  local remaining = target_ticks() - s.played_ticks

  local warning_ticks = setting("faat-warning-minutes") * TICKS_PER_MINUTE
  if warning_ticks > 0 and remaining <= warning_ticks and not s.warned then
    s.warned = true
    game.print("WARNING: " .. format_time(remaining) .. " remaining. The game will then save and close!", RED)
    for _, player in pairs(game.connected_players) do
      player.play_sound{path = "utility/alert_destroyed"}
    end
  end

  if remaining <= END_BUFFER_TICKS then
    end_session(s)
  elseif remaining <= TICKS_PER_MINUTE then
    local secs = math.ceil(remaining / TICKS_PER_SECOND)
    if secs <= 10 or secs % 10 == 0 then
      game.print("Addiction timer closing in " .. secs .. " seconds...", RED)
    end
  end
end

-- Commands -------------------------------------------------------------------

local function command_player(event)
  return event.player_index and game.get_player(event.player_index) or nil
end

local function is_admin(player)
  return player == nil or player.admin -- nil = server console
end

local function on_remaining_time_command(event)
  local s = state()
  if s.close_at then
    game.print(s.locked and "This save is locked. Type /faat-unlock to start a new day." or "The game is closing now.")
  elseif s.disabled then
    game.print("Addiction timer is disabled until the next load.")
  else
    game.print("Time remaining: " .. format_time(target_ticks() - s.played_ticks))
  end
end

local function on_disable_timer_command(event)
  local player = command_player(event)
  if not is_admin(player) then
    game.print("Only admins can disable the addiction timer.")
    return
  end
  local s = state()
  if s.close_at then
    game.print("Too late to disable the timer now. Use /faat-unlock on a locked save.")
    return
  end
  s.disabled = true
  game.print("Addiction timer disabled until the next load by " .. (player and player.name or "the server"), {r=1, g=1, b=0})
end

local function on_unlock_command(event)
  local player = command_player(event)
  if not is_admin(player) then
    game.print("Only admins can unlock the save.")
    return
  end
  local s = state()
  if not s.locked then
    game.print("This save isn't locked.")
    return
  end
  s.locked = false
  s.played_ticks = 0
  s.warned = false
  s.close_at = nil
  s.save_pending = false
  s.last_tick = game.tick
  game.print("Save unlocked. New day, new timer: " .. format_time(target_ticks()) .. ".", YELLOW)
end

local function on_view_memorial_command(event)
  local player = command_player(event)
  if not player then return end

  local surface = game.get_surface(MEMORIAL_SURFACE)
  local fish_count = surface and surface.count_entities_filtered{name = "fish"} or 0
  if fish_count == 0 then
    player.print("No memorial fish have been placed yet.")
    return
  end
  player.print("Memorial fish count: " .. fish_count .. " session(s) ended by addiction timer.")

  local dates = {}
  for date, _ in pairs(state() and storage.memorial_dates or {}) do
    table.insert(dates, date)
  end
  table.sort(dates)
  if #dates > 0 then
    player.print("Recorded sessions: " .. table.concat(dates, ", "))
  end
  if player.admin then
    player.print("Admin privilege: You can visit the memorial surface with /c game.player.teleport({0,0}, '" .. MEMORIAL_SURFACE .. "')")
  end
end

-- Event handlers ---------------------------------------------------------------

script.on_init(on_session_start)
script.on_configuration_changed(function() state() end)
script.on_load(function() loaded_from_save = true end)
script.on_event({defines.events.on_singleplayer_init, defines.events.on_multiplayer_init}, on_session_start)
script.on_nth_tick(60, on_second)

commands.add_command("time-remaining", "Check how much time is left before the addiction timer closes the game", on_remaining_time_command)
commands.add_command("disable-timer", "Disable the addiction timer until the next load (admin only)", on_disable_timer_command)
commands.add_command("faat-unlock", "Unlock a save locked by the addiction timer and start a new day (admin only)", on_unlock_command)
commands.add_command("view-memorial", "View information about memorial fish from past sessions", on_view_memorial_command)

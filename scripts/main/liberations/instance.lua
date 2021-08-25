local PlayerSession = require("scripts/main/liberations/player_session")
local Enemy = require("scripts/main/liberations/enemy")
local EnemyHelpers = require("scripts/main/liberations/enemy_helpers")
local Loot = require("scripts/main/liberations/loot")
local Preloader = require("scripts/main/liberations/preloader")

local debug = true

-- private functions

local function is_panel(self, object)
  return object.data.type == "tile" and object.data.gid >= self.FIRST_PANEL_GID and object.data.gid <= self.LAST_PANEL_GID
end

local function is_adjacent(position_a, position_b)
  if position_a.z ~= position_b.z then
    return false
  end

  local x_diff = math.abs(math.floor(position_a.x) - math.floor(position_b.x))
  local y_diff = math.abs(math.floor(position_a.y) - math.floor(position_b.y))

  return x_diff + y_diff == 1
end

local DARK_HOLE_SHAPE = {
  {1, 1, 1},
  {1, 1, 1},
  {1, 1, 1},
}

-- expects execution in a coroutine
local function convert_indestructible_panels(self)
  local slide_time = .5
  local hold_time = 2

  -- notify players
  for _, player_session in pairs(self.player_sessions) do
    player_session.player:message("No more DarkHoles! Nothing will save the Darkloids now!")

    local player = player_session.player

    Net.lock_player_input(player.id)

    Net.slide_player_camera(player.id, self.boss.x, self.boss.y, self.boss.z, slide_time)

    -- hold the camera
    Net.move_player_camera(player.id, self.boss.x, self.boss.y, self.boss.z, hold_time)

    -- return the camera
    Net.slide_player_camera(player.id, player.x, player.y, player.z, slide_time)
    Net.unlock_player_camera(player.id)
  end

  Async.await(Async.sleep(slide_time + hold_time / 2))

  -- convert panels
  for _, panel in ipairs(self.indestructible_panels) do
    panel.data.gid = self.BASIC_PANEL_GID
    Net.set_object_data(self.area_id, panel.id, panel.data)
  end

  self.indestructible_panels = nil

  Async.await(Async.sleep(hold_time / 2 + slide_time))

  -- returning control
  for _, player_session in pairs(self.player_sessions) do
    if not player_session.completed_turn then
      Net.unlock_player_input(player_session.player.id)
    end
  end
end

-- todo: pass terrain? https://megaman.fandom.com/wiki/Liberation_Mission#:~:text=corresponding%20Barrier%20Panel.-,Terrain,-Depending%20on%20the
local function liberate_panel(self, player_session)
  local selection = player_session.selection
  local panel = selection.root_panel

  local co = coroutine.create(function()
    if panel.data.gid == self.BONUS_PANEL_GID then
      Async.await(player_session.player:message_with_mug("A BonusPanel!"))

      self:remove_panel(panel)
      selection:clear()

      Async.await(Loot.loot_bonus_panel(self, player_session, panel))

      Net.unlock_player_input(player_session.player.id)
    elseif panel.data.gid == self.DARK_HOLE_PANEL_GID then
      Async.await(player_session.player:message_with_mug("Let's do it! Liberate panels!"))

      -- todo: battle

      selection:set_shape(DARK_HOLE_SHAPE, 0, -1)
      local panels = selection:get_panels()

      Async.await(player_session:liberate_panels(panels))

      -- destroy any spawned enemies
      Async.await(Enemy.destroy(self, panel.enemy))

      if #self.dark_holes == 0 then
        convert_indestructible_panels(self)
      end

      -- looting occurs last
      Async.await(player_session:loot_panels(panels))

      player_session:complete_turn()
    else
      Async.await(player_session.player:message_with_mug("Let's do it! Liberate panels!"))

      -- todo: battle

      -- destroy enemy
      local enemy = self:get_enemy_at(panel.x, panel.y, panel.z)
      if enemy then
        Async.await(Enemy.destroy(self, enemy))
      end

      local panels = player_session.selection:get_panels()
      Async.await(player_session:liberate_and_loot_panels(panels))
      player_session:complete_turn()
    end
  end)

  Async.promisify(co)
end

local function take_enemy_turn(self)
  local hold_time = .15
  local slide_time = .5

  local co = coroutine.create(function()
    for _, enemy in ipairs(self.enemies) do
      for _, player in ipairs(self.players) do
        Net.slide_player_camera(player.id, enemy.x + .5, enemy.y + .5, enemy.z, slide_time)
      end

      -- wait until the camera is done moving
      Async.await(Async.sleep(slide_time))

      if enemy.is_boss then
        -- darkloids heal up to 50% of health during their turn
        Async.await(EnemyHelpers.heal(enemy, enemy.max_health / 2))
      end

      Async.await(enemy:take_turn())

      -- wait a short amount of time to look nicer if there was no action taken
      Async.await(Async.sleep(hold_time))
    end

    -- dark holes!
    for _, dark_hole in ipairs(self.dark_holes) do
      -- see if we need to spawn a new enemy
      if Enemy.is_alive(dark_hole.enemy) then
        goto continue
      end

      -- find an available space
      -- todo: move out of func
      local neighbor_offsets = {
        { 1, -1 },
        { 1, 0 },
        { 1, 1 },
        { -1, -1 },
        { -1, 0 },
        { -1, 1 },
        { 0, 1 },
        { 0, -1 },
      }

      local neighbors = {}

      for _, neighbor_offset in ipairs(neighbor_offsets) do
        local panel = self:get_panel_at(dark_hole.x + neighbor_offset[1], dark_hole.y + neighbor_offset[2], dark_hole.z)

        if panel then
          neighbors[#neighbors+1] = panel
        end
      end

      if #neighbors == 0 then
        -- no available spaces
        goto continue
      end

      -- pick a neighbor to be the destination
      local destination = neighbors[math.random(#neighbors)]

      -- move the camera here
      for _, player in ipairs(self.players) do
        Net.slide_player_camera(player.id, dark_hole.x + .5, dark_hole.y + .5, dark_hole.z, slide_time)
      end

      -- wait until the camera is done moving
      Async.await(Async.sleep(slide_time))

      -- spawn a new enemy
      local name = dark_hole.custom_properties.Spawns
      local direction = dark_hole.custom_properties.Direction
      dark_hole.enemy = Enemy.from(self, dark_hole, direction, name)
      self.enemies[#self.enemies+1] = dark_hole.enemy

      -- Let people admire the enemy
      local admire_time = .5
      Async.await(Async.sleep(admire_time))

      -- move them out
      Async.await(EnemyHelpers.move(self, dark_hole.enemy, destination.x, destination.y, destination.z))

      -- Needs more admiration
      Async.await(Async.sleep(admire_time))

      ::continue::
    end

    -- completed turn, return camera to players
    for _, player in pairs(self.players) do
      Net.slide_player_camera(player.id, player.x, player.y, player.z, slide_time)
      Net.unlock_player_camera(player.id)
    end

    -- wait for the camera
    Async.await(Async.sleep(slide_time))

    -- give turn back to players
    for _, player_session in pairs(self.player_sessions) do
      player_session:give_turn()
    end

    self.emote_timer = 0
    self.phase = self.phase + 1

    if self.needs_disposal then
      for _, enemy in ipairs(self.enemies) do
        Net.remove_bot(enemy.id)
      end

      Net.remove_area(self.area_id)
    end
  end)

  Async.promisify(co)
end

-- public
local Mission = {}

function Mission:new(base_area_id, new_area_id, players)
  local FIRST_PANEL_GID = Net.get_tileset(base_area_id, "/server/assets/tiles/panels.tsx").first_gid
  local TOTAL_PANEL_GIDS = 7

  local mission = {
    area_id = new_area_id,
    emote_timer = 0,
    phase = 1,
    ready_count = 0,
    order_points = 3,
    MAX_ORDER_POINTS = 8,
    points_of_interest = {},
    players = players,
    player_sessions = {},
    boss = nil,
    enemies = {},
    panels = {},
    dark_holes = {},
    indestructible_panels = {},
    FIRST_PANEL_GID = FIRST_PANEL_GID,
    BASIC_PANEL_GID = FIRST_PANEL_GID,
    ITEM_PANEL_GID = FIRST_PANEL_GID + 1,
    DARK_HOLE_PANEL_GID = FIRST_PANEL_GID + 2,
    INDESTRUCTIBLE_PANEL_GID = FIRST_PANEL_GID + 3,
    BONUS_PANEL_GID = FIRST_PANEL_GID + 4,
    LAST_PANEL_GID = FIRST_PANEL_GID + TOTAL_PANEL_GIDS - 1,
    needs_disposal = false
  }

  for i = 1, Net.get_height(base_area_id), 1 do
    -- create row
    mission.panels[i] = {}
  end

  setmetatable(mission, self)
  self.__index = self

  Net.clone_area(base_area_id, new_area_id)
  Preloader.update(new_area_id)

  local object_ids = Net.list_objects(mission.area_id)

  for _, object_id in ipairs(object_ids) do
    local object = Net.get_object_by_id(mission.area_id, object_id)

    if object.name == "Point of Interest" then
      -- track points of interest for the camera
      mission.points_of_interest[#mission.points_of_interest + 1] = object
      -- delete to reduce map size
      Net.remove_object(mission.area_id, object_id)
    elseif is_panel(mission, object) then
      if object.data.gid == mission.ITEM_PANEL_GID then
        -- set the loot for the panel
        object.loot = Loot.DEFAULT_POOL[math.random(#Loot.DEFAULT_POOL)]
      elseif object.data.gid == mission.DARK_HOLE_PANEL_GID then
        -- track dark holes for converting indestructible panels
        mission.dark_holes[#mission.dark_holes+1] = object
      elseif object.data.gid == mission.INDESTRUCTIBLE_PANEL_GID then
        -- track indestructible panels for conversion
        mission.indestructible_panels[#mission.indestructible_panels+1] = object
      end

      -- insert the panel before spawning enemies
      local x = math.floor(object.x) + 1
      local y = math.floor(object.y) + 1
      mission.panels[y][x] = object

      -- spawning bosses
      if object.custom_properties.Boss then
        local name = object.custom_properties.Boss
        local direction = object.custom_properties.Direction
        local enemy = Enemy.from(mission, object, direction, name)
        enemy.is_boss = true

        mission.boss = enemy
        table.insert(mission.enemies, 1, enemy) -- make the boss the first enemy in the list
      end

      -- spawning enemies
      if object.custom_properties.Spawns then
        local name = object.custom_properties.Spawns
        local direction = object.custom_properties.Direction
        local position = {
          x = object.x,
          y = object.y,
          z = object.z
        }

        position = EnemyHelpers.offset_position_with_direction(position, direction)

        local enemy = Enemy.from(mission, position, direction, name)
        object.enemy = enemy

        mission.enemies[#mission.enemies + 1] = enemy -- make the boss the first enemy in the list
      end
    end
  end

  return mission
end

function Mission:clean_up()
  -- mark as needs_disposal to clean up after async functions complete
  self.needs_disposal = true
end

function Mission:begin()
  local spawn = Net.get_spawn_position(self.area_id)
  local hold_time = .7
  local slide_time = .7
  local total_camera_time = 0

  for _, player in ipairs(self.players) do
    -- create data
    self.player_sessions[player.id] = PlayerSession:new(self, player)

    if not debug then
      Net.lock_player_input(player.id)

      -- reset - we want the total camera time taken by all players in parallel, not in sequence
      total_camera_time = 0

      -- control camera
      Net.move_player_camera(player.id, spawn.x, spawn.y, spawn.z, hold_time)
      total_camera_time = total_camera_time + hold_time

      for j, point in ipairs(self.points_of_interest) do
        Net.slide_player_camera(player.id, point.x, point.y, point.z, slide_time)
        Net.move_player_camera(player.id, point.x, point.y, point.z, hold_time)

        total_camera_time = total_camera_time + slide_time + hold_time
      end

      Net.slide_player_camera(player.id, spawn.x, spawn.y, spawn.z, slide_time)
      Net.unlock_player_camera(player.id)

      total_camera_time = total_camera_time + slide_time
    end
  end

  if not debug then
    -- release players after camera animation
    Async.sleep(total_camera_time).and_then(function()
      for _, player in ipairs(self.players) do
        Net.unlock_player_input(player.id)
      end
    end)
  end
end

function Mission:tick(elapsed)
  if self.ready_count == #self.players then
    self.ready_count = 0
    -- now we can take a turn !
    take_enemy_turn(self)
  end

  self.emote_timer = self.emote_timer - elapsed

  if self.emote_timer <= 0 then
    for _, player_session in pairs(self.player_sessions) do
      player_session:emote_state()
    end

    -- emote every second
    self.emote_timer = 1
  end
end

function Mission:handle_tile_interaction(player_id, x, y, z, button)
  local player_session = self.player_sessions[player_id]

  if button == 1 then
    -- Shoulder L
    return
  end

  if player_session.completed_turn or Net.is_player_in_widget(player_id) then
    -- ignore selection as it's not our turn or waiting for a response
    return
  end

  Net.lock_player_input(player_id)

  local quiz_promise = player_session:quiz_with_points("Pass", "Cancel")

  quiz_promise.and_then(function(response)
    if response == 0 then
      -- Pass
      player_session:get_pass_turn_permission()
    else
      -- Cancel
      Net.unlock_player_input(player_id)
    end
  end)
end

function Mission:handle_object_interaction(player_id, object_id, button)
  local player_session = self.player_sessions[player_id]

  if button == 1 then
    -- Shoulder L
    return
  end

  if player_session.completed_turn or Net.is_player_in_widget(player_id) then
    -- ignore selection as it's not our turn or waiting for a response
    return
  end

  -- panel selection detection

  local object = Net.get_object_by_id(self.area_id, object_id)

  if not object then
    -- must have been liberated
    return
  end

  if not is_adjacent(player_session.player, object) then
    -- can't select panels diagonally
    return
  end

  local panel = self:get_panel_at(object.x, object.y)

  if not panel then
    -- no data associated with this object
    return
  end

  Net.lock_player_input(player_id)

  local panel_already_selected = false

  for _, player_session in pairs(self.player_sessions) do
    if player_session.selection.root_panel == panel then
      panel_already_selected = true
      break
    end
  end

  local can_liberate = not panel_already_selected and (
    panel.data.gid == self.BASIC_PANEL_GID or
    panel.data.gid == self.ITEM_PANEL_GID or
    panel.data.gid == self.DARK_HOLE_PANEL_GID or
    panel.data.gid == self.BONUS_PANEL_GID
  )

  if not can_liberate then
    -- indestructible panels
    local quiz_promise = player_session:quiz_with_points("Pass", "Cancel")

    quiz_promise.and_then(function(response)
      if response == 0 then
        -- Pass
        player_session:get_pass_turn_permission()
      else
        -- Cancel
        Net.unlock_player_input(player_id)
      end
    end)

    return
  end

  local ability = player_session.ability

  local has_enemy = false

  for _, enemy in ipairs(self.enemies) do
    if (
      math.min(panel.x) == enemy.x and
      math.min(panel.y) == enemy.y and
      enemy.z == panel.z
   ) then
      has_enemy = true
      break
    end
  end

  local can_use_ability = (
    ability.question and -- no question = passive ability
    not has_enemy and -- cant have an enemy standing on this tile
    self.order_points >= ability.cost and
    (
      panel.data.gid == self.BASIC_PANEL_GID or
      panel.data.gid == self.ITEM_PANEL_GID
    )
  )

  if not can_use_ability then
    player_session.selection:select_panel(panel)

    local quiz_promise = player_session:quiz_with_points(
      "Liberation",
      "Pass",
      "Cancel"
    )

    quiz_promise.and_then(function(response)
      if response == 0 then
        -- Liberation
        liberate_panel(self, player_session)
      elseif response == 1 then
        -- Pass
        player_session.selection:clear()
        player_session:get_pass_turn_permission()
      else
        -- Cancel
        player_session.selection:clear()
        Net.unlock_player_input(player_id)
      end
    end)

    return
  end


  player_session.selection:select_panel(panel)

  local quiz_promise = player_session:quiz_with_points(
    "Liberation",
    ability.name,
    "Pass"
  )

  quiz_promise.and_then(function(response)
    if response == 0 then
      -- Liberate
      liberate_panel(self, player_session)
    elseif response == 1 then
      -- Ability
      local selection_shape, shape_offset_x, shape_offset_y = ability.generate_shape(self, player_session)
      player_session.selection:set_shape(selection_shape, shape_offset_x, shape_offset_y)

      -- ask if we should use the ability
      player_session:get_ability_permission()
    elseif response == 2 then
      -- Pass
      player_session.selection:clear()
      player_session:get_pass_turn_permission()
    end
  end)
end

function Mission:handle_player_avatar_change(player_id)
  local player = self.player_sessions[player_id].player

  player:boot_to_lobby()
end

function Mission:handle_player_transfer(player_id)
end

function Mission:handle_player_disconnect(player_id)
  for i, player in ipairs(self.players) do
    if player_id == player.id then
      table.remove(self.players, i)
      break
    end
  end

  self.player_sessions[player_id]:handle_disconnect()
  self.player_sessions[player_id] = nil
end

function Mission:get_players()
  return self.players
end

function Mission:get_spawn_position()
  return Net.get_spawn_position(self.area_id)
end

-- helper functions
function Mission:get_panel_at(x, y)
  y = math.floor(y) + 1
  local row = self.panels[y]

  if row == nil then
    return nil
  end

  x = math.floor(x) + 1
  return row[x]
end

function Mission:remove_panel(panel)
  local y = math.floor(panel.y) + 1
  local row = self.panels[y]

  if row == nil then
    return nil
  end

  local x = math.floor(panel.x) + 1

  if row[x] == nil then
    return
  end

  Net.remove_object(self.area_id, panel.id)
  row[x] = nil

  if panel.data.gid == self.DARK_HOLE_PANEL_GID then
    for i, dark_hole in ipairs(self.dark_holes) do
      if panel == dark_hole then
        table.remove(self.dark_holes, i)
        break
      end
    end
  end
end

function Mission:get_enemy_at(x, y, z)
  x = math.floor(x)
  y = math.floor(y)

  for _, enemy in ipairs(self.enemies) do
    if enemy.x == x and enemy.y == y and enemy.z == z then
      return enemy
    end
  end

  return nil
end


-- exporting
return Mission

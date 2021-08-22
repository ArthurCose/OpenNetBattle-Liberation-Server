local PlayerSession = require("scripts/main/liberations/player_session")
local Loot = require("scripts/main/liberations/loot")

local debug = false

local Mission = {}

function Mission:new(base_area_id, new_area_id, players)
  local FIRST_PANEL_GID = Net.get_tileset(base_area_id, "/server/assets/tiles/panels.tsx").first_gid
  local TOTAL_PANEL_GIDS = 7

  local mission = {
    area_id = new_area_id,
    boss = nil,
    enemies = {},
    points_of_interest = {},
    player_list = players,
    ready_count = 0,
    player_sessions = {},
    order_points = 3,
    MAX_ORDER_POINTS = 8,
    panels = {},
    dark_hole_count = 0,
    indestructible_panels = {},
    FIRST_PANEL_GID = FIRST_PANEL_GID,
    BASIC_PANEL_GID = FIRST_PANEL_GID,
    ITEM_PANEL_GID = FIRST_PANEL_GID + 1,
    DARK_HOLE_PANEL_GID = FIRST_PANEL_GID + 2,
    INDESTRUCTIBLE_PANEL_GID = FIRST_PANEL_GID + 3,
    BONUS_PANEL_GID = FIRST_PANEL_GID + 4,
    LAST_PANEL_GID = FIRST_PANEL_GID + TOTAL_PANEL_GIDS - 1
  }

  for i = 1, Net.get_height(base_area_id), 1 do
    -- create row
    mission.panels[i] = {}
  end

  setmetatable(mission, self)
  self.__index = self

  Net.clone_area(base_area_id, new_area_id)

  local object_ids = Net.list_objects(mission.area_id)

  for _, object_id in ipairs(object_ids) do
    local object = Net.get_object_by_id(mission.area_id, object_id)

    if object.name == "Boss" then
      mission.boss = object
      table.insert(mission.enemies, 1, object) -- make the boss the first enemy in the list
    elseif object.name == "Enemy" then
      mission.enemies[#mission.enemies + 1] = object
      -- delete to reduce map size
      Net.remove_object(mission.area_id, object_id)
    elseif object.name == "Point of Interest" then
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
        mission.dark_hole_count = mission.dark_hole_count + 1
      elseif object.data.gid == mission.INDESTRUCTIBLE_PANEL_GID then
        -- track indestructible panels for conversion
        mission.indestructible_panels[#mission.indestructible_panels+1] = object
      end

      local x = math.floor(object.x) + 1
      local y = math.floor(object.y) + 1
      mission.panels[y][x] = object
    end
  end

  return mission
end

function Mission:begin()
  local spawn = Net.get_spawn_position(self.area_id)
  local hold_time = .7
  local slide_time = .7
  local total_camera_time = 0

  for _, player in ipairs(self.player_list) do
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
      for _, player in ipairs(self.player_list) do
        Net.unlock_player_input(player.id)
      end
    end)
  end
end

function Mission:tick(elapsed)
  if self.ready_count == #self.player_list then
    self.ready_count = 0
    take_enemy_turn(self)
    -- now we can take a turn !
  end
end

function Mission:handle_tile_interaction(player_id, x, y, z, button)
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

  local panel = self:get_panel_at(object.x, object.y)

  if not panel then
    -- no data associated with this object
    return
  end

  Net.lock_player_input(player_id)

  local can_liberate = (
    panel.data.gid == self.BASIC_PANEL_GID or
    panel.data.gid == self.ITEM_PANEL_GID or
    panel.data.gid == self.DARK_HOLE_PANEL_GID or
    panel.data.gid == self.BONUS_PANEL_GID
  )

  if not can_liberate then
    -- indestructible panels
    local quiz_promise = player_session.player:quiz("Pass", "Cancel")

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

  local can_use_ability = (
    ability.question and -- no question = passive ability
    self.order_points > ability.cost and
    (
      panel.data.gid == self.BASIC_PANEL_GID or
      panel.data.gid == self.ITEM_PANEL_GID
    )
  )

  if not can_use_ability then
    player_session.panel_selection:select_panel(panel)

    local quiz_promise = player_session.player:quiz(
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
        player_session.panel_selection:clear()
        player_session:get_pass_turn_permission()
      else
        -- Cancel
        player_session.panel_selection:clear()
        Net.unlock_player_input(player_id)
      end
    end)

    return
  end


  player_session.panel_selection:select_panel(panel)

  local quiz_promise = player_session.player:quiz(
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
      local selection_shape = ability.generate_shape(self, player_session)
      player_session.panel_selection:set_shape(selection_shape)

      -- ask if we should use the ability
      player_session:get_ability_permission()
    elseif response == 2 then
      -- Pass
      player_session.panel_selection:clear()
      player_session:get_pass_turn_permission()
    end
  end)
end

function Mission:handle_player_transfer(player_id)
end

function Mission:handle_player_disconnect(player_id)
  for i, player in ipairs(self.player_list) do
    if player_id == player.id then
      table.remove(self.player_list, i)
      break
    end
  end

  self.player_sessions[player_id]:handle_disconnect()
  self.player_sessions[player_id] = nil
end

function Mission:list_players()
  return self.player_list
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

  if row[x] ~= nil then
    Net.remove_object(self.area_id, panel.id)
    row[x] = nil
  end
end


-- private functions

function is_panel(self, object)
  return object.data.type == "tile" and object.data.gid >= self.FIRST_PANEL_GID and object.data.gid <= self.LAST_PANEL_GID
end

local DARK_HOLE_SHAPE = {
  {1, 1, 1},
  {1, 1, 1},
  {1, 1, 1},
}

-- todo: pass terrain? https://megaman.fandom.com/wiki/Liberation_Mission#:~:text=corresponding%20Barrier%20Panel.-,Terrain,-Depending%20on%20the
function liberate_panel(self, player_session)
  local panel_selection = player_session.panel_selection
  local panel = panel_selection.root_panel

  local co = coroutine.create(function()
    if panel.data.gid == self.BONUS_PANEL_GID then
      Async.await(player_session.player:message_with_mug("A BonusPanel!"))

      self:remove_panel(panel)
      panel_selection:clear()

      Async.await(Loot.loot_bonus_panel(self, player_session, panel))

      Net.unlock_player_input(player_session.player.id)
    elseif panel.data.gid == self.DARK_HOLE_PANEL_GID then
      Async.await(player_session.player:message_with_mug("Let's do it! Liberate panels!"))

      -- todo: battle

      panel_selection:set_shape(DARK_HOLE_SHAPE, 0, -1)
      local panels = panel_selection:get_panels()

      Async.await(player_session:liberate_panels(panels))

      -- todo: delete spawned monster

      self.dark_hole_count = self.dark_hole_count - 1

      if self.dark_hole_count == 0 then
        convert_indestructible_panels(self)
      end

      -- looting occurs last
      Async.await(player_session:loot_panels(panels))

      player_session:complete_turn()
    else
      Async.await(player_session.player:message_with_mug("Let's do it! Liberate panels!"))

      -- todo: battle

      local panels = player_session.panel_selection:get_panels()
      Async.await(player_session:liberate_and_loot_panels(panels))
      player_session:complete_turn()
    end
  end)

  Async.promisify(co)
end

-- expects execution in a coroutine
function convert_indestructible_panels(self)
  local slide_time = .5
  local hold_time = 2

  -- notify players
  for _, player_session in pairs(self.player_sessions) do
    player_session.player:message("No more DarkHoles! Nothing will save the Darkloids now!")

    local player_id = player_session.player.id

    Net.lock_player_input(player_id)

    Net.slide_player_camera(player_id, self.boss.x, self.boss.y, self.boss.z, slide_time)

    -- hold the camera
    Net.move_player_camera(player_id, self.boss.x, self.boss.y, self.boss.z, hold_time)

    -- return the camera
    local player_pos = Net.get_player_position(player_id)
    Net.slide_player_camera(player_id, player_pos.x, player_pos.y, player_pos.z, slide_time)
    Net.unlock_player_camera(player_id)
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

function take_enemy_turn(self)
  local hold_time = .15
  local slide_time = .5

  local co = coroutine.create(function()
    for _, enemy in ipairs(self.enemies) do
      for _, player in ipairs(self.player_list) do
        Net.slide_player_camera(player.id, enemy.x, enemy.y, enemy.z, slide_time)
      end

      -- wait until the camera is done moving
      Async.await(Async.sleep(slide_time))

      -- todo: attack

      -- wait a short amount of time to look nicer if there was no action taken
      Async.await(Async.sleep(hold_time))
    end

    -- completed turn, return camera to players
    for i, player in pairs(self.player_list) do
      local player_pos = Net.get_player_position(player.id)
      Net.slide_player_camera(player.id, player_pos.x, player_pos.y, player_pos.z, slide_time)
      Net.unlock_player_camera(player.id)
    end

    -- wait for the camera
    Async.await(Async.sleep(slide_time))

    -- give turn back to players
    for i, player_session in pairs(self.player_sessions) do
      player_session:give_turn()
    end
  end)

  Async.promisify(co)
end

-- exporting
return Mission

local PlayerSession = require("scripts/liberations/player_session")

local debug = true

local Mission = {}

function Mission:new(base_area_id, new_area_id, player_ids)
  local FIRST_PANEL_GID = Net.get_tileset(base_area_id, "/server/assets/tiles/panels.tsx").first_gid
  local TOTAL_PANEL_GIDS = 7

  local mission = {
    area_id = new_area_id,
    boss = nil,
    enemies = {},
    points_of_interest = {},
    player_list = player_ids,
    ready_count = 0,
    player_sessions = {},
    order_points = 3,
    MAX_ORDER_POINTS = 8,
    panels = {},
    FIRST_PANEL_GID = FIRST_PANEL_GID,
    BASIC_PANEL_GID = FIRST_PANEL_GID,
    ITEM_PANEL_GID = FIRST_PANEL_GID + 1,
    DARK_HOLE_PANEL_GID = FIRST_PANEL_GID + 2,
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

  for i, object_id in ipairs(object_ids) do
    local object = Net.get_object_by_id(mission.area_id, object_id)

    if object.name == "Boss" then
      mission.boss = object
      table.insert(mission.enemies, 1, object) -- make the boss the first enemy in the list
    elseif object.name == "Enemy" then
      mission.enemies[#mission.enemies + 1] = object
    elseif object.name == "Point of Interest" then
      mission.points_of_interest[#mission.points_of_interest + 1] = object
    elseif is_panel(mission, object) then
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

  for i, player_id in ipairs(self.player_list) do
    -- create data
    self.player_sessions[player_id] = PlayerSession:new(self, player_id)

    if not debug then
      Net.lock_player_input(player_id)

      -- reset - we want the total camera time taken by all players in parallel, not in sequence
      total_camera_time = 0

      -- control camera
      Net.move_player_camera(player_id, spawn.x, spawn.y, spawn.z, hold_time)
      total_camera_time = total_camera_time + hold_time

      for j, point in ipairs(self.points_of_interest) do
        Net.slide_player_camera(player_id, point.x, point.y, point.z, slide_time)
        Net.move_player_camera(player_id, point.x, point.y, point.z, hold_time)

        total_camera_time = total_camera_time + slide_time + hold_time
      end

      Net.slide_player_camera(player_id, spawn.x, spawn.y, spawn.z, slide_time)
      Net.unlock_player_camera(player_id)

      total_camera_time = total_camera_time + slide_time
    end
  end

  if not debug then
    -- release players after camera animation
    Async.sleep(total_camera_time).and_then(function()
      for i, player_id in ipairs(self.player_list) do
        Net.unlock_player_input(player_id)
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

function Mission:handle_tile_interaction(player_id, x, y, z)
  if self.player_sessions[player_id].completed_turn then return end
end

function Mission:handle_object_interaction(player_id, object_id)
  local player_session = self.player_sessions[player_id]

  if player_session.completed_turn or player_session.on_response then
    -- ignore selection as it's not our turn or waiting for a response
    return
  end

  -- panel selection detection

  local object = Net.get_object_by_id(self.area_id, object_id)

  if not is_panel(self, object) then
    -- out of range
    return
  end

  local can_liberate = (
    object.data.gid == self.BASIC_PANEL_GID or
    object.data.gid == self.ITEM_PANEL_GID or
    object.data.gid == self.DARK_HOLE_PANEL_GID or
    object.data.gid == self.BONUS_PANEL_GID
  )

  if not can_liberate then
    -- indestructible panels
    Net.quiz_player(
      player_id,
      "Pass",
      "Cancel"
    )

    player_session.on_response = function(response)
      if response == 0 then
        -- Pass
        player_session:complete_turn()
      end
    end

    return
  end

  local ability = player_session.ability

  local can_use_ability = (
    ability.question and -- no question = passive ability
    self.order_points > ability.cost and
    (
      object.data.gid == self.BASIC_PANEL_GID or
      object.data.gid == self.ITEM_PANEL_GID
    )
  )

  if not can_use_ability then
    player_session.panel_selection:select_panel(object)

    Net.quiz_player(
      player_id,
      "Liberation",
      "Pass",
      "Cancel"
    )

    player_session.on_response = function(response)
      if response == 0 then
        -- Liberation
        liberate_panel(self, player_id)
      elseif response == 1 then
        -- Pass
        player_session:complete_turn()
      else
        -- Cancel
        player_session.panel_selection:clear()
      end
    end

    return
  end


  if object.data.gid == self.BASIC_PANEL_GID or object.data.gid == self.ITEM_PANEL_GID then
    player_session.panel_selection:select_panel(object)

    Net.quiz_player(
      player_id,
      "Liberation",
      ability.name,
      "Pass"
    )

    player_session.on_response = function(response)
      if response == 0 then
        -- Liberate
        liberate_panel(self, player_id)
      elseif response == 1 then
        -- Ability
        player_session.panel_selection:set_shape(ability.shape)

        -- ask if we should use the ability
        local mug = Net.get_player_mugshot(player_id)
        Net.question_player(
          player_id,
          ability.question,
          mug.texture_path,
          mug.animation_path
        )

        -- callback hell
        player_session.on_response = function(response)
          player_session.on_response = nil

          if response == 0 then
            -- No
            player_session.panel_selection:clear()
            return
          end

          -- Yes
          ability.activate(self, player_session)
        end
      elseif response == 2 then
        -- Pass
        player_session:complete_turn()
      end
    end

    return
  end

end

function Mission:handle_player_response(player_id, response)
  local player_session = self.player_sessions[player_id]

  local on_response = player_session.on_response
  player_session.on_response = nil

  if on_response ~= nil then
    on_response(response)
  end
end

function Mission:handle_player_transfer(player_id)
end

function Mission:handle_player_disconnect(player_id, response)
  for i, stored_player_id in ipairs(self.player_list) do
    if player_id == stored_player_id then
      table.remove(self.player_list, i)
      break
    end
  end

  self.player_sessions[player_id]:handle_disconnect()
  self.player_sessions[player_id] = nil
end

function Mission:has_player(player_id)
  for i, stored_player_id in ipairs(self.player_list) do
    if player_id == stored_player_id then
      return true
    end
  end

  return false
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

-- private functions
function is_panel(instance, object)
  return object.data.type == "tile" and object.data.gid >= instance.FIRST_PANEL_GID and object.data.gid <= instance.LAST_PANEL_GID
end

-- todo: pass terrain? https://megaman.fandom.com/wiki/Liberation_Mission#:~:text=corresponding%20Barrier%20Panel.-,Terrain,-Depending%20on%20the
function liberate_panel(instance, player_id)
  local player_session = instance.player_sessions[player_id]

  if instance.BONUS_PANEL_GID then
    -- todo: give item
  else
    -- todo: battle
    player_session:complete_turn()
  end

  player_session.panel_selection:liberate()
end

function take_enemy_turn(instance)
  local hold_time = .1
  local slide_time = .7

  local co = coroutine.create(function()
    for i, enemy in ipairs(instance.enemies) do
      for j, player_id in ipairs(instance.player_list) do
        Net.slide_player_camera(player_id, enemy.x, enemy.y, enemy.z, slide_time)
      end

      -- wait until the camera is done moving
      Async.await(Async.sleep(slide_time))

      -- todo: attack

      -- wait a short amount of time to look nicer if there was no action taken
      Async.await(Async.sleep(hold_time))
    end

    -- completed turn, return camera to players
    for i, player_session in pairs(instance.player_sessions) do
      local player_pos = Net.get_player_position(player_session.player_id)
      Net.slide_player_camera(player_session.player_id, player_pos.x, player_pos.y, player_pos.z, slide_time)
      Net.unlock_player_camera(player_session.player_id)
      player_session:give_turn()
    end

    -- wait for the camera
    Async.await(Async.sleep(slide_time))

    -- give turn back to players
    for i, player_session in pairs(instance.player_sessions) do
      player_session:give_turn()
    end
  end)

  Async.promisify(co)
end

-- exporting
return Mission

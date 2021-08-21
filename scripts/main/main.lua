-- random may be called in required scripts, need to set the seed
math.randomseed(os.time())

local Player = require("scripts/main/player")
local Instance = require("scripts/main/liberations/instance")
local Parties = require("scripts/libs/parties")

local waiting_area = "default"
local instances = {}
local door = Net.get_object_by_name(waiting_area, "Door")
local players = {}

function tick(elapsed)
  Parties.tick(elapsed)

  local dead_instances = {}

  for area_id, instance in pairs(instances) do
    instance:tick(elapsed)

    if #instance:list_players() == 0 then
      dead_instances[#dead_instances + 1] = area_id
    end
  end

  for i, area_id in ipairs(dead_instances) do
    remove_instance(area_id)
  end
end

function handle_tile_interaction(player_id, x, y, z, button)
  local area_id = Net.get_player_area(player_id)

  if area_id == waiting_area and button == 0 then
    local player = players[player_id]

    player:quiz("Leave party", "Close").and_then(function(response)
      if response == 0 then
        Parties.leave(player_id)
      end
    end)
  elseif instances[area_id] ~= nil then
    instances[area_id]:handle_tile_interaction(player_id, x, y, z, button)
  end
end

function handle_object_interaction(player_id, object_id, button)
  local area_id = Net.get_player_area(player_id)

  if area_id == waiting_area then
    detect_door_interaction(player_id, object_id, button)
  elseif instances[area_id] ~= nil then
    instances[area_id]:handle_object_interaction(player_id, object_id, button)
  end
end

function handle_actor_interaction(player_id, other_player_id, button)
  local area_id = Net.get_player_area(player_id)

  if area_id ~= waiting_area or button ~= 0 then return end

  if Net.is_bot(other_player_id) then return end

  if Parties.is_in_same_party(player_id, other_player_id) then
    return
  end

  local name = Net.get_player_name(other_player_id)
  local player = players[player_id]

  -- checking for an invite
  local party_request = Parties.find_request(other_player_id, player_id)

  if party_request ~= nil then
    -- other player has a request for us
    player:question_with_mug("Join " .. name .. "'s party?").and_then(function(response)
      if response == 1 then
        Parties.accept(party_request)
      end
    end)

    return
  end

  -- try making a party request
  party_request = Parties.find_request(player_id, other_player_id)

  if party_request ~= nil then
    -- we already made a request, just ignore
    return
  end

  player:question_with_mug("Recruit " .. name .. "?").and_then(function(response)
    if response == 1 then
      -- create a request
      Parties.request(player_id, other_player_id)
    end
  end)
end

function detect_door_interaction(player_id, object_id, button)
  if button ~= 0 then return end
  if object_id ~= door.id then return end

  local player = players[player_id]

  player:question_with_mug("Start mission?").and_then(function(response)
    if response == 1 then
      start_game_for_player("acdc3", player_id)
    end
  end)
end

function handle_textbox_response(player_id, response)
  local player = players[player_id]

  player:handle_textbox_response(response)
end

function start_game_for_player(map, player_id)
  local party_info = Parties.find(player_id)

  if party_info == nil then
    transfer_players_to_new_instance(map, { player_id })
  else
    local party = Parties.get(party_info.party_index)

    if party.playing == false then
      party.playing = true
      transfer_players_to_new_instance(map, party.members)
    end
  end
end

function transfer_players_to_new_instance(base_area, player_ids)
  local instance_id = player_ids[1]
  local instance_players = {}

  for _, player_id in ipairs(player_ids) do
    instance_players[#instance_players+1] = players[player_id]
  end

  local instance = Instance:new(base_area, instance_id, instance_players)
  local spawn = instance:get_spawn_position()

  for _, player in ipairs(instance_players) do
    Net.transfer_player(player.id, instance_id, true, spawn.x, spawn.y, spawn.z)
    player.activity = instance
  end

  instance:begin()

  instances[instance_id] = instance
end

function handle_player_transfer(player_id)
  local player = players[player_id]

  if player.activity then
    player.activity:handle_player_transfer(player_id)
  end
end

function handle_player_join(player_id)
  players[player_id] = Player:new(player_id)
end

function handle_player_disconnect(player_id)
  local player = players[player_id]

  if player.activity then
    player.activity:handle_player_disconnect(player_id)
  end

  Parties.leave(player_id)
  players[player_id] = nil
end

function remove_instance(area_id)
  local instance = instances[area_id]

  for _, player in ipairs(instance:list_players()) do
    Net.transfer_player(player.id, waiting_area, true)

    -- could possibly do this once
    -- but race conditions (player left party/joined diff party but was still sent with group) may be possible lol
    local party_info = Parties.find(player.id)

    if party_info ~= nil then
      Parties.get(party_info.party_index).playing = false
    end

    player.activity = nil
  end

  Net.remove_area(instance.area_id)
  instances[area_id] = nil
end

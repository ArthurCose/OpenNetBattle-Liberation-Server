-- random may be called in required scripts, need to set the seed
math.randomseed(os.time())

local Instance = require("scripts/liberations/instance")
local Parties = require("scripts/libs/parties")

local waiting_area = "default"
local instances = {}
local door = Net.get_object_by_name(waiting_area, "Door")
local player_state_map = {} -- "door"

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

function handle_tile_interaction(player_id, x, y, z)
  local area_id = Net.get_player_area(player_id)

  if area_id == waiting_area then
    player_state_map[player_id] = "tile menu"
    Net.quiz_player(player_id, "Leave party", "Close")
  elseif instances[area_id] ~= nil then
    instances[area_id]:handle_tile_interaction(player_id, x, y, z)
  end
end

function handle_object_interaction(player_id, object_id)
  local area_id = Net.get_player_area(player_id)

  if area_id == waiting_area then
    detect_door_interaction(player_id, object_id)
  elseif instances[area_id] ~= nil then
    instances[area_id]:handle_object_interaction(player_id, object_id)
  end
end

function handle_actor_interaction(player_id, other_player_id)
  local area_id = Net.get_player_area(player_id)

  if area_id ~= waiting_area then return end

  if Net.is_bot(other_player_id) then return end

  if Parties.is_in_same_party(player_id, other_player_id) then
    return
  end

  local name = Net.get_player_name(other_player_id)

  local request_index = Parties.find_request(other_player_id, player_id)

  if request_index ~= nil then
    -- other player has a request for us
    player_state_map[player_id] = "accepting recruit " .. other_player_id

    local mugshot = Net.get_player_mugshot(player_id)
    Net.question_player(player_id, "Join " .. name .. "'s party?", mugshot.texture_path, mugshot.animation_path)
    return
  end

  local request_index = Parties.find_request(player_id, other_player_id)

  if request_index ~= nil then
    -- we already made a request, just ignore
    return
  end

  local mugshot = Net.get_player_mugshot(player_id)
  player_state_map[player_id] = "recruiting " .. other_player_id
  Net.question_player(player_id, "Recruit " .. name .. "?", mugshot.texture_path, mugshot.animation_path)
end

function detect_door_interaction(player_id, object_id)
  if object_id ~= door.id then return end

  local mugshot = Net.get_player_mugshot(player_id)
  player_state_map[player_id] = "door"
  Net.question_player(player_id, "Start mission?", mugshot.texture_path, mugshot.animation_path)
end

function handle_textbox_response(player_id, response)
  local area_id = Net.get_player_area(player_id)

  if instances[area_id] ~= nil then
    instances[area_id]:handle_textbox_response(player_id, response)
    return
  end

  if area_id ~= waiting_area then return end

  local state = player_state_map[player_id]

  if state == nil then
    return
  end

  if state == "tile menu" and response == 0 then
    Parties.leave(player_id)

    player_state_map[player_id] = nil
  elseif state == "door" and response == 1 then
    -- Responded yes to playing at the door
    start_game_for_player("acdc3", player_id)
    player_state_map[player_id] = nil
  elseif state:find("^recruiting ") ~= nil and response == 1 then
    local recruit_id = state:sub(("recruiting "):len() + 1)

    Parties.request(player_id, recruit_id)

    player_state_map[player_id] = nil
  elseif state:find("^accepting recruit ") ~= nil and response == 1 then
    local requester_id = state:sub(("accepting recruit "):len() + 1)

    local request = Parties.find_request(requester_id, player_id)
    Parties.accept(request)

    player_state_map[player_id] = nil
  else
    player_state_map[player_id] = nil
  end
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
  local instance = Instance:new(base_area, instance_id, player_ids)
  local spawn = instance:get_spawn_position()

  for i, player_id in ipairs(player_ids) do
    player_state_map[player_id] = nil
    Net.transfer_player(player_id, instance_id, true, spawn.x, spawn.y, spawn.z)
  end

  instance:begin()

  instances[instance_id] = instance
end

function handle_player_transfer(player_id)
  for _, instance in pairs(instances) do
    if instance:has_player(player_id) then
      instance:handle_player_transfer(player_id)
      break
    end
  end
end

function handle_player_disconnect(player_id)
  player_state_map[player_id] = nil
  Parties.leave(player_id)

  for _, instance in pairs(instances) do
    if instance:has_player(player_id) then
      instance:handle_player_disconnect(player_id)
      break
    end
  end
end

function remove_instance(area_id)
  local instance = instances[area_id]

  for i, player_id in ipairs(instance:list_players()) do
    Net.transfer_player(player_id, waiting_area, true)

    -- could possibly do this once
    -- but race conditions (player left party/joined diff party but was still sent with group) may be possible lol
    local party_info = Parties.find(player_id)

    if party_info ~= nil then
      Parties.get(party_info.party_index).playing = false
    end
  end

  Net.remove_area(instance.area_id)
  instances[area_id] = nil
end

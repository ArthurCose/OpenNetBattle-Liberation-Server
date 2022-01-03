local Direction = require("scripts/libs/direction")
local areas = Net.list_areas()

for i, area_id in ipairs(areas) do
  local spawn = Net.get_object_by_name(area_id, "Spawn")

  if spawn ~= nil then
    Net.set_spawn_position(area_id, spawn.x, spawn.y, spawn.z)

    local direction = spawn.custom_properties.Direction

    if direction then
      Net.set_spawn_direction(area_id, direction)
    end
  end
end

local spawn_data = {}

function handle_player_request(player_id, data)
  spawn_data[player_id] = data
end

function handle_player_connect(player_id)
  if spawn_data[player_id] == "iceberg" then
    local spawn = Net.get_object_by_name("default", "Iceberg Spawn")
    Net.teleport_player(player_id, true, spawn.x, spawn.y, spawn.z, Direction.DOWN_RIGHT)
  end
  spawn_data[player_id] = nil
end

function handle_player_disconnect(player_id)
  spawn_data[player_id] = nil
end

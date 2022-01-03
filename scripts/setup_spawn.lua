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

function handle_player_request(player_id, data)
  if data == "iceberg" then
    local spawn = Net.get_object_by_name("default", "Iceberg Spawn")
    Net.transfer_player(player_id, "default", true, spawn.x, spawn.y, spawn.z, Direction.DOWN_RIGHT)
  end
end

local areas = Net.list_areas()

for i, area_id in ipairs(areas) do
  local spawn = Net.get_object_by_name(area_id, "Spawn")

  if spawn ~= nil then
    Net.set_spawn_position(area_id, spawn.x, spawn.y, spawn.z)
  end
end

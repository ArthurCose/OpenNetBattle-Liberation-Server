local PanelEncounters = {
  ACDC = {
    even = {},
    advantage = {},
    disadvantage = {},
    surrounded = {}
  }
}

local corner_offsets = {
  { 1, -1 },
  { 1, 1 },
  { -1, -1 },
  { -1, 1 },
}

local function has_dark_panel(instance, x, y, z)
  local panel = instance:get_panel_at(x, y, z)

  return panel and panel.data.gid ~= instance.BONUS_PANEL_GID
end

function PanelEncounters.resolve_terrain(instance, player)
  local x_left = has_dark_panel(instance, player.x - 1, player.y, player.z)
  local x_right = has_dark_panel(instance, player.x + 1, player.y, player.z)
  local y_left = has_dark_panel(instance, player.x, player.y - 1, player.z)
  local y_right = has_dark_panel(instance, player.x, player.y + 1, player.z)

  if (x_left and x_right) or (y_left and y_right) then
    return "surrounded"
  end

  if (x_left or x_right) and (y_left or y_right) then
    return "disadvantage"
  end

  for _, offset in ipairs(corner_offsets) do
    if has_dark_panel(instance, player.x + offset[1], player.y + offset[2], player.z) then
      return "even"
    end
  end

  return "advantage"
end

return PanelEncounters

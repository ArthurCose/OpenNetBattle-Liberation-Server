local Selection = require("scripts/main/liberations/selection")
local Direction = require("scripts/libs/direction")

-- private functions

local function resolve_selection_direction(player_pos, panel_object)
  -- resolving selection direction, can't use the Direction helper lib for this
  -- as we only allow for diagonal directions
  local x_diff = panel_object.x + panel_object.height / 2 - player_pos.x
  local y_diff = panel_object.y + panel_object.height / 2 - player_pos.y

  if math.abs(x_diff) > math.abs(y_diff) then
    -- x axis direction
    if x_diff < 0 then
      return Direction.UP_LEFT
    else
      return Direction.DOWN_RIGHT
    end
  else
    -- y axis direction
    if y_diff < 0 then
      return Direction.UP_RIGHT
    else
      return Direction.DOWN_LEFT
    end
  end
end

-- public
local PanelSelection = {}

function PanelSelection:new(instance, player_id)
  local LIBERATING_PANEL_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/selected tile.tsx").first_gid

  local panel_selection = {
    player_id = player_id,
    instance = instance,
    root_panel = nil,
    selection = Selection:new(instance),
    LIBERATING_PANEL_GID = LIBERATING_PANEL_GID,
    SELECTED_PANEL_GID = LIBERATING_PANEL_GID + 1
  }

  setmetatable(panel_selection, self)
  self.__index = self

  local function filter(x, y, z)
    local panel = instance:get_panel_at(x, y, z)

    if panel == nil then
      return false
    end

    return (
      panel == panel_selection.root_panel or
      panel.data.gid == instance.BASIC_PANEL_GID or
      panel.data.gid == instance.ITEM_PANEL_GID
    )

    -- todo: detect if an enemy is standing on this panel
  end

  panel_selection.selection:set_filter(filter)
  panel_selection.selection:set_indicator({
    gid = panel_selection.SELECTED_PANEL_GID,
    width = 64,
    height = 32,
    offset_x = 1,
    offset_y = 1,
  })

  return panel_selection
end

function PanelSelection:select_panel(panel_object)
  self.root_panel = panel_object

  local player_pos = Net.get_player_position(self.player_id)
  local direction = resolve_selection_direction(player_pos, panel_object)
  self.selection:move(player_pos, direction)
  self.selection:set_shape({{1}})

  self.selection:remove_indicators()
  self.selection:indicate()
end

-- shape = [m][n] bool array, n being odd, just below bottom center is player position
function PanelSelection:set_shape(shape, shape_offset_x, shape_offset_y)
  self.selection:set_shape(shape, shape_offset_x, shape_offset_y)
  self.selection:remove_indicators()
  self.selection:indicate()
end

function PanelSelection:get_panels()
  local panels = {}

  for _, object in pairs(self.selection.objects) do
    panels[#panels+1] = self.instance:get_panel_at(object.x, object.y)
  end

  return panels
end

function PanelSelection:clear()
  self.selection:remove_indicators()
end

function PanelSelection:count_panels()
  return #self.objects
end

-- todo: add an update function that is called when a player liberates a panel? may fix issues with overlapped panels

-- exports
return PanelSelection
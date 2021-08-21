local Direction = require("scripts/libs/direction")

local PanelSelection = {}

local SELECTION_OFFSET = 1 / 32

function PanelSelection:new(instance, player_id)
  local LIBERATING_PANEL_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/selected tile.tsx").first_gid

  local panel_selection = {
    player_id = player_id,
    instance = instance,
    root_panel = nil,
    selection_direction = nil,
    objects = {},
    shape = {{}},
    LIBERATING_PANEL_GID = LIBERATING_PANEL_GID,
    SELECTED_PANEL_GID = LIBERATING_PANEL_GID + 1
  }

  setmetatable(panel_selection, self)
  self.__index = self

  return panel_selection
end

function PanelSelection:select_panel(panel_object)
  self:clear()

  self.root_panel = panel_object
  self.shape = {{1}}

  local player_pos = Net.get_player_position(self.player_id)
  self.selection_direction = resolve_selection_direction(player_pos, panel_object)

  -- create selection object
  local object = generate_selection_object(self)
  object.id = Net.create_object(self.instance.area_id, object)
  self.objects = { object }
end

-- shape = [m][n] bool array, n being odd, just below bottom center is player position
function PanelSelection:set_shape(shape, shape_offset_x, shape_offset_y)
  shape_offset_x = shape_offset_x or 0
  shape_offset_y = shape_offset_y or 0

  local root_panel = self.root_panel

  -- delete old objects
  self:clear()

  -- update shape
  self.root_panel = root_panel
  self.shape = shape

  -- generating objects
  for m, row in ipairs(shape) do
    local center_x = (#row - 1) / 2

    for n, is_selected in ipairs(row) do
      if is_selected == 0 or not is_selected then
        goto continue
      end

      -- facing up right by default
      local offset_x = n + shape_offset_x - center_x - 1
      local offset_y = -(m + shape_offset_y - 1)

      -- adjusting the offset to the direction
      if self.selection_direction == Direction.DOWN_LEFT then
        offset_x = -offset_x -- flipped
        offset_y = -offset_y -- flipped
      elseif self.selection_direction == Direction.UP_LEFT then
        local old_offset_y = offset_y
        offset_y = -offset_x -- 🤷
        offset_x = old_offset_y -- negative for going left
      elseif self.selection_direction == Direction.DOWN_RIGHT then
        local old_offset_y = offset_y
        offset_y = offset_x -- 🤷
        offset_x = -old_offset_y -- positive for going right
      end

      -- actually generating the object
      local object = generate_selection_object(self)
      object.x = object.x + offset_x
      object.y = object.y + offset_y

      local panel = self.instance:get_panel_at(object.x, object.y)
      if panel ~= root_panel and not can_shape_select(self.instance, panel) then
        goto continue
      end

      object.id = Net.create_object(self.instance.area_id, object)
      self.objects[#self.objects+1] = object

      ::continue::
    end
  end
end

function PanelSelection:get_panels()
  local panels = {}

  for _, object in pairs(self.objects) do
    panels[#panels+1] = self.instance:get_panel_at(object.x, object.y)
  end

  return panels
end

function PanelSelection:clear()
  -- delete objects
  for _, object in pairs(self.objects) do
    Net.remove_object(self.instance.area_id, object.id)
  end

  self.root_panel = nil
  self.objects = {}
  self.shape = {{}}
end

function PanelSelection:count_panels()
  return #self.objects
end

-- todo: add an update function that is called when a player liberates a panel? may fix issues with overlapped panels

-- private functions

function resolve_selection_direction(player_pos, panel_object)
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

function generate_selection_object(panel_selection)
  return {
    x = panel_selection.root_panel.x + SELECTION_OFFSET,
    y = panel_selection.root_panel.y + SELECTION_OFFSET,
    z = panel_selection.root_panel.z,
    width = 2,
    height = 1,
    data = {
      type = "tile",
      gid = panel_selection.SELECTED_PANEL_GID,
    }
  }
end

function can_shape_select(instance, panel)
  if panel == nil then
    return false
  end

  return (
    panel.data.gid == instance.BASIC_PANEL_GID or
    panel.data.gid == instance.ITEM_PANEL_GID
  )

 -- todo: detect if an enemy is standing on this panel
end

-- exports
return PanelSelection
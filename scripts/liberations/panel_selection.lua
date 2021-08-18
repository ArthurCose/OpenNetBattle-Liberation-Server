local Direction = require("scripts/libs/direction")

local PanelSelection = {}

local PANEL_OFFSET = 1 / 32

function PanelSelection:new(instance, player_id)
  local LIBERATING_PANEL_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/selected tile.tsx").first_gid

  local panel_selection = {
    player_id = player_id,
    instance = instance,
    objects = {},
    shape = {{}},
    LIBERATING_PANEL_GID = LIBERATING_PANEL_GID,
    SELECTED_PANEL_GID = LIBERATING_PANEL_GID + 1
  }

  setmetatable(panel_selection, self)
  self.__index = self

  return panel_selection
end

-- shape = [m][n] bool array, n being odd, bottom center is player position
function PanelSelection:set_selection(panel_object, shape)
  -- delete old objects
  self:clear()

  -- update shape
  self.shape = shape

  -- generating objects
  local player_pos = Net.get_player_position(self.player_id)
  local direction = resolve_selection_direction(player_pos, panel_object)

  for m, row in ipairs(shape) do
    local center = (#row - 1) / 2

    for n, is_selected in ipairs(row) do
      if not is_selected then
        goto continue
      end

      -- facing up right by default
      local offset_x = n - center - 1
      local offset_y = -(m - 1)

      -- adjusting the offset to the direction
      if direction == Direction.DOWN_LEFT then
        offset_x = -offset_x -- flipped
        offset_y = -offset_y -- flipped
      elseif direction == Direction.UP_LEFT then
        local old_offset_y = offset_y
        offset_y = -offset_x -- 🤷
        offset_x = old_offset_y -- negative for going left
      elseif direction == Direction.DOWN_RIGHT then
        local old_offset_y = offset_y
        offset_y = offset_x -- 🤷
        offset_x = -old_offset_y -- positive for going right
      end

      -- actually generating the object
      local object = {
        x = panel_object.x + offset_x + PANEL_OFFSET,
        y = panel_object.y + offset_y + PANEL_OFFSET,
        z = panel_object.z,
        width = 2,
        height = 1,
        visible = true,
        data = {
          type = "tile",
          gid = self.SELECTED_PANEL_GID,
        }
      }

      if self.instance:get_panel_at(object.x, object.y) == nil then
        goto continue
      end

      object.id = Net.create_object(self.instance.area_id, object)
      self.objects[#self.objects+1] = object

      ::continue::
    end
  end
end

function PanelSelection:clear()
  -- delete objects
  for _, object in pairs(self.objects) do
    Net.remove_object(self.instance.area_id, object.id)
  end

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

-- exports
return PanelSelection
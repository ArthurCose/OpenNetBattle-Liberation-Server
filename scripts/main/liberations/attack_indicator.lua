

local Direction = require("scripts/libs/direction")

local INDICATOR_OFFSET = 1 / 32

local AttackIndicator = {}

function AttackIndicator:new(instance, position, direction)
  local INDICATOR_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/attack indicator.tsx").first_gid
  local PANEL_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/panel base.tsx").first_gid

  local attack_indicator = {
    instance = instance,
    position = {
      x = math.floor(position.x),
      y = math.floor(position.y),
      z = math.floor(position.z),
    },
    selection_direction = direction,
    shape = {},
    shape_offset_x = 0,
    shape_offset_y = 0,
    objects = {},
    INDICATOR_GID = INDICATOR_GID,
    PANEL_GID = PANEL_GID,
    LAST_PANEL_GID = PANEL_GID + 2,
  }

  setmetatable(attack_indicator, self)
  self.__index = self

  return attack_indicator
end

-- shape = [m][n] bool array, n being odd, just below bottom center is enemy position
function AttackIndicator:set_shape(shape, shape_offset_x, shape_offset_y)
  self:clear()

  self.shape = shape
  self.shape_offset_x = shape_offset_x or 0
  self.shape_offset_y = shape_offset_y or 0

  -- generating objects
  for m, row in ipairs(self.shape) do
    local center_x = (#row - 1) / 2

    for n, is_selected in ipairs(row) do
      if is_selected == 0 or not is_selected then
        goto continue
      end

      -- facing up right by default
      local offset_x = n + self.shape_offset_x - center_x - 1
      local offset_y = -(m + self.shape_offset_y - 1)

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

      local tile = Net.get_tile(
        self.instance.area_id,
        self.position.x + offset_x,
        self.position.y + offset_y,
        self.position.z
      )

      if tile.gid < self.PANEL_GID or tile.gid > self.LAST_PANEL_GID then
        -- can't attack here
        goto continue
      end

      -- actually generating the object
      local object = generate_selection_object(self)
      object.x = object.x + offset_x
      object.y = object.y + offset_y

      object.id = Net.create_object(self.instance.area_id, object)
      self.objects[#self.objects+1] = object

      ::continue::
    end
  end
end

function AttackIndicator:clear()
  -- delete objects
  for _, object in pairs(self.objects) do
    Net.remove_object(self.instance.area_id, object.id)
  end

  self.objects = {}
  self.shape = {{}}
end

function generate_selection_object(self)
  return {
    x = self.position.x + INDICATOR_OFFSET,
    y = self.position.y + INDICATOR_OFFSET,
    z = self.position.z,
    width = 48 / 32,
    height = 24 / 32,
    data = {
      type = "tile",
      gid = self.INDICATOR_GID,
    }
  }
end

-- exports
return AttackIndicator

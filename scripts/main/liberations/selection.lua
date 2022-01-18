local Direction = require("scripts/libs/direction")

-- private functions

local function generate_selection_object(self)
  return {
    x = self.position.x + self.indicator.offset_x / 32,
    y = self.position.y + self.indicator.offset_y / 32,
    z = self.position.z,
    width = self.indicator.width / 32,
    height = self.indicator.height / 32,
    data = {
      type = "tile",
      gid = self.indicator.gid,
    }
  }
end

-- public
local Selection = {}

function Selection:new(instance)
  local attack_collider = {
    instance = instance,
    position = { x = 0, y = 0, z = 0 },
    shape = {},
    shape_offset_x = 0,
    shape_offset_y = 0,
    direction = nil,
    filter = nil,
    objects = {},
    indicator = nil
  }

  setmetatable(attack_collider, self)
  self.__index = self

  return attack_collider
end

function Selection:set_filter(filter)
  self.filter = filter
end

--[[
  indicator = {
    gid,
    width,
    height,
    offset_x,
    offset_y,
  }
]]
function Selection:set_indicator(indicator)
  self.indicator = indicator
end

-- shape = [m][n] bool array, n being odd, just below bottom center is actor position
function Selection:set_shape(shape, shape_offset_x, shape_offset_y)
  self.shape = shape
  self.shape_offset_x = shape_offset_x or 0
  self.shape_offset_y = shape_offset_y or 0
end

local function add_rows(shape, index, row_width, row_count)
  for y = 1, row_count do
    local new_row = { }

    for x = 1, row_width do
      new_row[x] = 0
    end

    table.insert(shape, index, new_row)
  end
end

local function widen_row(row, new_width)
  local old_width = #row
  local difference = new_width - old_width

  -- add cols
  for _ = 1, difference do
    row[#row+1] = 0
  end

  local left_padding = difference / 2

  -- copy to the right
  for i = old_width, 1, -1 do
    row[i + left_padding] = row[i]
  end

  -- clear
  for i = 1, left_padding do
    row[i] = 0
  end
end

function Selection:merge_shape(shape, shape_offset_x, shape_offset_y)
  if shape_offset_x ~= 0 then
    print("Selection:merge_shape() does not support shape_offset_x yet")
  end

  local shape_y_difference = shape_offset_y - self.shape_offset_y

  -- y positions for merging the new shape
  local start_y = shape_y_difference + 1
  -- new width must be able to fit both shapes
  local new_width = math.max(#shape[1], #self.shape[1])

  if shape_offset_y < self.shape_offset_y then
    -- new shape has a lower shape_offset_y, use as the new offset
    self.shape_offset_y = shape_offset_y

    -- we're placing our new shape at the bottom
    start_y = 1

    -- expand down
    add_rows(self.shape, 1, new_width, -shape_y_difference)
  end

  -- figure out if we need to expand up
  local new_length = start_y + #shape - 1
  local current_length = #self.shape

  if new_length > current_length then
    -- expand up
    local length_difference = new_length - current_length
    add_rows(self.shape, current_length + 1, new_width, length_difference)
  end

  -- time to actually merge the shapes
  -- x positions for merging the new shape
  local start_x = (new_width - #shape[1]) / 2 + 1
  local end_x = new_width - (start_x - 1)

  local end_y = start_y + #shape - 1

  for y, row in ipairs(self.shape) do
    if #row < new_width then
      widen_row(row, new_width)
    end

    if y >= start_y and y <= end_y then
      for x = start_x, end_x do
        row[x] = shape[y - start_y + 1][x - start_x + 1]
      end
    end
  end
end

-- really just for debugging
function Selection:to_string()
  local output = "{\n"

  for _, row in ipairs(self.shape) do
    output = output .. "  { " .. table.concat(row, ", ") .. " }\n"
  end

  output = output .. "}"

  return output
end

function Selection:move(position, direction)
  self.position.x = math.floor(position.x)
  self.position.y = math.floor(position.y)
  self.position.z = math.floor(position.z)
  self.direction = direction
end

function Selection:is_within(x, y, z)
  x = math.floor(x)
  y = math.floor(y)
  z = math.floor(z)

  if z ~= self.position.z then
    return false
  end

  local offset_x = self.position.x - x
  local offset_y = self.position.y - y

  -- transform the player position to fit into the shape
  -- default direction is UP RIGHT

  if self.direction == Direction.DOWN_LEFT then
    offset_x = -offset_x -- flipped
    offset_y = -offset_y -- flipped
  elseif self.direction == Direction.UP_LEFT then
    local old_offset_y = offset_y
    offset_y = -offset_x -- 🤷
    offset_x = old_offset_y -- negative for going left
  elseif self.direction == Direction.DOWN_RIGHT then
    local old_offset_y = offset_y
    offset_y = offset_x -- 🤷
    offset_x = -old_offset_y -- positive for going right
  end

  offset_x = offset_x - self.shape_offset_x
  offset_y = offset_y - self.shape_offset_y

  if offset_y < 1 or offset_y > #self.shape then
    return false
  end

  local row = self.shape[offset_y]
  local center_x = (#row - 1) / 2
  offset_x = offset_x + center_x + 1

  if offset_x < 1 or offset_x > #row then
    return false
  end

  local is_selected = row[offset_x]

  if is_selected == 0 or not is_selected then
    return false
  end

  return self.filter(x, y, z)
end

function Selection:indicate()
  -- generating objects
  for m, row in ipairs(self.shape) do
    local center_x = (#row - 1) / 2

    for n, is_selected in ipairs(row) do
      if is_selected == 0 or not is_selected then
        goto continue
      end

      -- facing up right by default
      local offset_x = n + self.shape_offset_x - center_x - 1
      local offset_y = -(m + self.shape_offset_y)

      -- adjusting the offset to the direction
      if self.direction == Direction.DOWN_LEFT then
        offset_x = -offset_x -- flipped
        offset_y = -offset_y -- flipped
      elseif self.direction == Direction.UP_LEFT then
        local old_offset_y = offset_y
        offset_y = -offset_x -- 🤷
        offset_x = old_offset_y -- negative for going left
      elseif self.direction == Direction.DOWN_RIGHT then
        local old_offset_y = offset_y
        offset_y = offset_x -- 🤷
        offset_x = -old_offset_y -- positive for going right
      end

      local x = self.position.x + offset_x
      local y = self.position.y + offset_y
      local z = self.position.z

      if not self.filter(x, y, z) then
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

function Selection:remove_indicators()
  -- delete objects
  for _, object in pairs(self.objects) do
    Net.remove_object(self.instance.area_id, object.id)
  end

  self.objects = {}
end

return Selection

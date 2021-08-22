local Selection = require("scripts/main/liberations/selection")
local Direction = require("scripts/libs/direction")

local EnemySelection = {}

function EnemySelection:new(instance)
  local enemy_selection = {
    instance = instance,
    selection = Selection:new(instance)
  }

  setmetatable(enemy_selection, self)
  self.__index = self

  local INDICATOR_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/attack indicator.tsx").first_gid
  local PANEL_GID = Net.get_tileset(instance.area_id, "/server/assets/tiles/panel base.tsx").first_gid
  local LAST_PANEL_GID = PANEL_GID + 2

  local function filter(x, y, z)
    local tile = Net.get_tile(instance.area_id, x, y, z)

    return tile.gid >= PANEL_GID or tile.gid <= LAST_PANEL_GID
  end

  enemy_selection.selection:set_filter(filter)
  enemy_selection.selection:set_indicator({
    gid = INDICATOR_GID,
    width = 48,
    height = 24,
    offset_x = 1,
    offset_y = 1,
  })

  return enemy_selection
end

-- shape = [m][n] bool array, n being odd, just below bottom center is enemy position
function EnemySelection:set_shape(shape, shape_offset_x, shape_offset_y)
  self.selection:set_shape(shape, shape_offset_x, shape_offset_y)
end

function EnemySelection:move(position, direction)
  self.selection:move(position, direction)
end

-- returns player sessions that collide
function EnemySelection:detect_player_sessions()
  local sessions = {}

  for _, player_session in pairs(self.instance.player_sessions) do
    -- if self.selection.direction == Direction.DOWN_LEFT then
    --   offset_x = -offset_x -- flipped
    --   offset_y = -offset_y -- flipped
    -- elseif self.selection.direction == Direction.UP_LEFT then
    --   local old_offset_y = offset_y
    --   offset_y = -offset_x -- 🤷
    --   offset_x = old_offset_y -- negative for going left
    -- elseif self.selection.direction == Direction.DOWN_RIGHT then
    --   local old_offset_y = offset_y
    --   offset_y = offset_x -- 🤷
    --   offset_x = -old_offset_y -- positive for going right
    -- end

    -- sessions[#sessions+1] = player_session
  end

  return sessions
end

function EnemySelection:indicate()
  self.selection:indicate()
end

function EnemySelection:remove_indicators()
  -- delete objects
  self.selection:remove_indicators()
end

-- exports
return EnemySelection

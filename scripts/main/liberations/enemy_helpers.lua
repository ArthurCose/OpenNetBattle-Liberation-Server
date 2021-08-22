local Direction = require("scripts/libs/direction")

local EnemyHelpers = {}

local direction_suffix_map = {
  [Direction.DOWN_LEFT] = "DL",
  [Direction.DOWN_RIGHT] = "DR",
  [Direction.UP_LEFT] = "UL",
  [Direction.UP_RIGHT] = "UR",
}

function EnemyHelpers.play_attack_animation(enemy)
  local direction = Net.get_bot_direction(enemy.id)
  local suffix = direction_suffix_map[direction]

  local animation = "ATTACK_" .. suffix

  Net.animate_bot(enemy.id, animation)
end

function EnemyHelpers.offset_position_with_direction(position, direction)
  position = {
    x = position.x,
    y = position.y,
    z = position.z
  }

  if direction == Direction.DOWN_LEFT then
    position.y = position.y + 1
  elseif direction == Direction.DOWN_RIGHT then
    position.x = position.x + 1
  elseif direction == Direction.UP_LEFT then
    position.x = position.x - 1
  elseif direction == Direction.UP_RIGHT then
    position.x = position.y - 1
  end

  return position
end

return EnemyHelpers

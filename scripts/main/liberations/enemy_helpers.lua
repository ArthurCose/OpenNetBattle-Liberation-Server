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

return EnemyHelpers

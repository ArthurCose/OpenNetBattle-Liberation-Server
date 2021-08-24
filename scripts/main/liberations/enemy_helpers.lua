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

-- takes instance to move player cameras
function EnemyHelpers.move(instance, enemy, x, y, z)
  x = math.floor(x)
  y = math.floor(y)

  local slide_time = .5
  local hold_time = .25
  local startup_time = .25
  local animation_time = .042

  local co = coroutine.create(function()
    Async.await(Async.sleep(hold_time))

    for _, player in ipairs(instance.players) do
      Net.slide_player_camera(player.id, x + .5, y + .5, z, slide_time)
    end

    local area_id = Net.get_bot_area(enemy.id)

    -- create blur
    local blur_bot_id = Net.create_bot({
      texture_path = "/server/assets/bots/blur.png",
      animation_path = "/server/assets/bots/blur.animation",
      area_id = area_id,
      warp_in = false,
      x = enemy.x + .5 + (1 / 32),
      y = enemy.y + .5 + (1 / 32),
      z = enemy.z + 1
    })

    -- animate blur
    Net.animate_bot(blur_bot_id, "DISAPPEAR", false)

    Async.await(Async.sleep(animation_time))

    -- move this bot off screen
    local area_width = Net.get_width(area_id)
    Net.transfer_bot(enemy.id, area_id, false, area_width + 100, 0, 0)

    Async.await(Async.sleep(slide_time + startup_time))

    -- animate blur
    Net.transfer_bot(
      blur_bot_id,
      area_id,
      false,
      x + .5 + (1 / 32),
      y + .5 + (1 / 32),
      z + 1
    )
    Net.animate_bot(blur_bot_id, "APPEAR", false)

    Async.await(Async.sleep(animation_time))

    -- move the enemy
    Net.transfer_bot(enemy.id, area_id, false, x + .5, y + .5, z)

    -- delete the blur bot
    Net.remove_bot(blur_bot_id)

    Async.await(Async.sleep(hold_time))

    enemy.x = x
    enemy.y = y
    enemy.z = z
  end)

  return Async.promisify(co)
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

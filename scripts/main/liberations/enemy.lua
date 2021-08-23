-- enemy implementations are in the enemies folder
-- enemy shape:
-- { id, is_boss?, health, x, y, z, mug? }
--   :new(instance, position, direction)
--   :take_turn() -- promise
--   :get_death_message() -- string

local BlizzardMan = require("scripts/main/liberations/enemies/blizzardman")
local BigBrute = require("scripts/main/liberations/enemies/bigbrute")
local EnemyHelpers = require("scripts/main/liberations/enemy_helpers")
local ExplodingEffect = require("scripts/util/exploding_effect")

local Enemy = {}

local name_to_enemy = {
  BlizzardMan = BlizzardMan,
  BigBrute = BigBrute,
}

function Enemy.from(instance, position, direction, name)
  if instance:get_panel_at(position.x, position.y, position.z).data.gid == instance.DARK_HOLE_PANEL_GID then
    -- push the enemy out of the dark hole
    position = EnemyHelpers.offset_position_with_direction(position, direction)
  end

  local enemy = name_to_enemy[name]:new(instance, position, direction)
  Net.set_bot_name(enemy.id, name .. ": " .. enemy.health)

  return enemy
end

function Enemy.is_alive(enemy)
  return Net.is_bot(enemy.id)
end

function Enemy.destroy(instance, enemy)
  local co = coroutine.create(function()
    if not Enemy.is_alive(enemy) then
      -- already died
      return
    end

    -- begin exploding the enemy
    local explosions = ExplodingEffect:new(enemy.id)

    -- moving every player's camera to the enemy
    local slide_time = .2
    local hold_time = 2

    local lock_tracker = {}

    for _, player in ipairs(instance.players) do
      lock_tracker[player.id] = Net.is_player_input_locked(player.id)
      Net.lock_player_input(player.id)

      Net.slide_player_camera(player.id, enemy.x + .5, enemy.y + .5, enemy.z, slide_time)
      Net.move_player_camera(player.id, enemy.x + .5, enemy.y + .5, enemy.z, hold_time)

      local player_pos = Net.get_player_position(player.id)
      Net.slide_player_camera(player.id, player_pos.x, player_pos.y, player_pos.z, slide_time)
      Net.unlock_player_camera(player.id)
    end

    Async.await(Async.sleep(slide_time))

    -- display death message
    local message = enemy:get_death_message()
    local texture_path = enemy.mug and enemy.mug.texture_path
    local animation_path = enemy.mug and enemy.mug.animation_path

    for _, player in ipairs(instance.players) do
      player:message(message, texture_path, animation_path)
    end

    Async.await(Async.sleep(hold_time))

    -- remove from the instance
    for i, stored_enemy in pairs(instance.enemies) do
      if enemy == stored_enemy then
        table.remove(instance.enemies, i)
        break
      end
    end

    -- remove from the server
    Net.remove_bot(enemy.id)

    -- stop explosions
    explosions:remove()

    -- padding time to fix issues with unlock_player_camera
    -- also looks nice with items
    local unlock_padding = .3

    Async.await(Async.sleep(slide_time + unlock_padding))


    -- unlock players who were not locked
    for _, player in ipairs(instance.players) do
      if not lock_tracker[player.id] then
        Net.unlock_player_input(player.id)
      end
    end
  end)

  return Async.promisify(co)
end

return Enemy

local counter = 0
local ID_PREFIX = "LIB_ITEM"
local SHADOW_ID_PREFIX = "LIB_SHADOW"

local Loot = {
  HEART = {
    animation = "HEART",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message_with_mug("I found\na heart!").and_then(function()
          player_session:heal(player_session.max_health / 2)
          resolve()
        end)
      end)
    end
  },
  CHIP = {
    animation = "CHIP",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message_with_mug("I found a\nBattleChip!").and_then(function()
          resolve()
        end)
      end)
    end
  },
  ZENNY = {
    animation = "ZENNY",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message_with_mug("I found some\nMonies!").and_then(function()
          resolve()
        end)
      end)
    end
  },
  BUGFRAG = {
    animation = "BUGFRAG",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message_with_mug("I found a\nBugFrag!").and_then(function()
          resolve()
        end)
      end)
    end
  },
  ORDER_POINT = {
    animation = "ORDER_POINT",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message_with_mug("I found\nOrder Points!")

        local previous_points = instance.order_points
        instance.order_points = math.min(instance.order_points + 3, instance.MAX_ORDER_POINTS)

        local recovered_points = instance.order_points - previous_points
        player_session:message(recovered_points .. "\nOrder Pts Recovered!").and_then(function()
          resolve()
        end)
      end)
    end
  },
  INVINCIBILITY = {
    animation = "INVINCIBILITY",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message("Team becomes invincible for\n 1 phase!!").and_then(function()
          resolve()
        end)
      end)
    end
  },
  MAJOR_HIT = {
    animation = "MAJOR_HIT",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        player_session:message("Damages the closest enemy the most!").and_then(function()
          resolve()
        end)
      end)
    end
  },
  KEY = {
    animation = "KEY",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        resolve()
      end)
    end
  },
  TRAP = {
    animation = "TRAP",
    activate = function(instance, player_session)
      return Async.create_promise(function(resolve)
        resolve()
      end)
    end
  },
}

Loot.DEFAULT_POOL = {
  Loot.HEART,
  -- Loot.CHIP,
  -- Loot.ZENNY,
  -- Loot.BUGFRAG,
  Loot.ORDER_POINT,
}

Loot.BONUS_POOL = {
  Loot.HEART,
  -- Loot.CHIP,
  Loot.ORDER_POINT,
  -- Loot.INVINCIBILITY,
  -- Loot.MAJOR_HIT,
}

Loot.TEST_POOL = {
  Loot.HEART,
  Loot.CHIP,
  Loot.ZENNY,
  Loot.BUGFRAG,
  Loot.ORDER_POINT,
}

local RISE_DURATION = .1

-- returns a promise that resolves when the animation finishes
-- resolved value is a function that cleans up the bot
function Loot.spawn_item_bot(item, area_id, x, y, z)
  local bot_data = {
    area_id = area_id,
    texture_path = "/server/assets/bots/item.png",
    animation_path = "/server/assets/bots/item.animation",
    animation = item.animation,
    warp_in = false,
    x = x,
    y = y,
    z = z,
  }

  local property_animation = {
    {
      properties = {
        { property = "Z", ease = "Linear", value = z + 1 }
      },
      duration = RISE_DURATION
    },
  }

  -- return a promise that resolves when the animation finishes
  return Async.create_promise(function(resolve)
    local cleanup = spawn_item_bot(bot_data, property_animation)

    Async.sleep(RISE_DURATION).and_then(function()
      resolve(cleanup)
    end)
  end)
end

-- returns a promise that resolves when the animation finishes
-- resolved value is a function that cleans up the bot
function Loot.spawn_randomized_item_bot(loot_pool, item_index, area_id, x, y, z)
  local target_duration = 2
  local frame_duration = .05
  local total_frames = math.ceil(target_duration / frame_duration)

  local start_index = (item_index - total_frames - 2) % #loot_pool + 1

  local bot_data = {
    area_id = area_id,
    texture_path = "/server/assets/bots/item.png",
    animation_path = "/server/assets/bots/item.animation",
    animation = loot_pool[start_index].animation,
    warp_in = false,
    x = x,
    y = y,
    z = z,
  }

  local property_animation = {}

  local total_duration = 0
  local added_rise = false

  for i = 1, total_frames, 1 do
    local current_item_index = (start_index + i) % #loot_pool + 1

    local key_frame = {
      properties = {
        { property = "Animation", value = loot_pool[current_item_index].animation }
      },
      duration = frame_duration
    }

    total_duration = total_duration + frame_duration

    if not added_rise and total_duration >= RISE_DURATION then
      -- animate rising
      key_frame.properties[#key_frame.properties] = { property = "Z", ease = "Linear", value = z + 1 }
      added_rise = true
    end

    property_animation[#property_animation+1] = key_frame
  end

  -- return a promise that resolves when the animation finishes
  return Async.create_promise(function(resolve)
    local cleanup = spawn_item_bot(bot_data, property_animation)

    Async.sleep(total_duration).and_then(function()
      resolve(cleanup)
    end)
  end)
end

-- returns a promise, resolves when looting is completed
function Loot.loot_item_panel(instance, player_session, panel)
  local slide_time = .1

  Net.slide_player_camera(
    player_session.player_id,
    math.min(panel.x) + .5,
    math.min(panel.y) + .5,
    panel.z,
    slide_time
  )

  local co = coroutine.create(function()
    Async.await(Async.sleep(slide_time))

    local spawn_x = math.floor(panel.x) + .5
    local spawn_y = math.floor(panel.y) + .5
    local spawn_z = panel.z

    local remove_item_bot = Async.await(Loot.spawn_item_bot(panel.loot, instance.area_id, spawn_x, spawn_y, spawn_z))

    Async.await(panel.loot.activate(instance, player_session))

    remove_item_bot()
  end)

  return Async.promisify(co)
end

-- private functions

function spawn_item_bot(bot_data, property_animation)
  local id = ID_PREFIX .. counter
  local shadow_id = SHADOW_ID_PREFIX .. counter
  counter = counter + 1

  Net.create_bot(
    shadow_id,
    {
      area_id = bot_data.area_id,
      texture_path = "/server/assets/bots/item.png",
      animation_path = "/server/assets/bots/item.animation",
      animation = "SHADOW",
      warp_in = false,
      x = bot_data.x,
      y = bot_data.y,
      z = bot_data.z,
    }
  )

  Net.create_bot(
    id,
    bot_data
  )

  Net.animate_bot_properties(id, property_animation)

  function cleanup()
    Net.remove_bot(shadow_id)
    Net.remove_bot(id)
  end

  return cleanup
end

return Loot
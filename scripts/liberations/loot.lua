local counter = 0
local ID_PREFIX = "LIB_ITEM"
local SHADOW_ID_PREFIX = "LIB_SHADOW"

local Loot = {
  HEART = "HEART",
  CHIP = "CHIP",
  ZENNY = "ZENNY",
  BUGFRAG = "BUGFRAG",
  ORDER_POINT = "ORDER_POINT",
  INVINCIBILITY = "INVINCIBILITY",
  MAJOR_HIT = "MAJOR_HIT",
  KEY = "KEY",
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
  -- Loot.ZENNY,
  -- Loot.BUGFRAG,
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

-- returns a function that cleans up the bot
function Loot.spawn_item_bot(item_name, area_id, x, y, z)
  local bot_data = {
    area_id = area_id,
    texture_path = "/server/assets/bots/item.png",
    animation_path = "/server/assets/bots/item.animation",
    animation = item_name,
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

  return spawn_item_bot(bot_data, property_animation)
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
    animation = loot_pool[start_index],
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
        { property = "Animation", value = loot_pool[current_item_index] }
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

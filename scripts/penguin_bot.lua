local Direction = require("scripts/libs/direction")

local area = "default"
local spawn = Net.get_object_by_name(area, "Penguin Spawn")
local penguin_id = Net.create_bot({
  area_id = area,
  texture_path = "/server/assets/bots/penguin.png",
  animation_path = "/server/assets/bots/penguin.animation",
  x = spawn.x,
  y = spawn.y,
  z = spawn.z,
  direction = Direction.UP_LEFT,
  solid = true
})

local fart_id

function handle_actor_interaction(player_id, other_id, button)
  if other_id ~= penguin_id then
    return
  end

  Net.play_sound_for_player(player_id, "/server/assets/sound effects/club penguin fart emote.ogg")

  if fart_id then
    return
  end

  fart_id = Net.create_bot({
    area_id = area,
    texture_path = "/server/assets/bots/penguin.png",
    animation_path = "/server/assets/bots/penguin.animation",
    x = spawn.x,
    y = spawn.y,
    z = spawn.z,
    warp_in = false,
    animation = "FART"
  })

  Async.sleep(5).and_then(function()
    Net.remove_bot(fart_id, false)
    fart_id = nil
  end)
end

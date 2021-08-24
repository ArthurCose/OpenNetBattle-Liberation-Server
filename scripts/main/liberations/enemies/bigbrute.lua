local EnemyHelpers = require("scripts/main/liberations/enemy_helpers")
local EnemySelection = require("scripts/main/liberations/enemy_selection")
local Preloader = require("scripts/main/liberations/preloader")

Preloader.add_asset("/server/assets/bots/beast breath.png")
Preloader.add_asset("/server/assets/bots/beast breath.animation")

local BigBrute = {}

function BigBrute:new(instance, position, direction)
  local bigbrute = {
    instance = instance,
    id = nil,
    health = 120,
    x = math.floor(position.x),
    y = math.floor(position.y),
    z = math.floor(position.z),
    selection = EnemySelection:new(instance)
  }

  setmetatable(bigbrute, self)
  self.__index = self

  local shape = {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1}
  }

  bigbrute.selection:set_shape(shape, 0, -2)
  bigbrute:spawn(direction)

  return bigbrute
end

function BigBrute:spawn(direction)
  self.id = Net.create_bot({
    texture_path = "/server/assets/bots/bigbrute.png",
    animation_path = "/server/assets/bots/bigbrute.animation",
    area_id = self.instance.area_id,
    direction = direction,
    warp_in = false,
    x = self.x + .5,
    y = self.y + .5,
    z = self.z
  })
end

function BigBrute:get_death_message()
  return "Gyaaaaahh!!"
end

function BigBrute:take_turn()
  local co = coroutine.create(function()
    self.selection:move(self, Net.get_bot_direction(self.id))

    local caught_sessions = self.selection:detect_player_sessions()

    if #caught_sessions == 0 then
      return
    end

    self.selection:indicate()

    Async.await(Async.sleep(1))

    EnemyHelpers.play_attack_animation(self)

    local spawned_bots = {}

    for _, player_session in ipairs(caught_sessions) do
      local player = player_session.player

      spawned_bots[#spawned_bots+1] = Net.create_bot({
        texture_path = "/server/assets/bots/beast breath.png",
        animation_path = "/server/assets/bots/beast breath.animation",
        animation = "ANIMATE",
        area_id = self.instance.area_id,
        warp_in = false,
        x = player.x + 1 / 32,
        y = player.y + 1 / 32,
        z = player.z
      })

      player_session:hurt(20)
    end

    Async.await(Async.sleep(.5))

    for _, player in ipairs(self.instance.players) do
      Net.shake_player_camera(player.id, 2, .5)
    end

    Async.await(Async.sleep(.5))

    for _, bot_id in ipairs(spawned_bots) do
      Net.remove_bot(bot_id, false)
    end

    Async.await(Async.sleep(1))

    self.selection:remove_indicators()
  end)

  return Async.promisify(co)
end

return BigBrute

local EnemySelection = require("scripts/main/liberations/enemy_selection")

local BigBrute = {}

function BigBrute:new(instance, position, direction)
  local bigbrute = {
    instance = instance,
    id = nil,
    health = 120,
    x = math.min(position.x) + .5,
    y = math.min(position.y) + .5,
    z = position.z,
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
    x = self.x,
    y = self.y,
    z = self.z
  })
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

    local spawned_bots = {}

    for _, player_session in ipairs(caught_sessions) do
      local position = Net.get_player_position(player_session.player.id)

      spawned_bots[#spawned_bots+1] = Net.create_bot({
        texture_path = "/server/assets/bots/beast breath.png",
        animation_path = "/server/assets/bots/beast breath.animation",
        animation = "ANIMATE",
        area_id = self.instance.area_id,
        warp_in = false,
        x = position.x + 1 / 32,
        y = position.y + 1 / 32,
        z = position.z
      })

      player_session:hurt(20)
    end

    Async.await(Async.sleep(1))

    for _, bot_id in ipairs(spawned_bots) do
      Net.remove_bot(bot_id, false)
    end

    Async.await(Async.sleep(1))

    self.selection:remove_indicators()
  end)

  return Async.promisify(co)
end

return BigBrute

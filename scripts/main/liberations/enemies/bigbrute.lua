local BigBrute = {}

function BigBrute:new(instance, position, direction)
  local bigbrute = {
    instance = instance,
    id = nil,
    x = math.min(position.x) + .5,
    y = math.min(position.y) + .5,
    z = position.z
  }

  setmetatable(bigbrute, self)
  self.__index = self

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

  end)

  return Async.promisify(co)
end

return BigBrute

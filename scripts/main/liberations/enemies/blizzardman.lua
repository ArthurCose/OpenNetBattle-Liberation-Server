local BlizzardMan = {}

function BlizzardMan:new(instance, position, direction)
  local blizzardman = {
    instance = instance,
    id = nil,
    health = 400,
    x = math.floor(position.x),
    y = math.floor(position.y),
    z = math.floor(position.z),
    mug = {
      texture_path = "/server/assets/mugs/blizzardman.png",
      animation_path = "/server/assets/mugs/blizzardman.animation",
    }
  }

  setmetatable(blizzardman, self)
  self.__index = self

  blizzardman:spawn(direction)

  return blizzardman
end

function BlizzardMan:spawn(direction)
  self.id = Net.create_bot({
    texture_path = "/server/assets/bots/blizzardman.png",
    animation_path = "/server/assets/bots/blizzardman.animation",
    area_id = self.instance.area_id,
    direction = direction,
    warp_in = false,
    x = self.x + .5,
    y = self.y + .5,
    z = self.z
  })
end

function BlizzardMan:get_death_message()
  return "Woosh!\nI can't believe\nit. I can't lose.\nNOOOO!"
end

function BlizzardMan:take_turn()
  local co = coroutine.create(function()
    if self.instance.phase == 1 then
      for _, player in ipairs(self.instance.players) do
        player:message(
          "I'll turn this area into a Nebula ski resort! Got it?",
          self.mug.texture_path,
          self.mug.animation_path
        )
      end

      -- Allow time for the players to read this message
      Async.await(Async.sleep(3))
    end
  end)

  return Async.promisify(co)
end

return BlizzardMan

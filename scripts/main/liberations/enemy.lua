-- enemy implementations are in the enemies folder
-- enemy shape:
-- { id, is_boss?, x, y, z }
--   :new(instance, position, direction)
--   :take_turn() -- returns a promise

local BlizzardMan = require("scripts/main/liberations/enemies/blizzardman")
local BigBrute = require("scripts/main/liberations/enemies/bigbrute")

local Enemy = {}

local name_to_enemy = {
  BlizzardMan = BlizzardMan,
  BigBrute = BigBrute,
}

function Enemy.from(instance, position, direction, name)
  return name_to_enemy[name]:new(instance, position, direction)
end

return Enemy

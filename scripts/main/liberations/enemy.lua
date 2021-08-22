-- enemy implementations are in the enemies folder
-- enemy shape:
-- { id, is_boss?, health, x, y, z }
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
  local enemy = name_to_enemy[name]:new(instance, position, direction)
  Net.set_bot_name(enemy.id, name .. ": " .. enemy.health)

  return enemy
end

return Enemy

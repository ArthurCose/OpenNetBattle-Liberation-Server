local Ability = require("scripts/liberations/ability")
local PanelSelection = require("scripts/liberations/panel_selection")

local PlayerSession = {}

function PlayerSession:new(instance, player_id)
  local player_session = {
    instance = instance,
    player_id = player_id,
    health = 100,
    max_health = 100,
    completed_turn = false,
    panel_selection = PanelSelection:new(instance, player_id),
    ability = Ability.LongSwrd, -- todo: resolve from element/name
    mug = Net.get_player_mugshot(player_id),
    on_response = nil
  }

  setmetatable(player_session, self)
  self.__index = self

  Net.set_player_health(player_id, player_session.health)
  Net.set_player_max_health(player_id, player_session.max_health)

  return player_session
end

function PlayerSession:message_with_mug(message)
  Net.message_player(self.player_id, message, self.mug.texture_path, self.mug.animation_path)
end

function PlayerSession:heal(amount)
  self.health = math.min(math.ceil(self.health + amount), self.max_health)
  Net.set_player_health(self.player_id, self.health)
end

function PlayerSession:pass_turn()
  -- heal up to 50% of health
  self:heal(self.max_health / 2)

  self:complete_turn()
end

function PlayerSession:complete_turn()
  self.instance.ready_count = self.instance.ready_count + 1
  self.completed_turn = true
  self.panel_selection:clear()
  Net.lock_player_input(self.player_id)
end

function PlayerSession:give_turn()
  self.completed_turn = false
  Net.unlock_player_input(self.player_id)
end

function PlayerSession:handle_disconnect()
  self.panel_selection:clear()

  if self.completed_turn then
    self.instance.ready_count = self.instance.ready_count - 1
  end
end

return PlayerSession
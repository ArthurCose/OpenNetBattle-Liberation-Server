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
    on_response = nil
  }

  setmetatable(player_session, self)
  self.__index = self

  return player_session
end

function PlayerSession:pass_turn()
  -- heal up to 50% of health
  self.health = math.min(self.health + self.max_health / 2, self.max_health)
  Net.set_player_health(self.player_id, self.health)

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
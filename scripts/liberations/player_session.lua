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
    textbox_promise_resolvers = {}
  }

  setmetatable(player_session, self)
  self.__index = self

  Net.set_player_health(player_id, player_session.health)
  Net.set_player_max_health(player_id, player_session.max_health)

  return player_session
end

-- all messages to this player should be made through the session while the session is alive
function PlayerSession:message(message, texture_path, animation_path)
  Net.message_player(self.player_id, message, texture_path, animation_path)

  return create_textbox_promise(self.textbox_promise_resolvers)
end

-- all messages to this player should be made through the session while the session is alive
function PlayerSession:message_with_mug(message)
  return self:message(message, self.mug.texture_path, self.mug.animation_path)
end

-- all questions to this player should be made through the session while the session is alive
function PlayerSession:question(question, texture_path, animation_path)
  Net.question_player(self.player_id, question, texture_path, animation_path)

  return create_textbox_promise(self.textbox_promise_resolvers)
end

-- all questions to this player should be made through the session while the session is alive
function PlayerSession:question_with_mug(question)
  return self:question(question, self.mug.texture_path, self.mug.animation_path)
end

-- all quizzes to this player should be made through the session while the session is alive
function PlayerSession:quiz(a, b, c, texture_path, animation_path)
  Net.quiz_player(self.player_id, a, b, c, texture_path, animation_path)

  return create_textbox_promise(self.textbox_promise_resolvers)
end

function PlayerSession:get_ability_permission()
  local question_promise = self:question_with_mug(self.ability.question)

  question_promise.and_then(function(response)
    if response == 0 then
      -- No
      self.panel_selection:clear()
      Net.unlock_player_input(self.player_id)
      return
    end

    -- Yes

    if self.instance.order_points < self.ability.cost then
      -- not enough order points
      self:message("Not enough Order Pts!")
      return
    end

    self.instance.order_points = self.instance.order_points - self.ability.cost
    self.ability.activate(self.instance, self)
  end)
end

function PlayerSession:get_pass_turn_permission()
  local question = "End without doing anything?"

  if self.health < self.max_health then
    quesiton = "Recover HP?"
  end

  local question_promise = self:question_with_mug(question)

  question_promise.and_then(function(response)
    if response == 0 then
      -- No
      Net.unlock_player_input(self.player_id)
      return
    end

    -- Yes
    self:pass_turn()
  end)
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

-- will throw if a textbox is sent to the player using Net directly
function PlayerSession:handle_textbox_response(response)
  local resolve = table.remove(self.textbox_promise_resolvers, 1)
  resolve(response)
end

-- private functions

function create_textbox_promise(textbox_promise_resolvers)
  return Async.create_promise(function(resolve)
    textbox_promise_resolvers[#textbox_promise_resolvers+1] = resolve
  end)
end

-- export
return PlayerSession
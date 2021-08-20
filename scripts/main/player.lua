local Player = {}

function Player:new(player_id)
  local panel_selection = {
    id = player_id,
    activity = nil,
    mug = Net.get_player_mugshot(player_id),
    textbox_promise_resolvers = {}
  }

  setmetatable(panel_selection, self)
  self.__index = self

  return panel_selection
end

-- all messages to this player should be made through the session while the session is alive
function Player:message(message, texture_path, animation_path)
  Net.message_player(self.id, message, texture_path, animation_path)

  return create_textbox_promise(self.textbox_promise_resolvers)
end

-- all messages to this player should be made through the session while the session is alive
function Player:message_with_mug(message)
  return self:message(message, self.mug.texture_path, self.mug.animation_path)
end

-- all questions to this player should be made through the session while the session is alive
function Player:question(question, texture_path, animation_path)
  Net.question_player(self.id, question, texture_path, animation_path)

  return create_textbox_promise(self.textbox_promise_resolvers)
end

-- all questions to this player should be made through the session while the session is alive
function Player:question_with_mug(question)
  return self:question(question, self.mug.texture_path, self.mug.animation_path)
end

-- all quizzes to this player should be made through the session while the session is alive
function Player:quiz(a, b, c, texture_path, animation_path)
  Net.quiz_player(self.id, a, b, c, texture_path, animation_path)

  return create_textbox_promise(self.textbox_promise_resolvers)
end

-- will throw if a textbox is sent to the player using Net directly
function Player:handle_textbox_response(response)
  local resolve = table.remove(self.textbox_promise_resolvers, 1)
  resolve(response)
end

-- private functions

function create_textbox_promise(textbox_promise_resolvers)
  return Async.create_promise(function(resolve)
    textbox_promise_resolvers[#textbox_promise_resolvers+1] = resolve
  end)
end

return Player
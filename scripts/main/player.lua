-- private functions

local function create_textbox_promise(self)
  if self.disconnected then
    return Async.create_promise(function(resolve)
      resolve()
    end)
  end

  return Async.create_promise(function(resolve)
    self.textbox_promise_resolvers[#self.textbox_promise_resolvers+1] = resolve
  end)
end

-- public
local Player = {}

function Player:new(player_id)
  local position = Net.get_player_position(player_id)

  local player = {
    id = player_id,
    activity = nil,
    mug = Net.get_player_mugshot(player_id),
    textbox_promise_resolvers = {},
    resolve_battle = nil,
    avatar_details = nil,
    x = position.x,
    y = position.y,
    z = position.z,
    disconnected = false
  }

  setmetatable(player, self)
  self.__index = self

  return player
end

-- all messages to this player should be made through the session while the session is alive
function Player:message(message, texture_path, animation_path)
  Net.message_player(self.id, message, texture_path, animation_path)

  return create_textbox_promise(self)
end

-- all messages to this player should be made through the session while the session is alive
function Player:message_with_mug(message)
  return self:message(message, self.mug.texture_path, self.mug.animation_path)
end

-- all questions to this player should be made through the session while the session is alive
function Player:question(question, texture_path, animation_path)
  Net.question_player(self.id, question, texture_path, animation_path)

  return create_textbox_promise(self)
end

-- all questions to this player should be made through the session while the session is alive
function Player:question_with_mug(question)
  return self:question(question, self.mug.texture_path, self.mug.animation_path)
end

-- all quizzes to this player should be made through the session while the session is alive
function Player:quiz(a, b, c, texture_path, animation_path)
  Net.quiz_player(self.id, a, b, c, texture_path, animation_path)

  return create_textbox_promise(self)
end

function Player:is_battling()
  return self.resolve_battle ~= nil
end

-- all quizzes to this player should be made through the session while the session is alive
function Player:initiate_encounter(asset_path)
  if self.disconnected then
    return Async.create_promise(function(resolve)
      resolve({ran = true})
    end)
  end

  if self:is_battling() then
    error("This player is already in a battle")
  end

  Net.initiate_encounter(asset_path)

  return Async.create_promise(function(resolve)
    self.resolve_battle = resolve
  end)
end

-- will throw if a textbox is sent to the player using Net directly
function Player:handle_textbox_response(response)
  local resolve = table.remove(self.textbox_promise_resolvers, 1)
  resolve(response)
end

-- will throw if a battle is initiated using Net directly
function Player:handle_battle_results(stats)
  local resolve = self.resolve_battle
  self.resolve_battle = nil
  resolve(stats)
end

function Player:handle_disconnect()
  self.disconnected = true

  for _, resolve in ipairs(self.textbox_promise_resolvers) do
    resolve()
  end

  if self.resolve_battle then
    self:handle_battle_results({ran = true})
  end

  self.textbox_promise_resolvers = nil

  if self.activity then
    self.activity:handle_player_disconnect(self.id)
  end
end

function Player:boot_to_lobby()
  self.activity:handle_player_disconnect(self.id)
  self.activity = nil

  local spawn = Net.get_spawn_position("default")
  Net.transfer_player(self.id, "default", true, spawn.x, spawn.y, spawn.z)

  Net.set_player_health(self.id, self.avatar_details.max_health)
  Net.set_player_max_health(self.id, self.avatar_details.max_health)
end

return Player

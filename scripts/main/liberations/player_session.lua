local Ability = require("scripts/main/liberations/ability")
local PlayerSelection = require("scripts/main/liberations/player_selection")
local Loot = require("scripts/main/liberations/loot")

local PlayerSession = {}

function PlayerSession:new(instance, player)
  local player_session = {
    instance = instance,
    player = player,
    health = 100,
    max_health = 100,
    completed_turn = false,
    selection = PlayerSelection:new(instance, player.id),
    ability = Ability.LongSwrd, -- todo: resolve from element/name
  }

  setmetatable(player_session, self)
  self.__index = self

  Net.set_player_health(player.id, player_session.health)
  Net.set_player_max_health(player.id, player_session.max_health)

  return player_session
end

function PlayerSession:get_ability_permission()
  local question_promise = self.player:question_with_mug(self.ability.question)

  question_promise.and_then(function(response)
    if response == 0 then
      -- No
      self.selection:clear()
      Net.unlock_player_input(self.player.id)
      return
    end

    -- Yes

    if self.instance.order_points < self.ability.cost then
      -- not enough order points
      self.player:message("Not enough Order Pts!")
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

  local question_promise = self.player:question_with_mug(question)

  question_promise.and_then(function(response)
    if response == 0 then
      -- No
      Net.unlock_player_input(self.player.id)
      return
    end

    -- Yes
    self:pass_turn()
  end)
end

function PlayerSession:heal(amount)
  self.health = math.min(math.ceil(self.health + amount), self.max_health)
  Net.set_player_health(self.player.id, self.health)
end

function PlayerSession:pass_turn()
  -- heal up to 50% of health
  self:heal(self.max_health / 2)

  self:complete_turn()
end

function PlayerSession:liberate_panels(panels)
  local co = coroutine.create(function()
    -- allow time for the player to see the liberation range
    Async.await(Async.sleep(1))

    for _, panel in ipairs(panels) do
      self.instance:remove_panel(panel)
    end

    self.selection:clear()

    Async.await(self.player:message_with_mug("Yeah!\nI liberated it!"))
  end)

  return Async.promisify(co)
end

-- returns a promise that resolves after looting
function PlayerSession:loot_panels(panels)
  local co = coroutine.create(function()
    for _, panel in ipairs(panels) do
      if panel.loot then
        -- loot the panel if it has loot
        Async.await(Loot.loot_item_panel(self.instance, self, panel))
      end
    end
  end)

  return Async.promisify(co)
end


function PlayerSession:liberate_and_loot_panels(panels)
  return Async.create_promise(function(resolve)
    self:liberate_panels(panels).and_then(function()
      self:loot_panels(panels).and_then(resolve)
    end)
  end)
end

function PlayerSession:complete_turn()
  self.completed_turn = true
  self.selection:clear()
  Net.lock_player_input(self.player.id)

  self.instance.ready_count = self.instance.ready_count + 1

  if self.instance.ready_count < #self.instance.player_list then
    Net.unlock_player_camera(self.player.id)
  end
end

function PlayerSession:give_turn()
  self.completed_turn = false
  Net.unlock_player_input(self.player.id)
end

function PlayerSession:handle_disconnect()
  self.selection:clear()

  if self.completed_turn then
    self.instance.ready_count = self.instance.ready_count - 1
  end
end

-- export
return PlayerSession

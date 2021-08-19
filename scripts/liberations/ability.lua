-- todo: pass terrain to activate()? https://megaman.fandom.com/wiki/Liberation_Mission#:~:text=corresponding%20Barrier%20Panel.-,Terrain,-Depending%20on%20the

local Ability = {
  Guard = {}, -- passive, knightman's ability
  LongSwrd = {
    name = "LongSwrd",
    question = "Use LongSwrd to liberate?",
    cost = 1,
    shape = {
      {1},
      {1}
    },
    activate = function (instance, player_session)
      -- todo: start battle, needs success handler? maybe on the player_data like on_response?
      player_session.panel_selection:liberate()
      player_session:complete_turn()
    end
  },
  ScrenDiv = {
    name = "ScrenDiv",
    question = "Use ScrenDiv to liberate?",
    cost = 1,
    shape = {
      {1, 1, 1}
    },
    activate = function (instance, player_session)
      -- todo: start battle, needs success handler? maybe on the player_data like on_response?
      player_session.panel_selection:liberate()
      player_session:complete_turn()
    end
  },
  PanelSearch = {
    name = "PanelSearch",
    question = "Search in this area?",
    cost = 1,
    shape = {
      {1},
      {1},
      {1}
    },
    activate = function (instance, player_session)
      -- todo: use Async.sleep in a coroutine+loop to adjust shape and play a sound
      -- https://www.youtube.com/watch?v=Q62Ek8_KP1Q&t=3887s
    end
  }
}

return Ability
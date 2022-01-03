local json = require('scripts/libs/json')

local area_ids = Net.list_areas()

-- [area_id .. id] = posts: { id: string, read: bool?, title: string?, author: string? }[]
local boards = {}
-- [post_id] = title: string
local id_to_message = {}

for _, area_id in ipairs(area_ids) do
  local object_ids = Net.list_objects(area_id)

  for _, object_id in ipairs(object_ids) do
    local object = Net.get_object_by_id(area_id, object_id)

    if object.name == "Known Issues" then
      local repo = object.custom_properties.Repo

      local posts = {}
      boards[area_id .. object.id] = posts

      Async.request("https://api.github.com/repos/" .. repo .. "/issues").and_then(function(response) -- { status, headers, body }
        if not response or response.status ~= 200 then
          print("Failed to download issues for " .. repo)
          return
        end

        local body = json.decode(response.body)

        for _, issue in ipairs(body) do
          posts[#posts+1] = {
            id = issue.id,
            title = string.sub(issue.title, 1, 14),
            author = string.sub(issue.user.login, 1, 7),
            read = true,
          }

          local message

          if issue.body then
            message = "["..issue.title .."]\n"..issue.body
          else
            message = issue.title
          end

          id_to_message[tostring(issue.id)] = message
        end
      end)
    end
  end
end

function handle_object_interaction(player_id, object_id)
  local area_id = Net.get_player_area(player_id)

  local posts = boards[area_id..object_id]

  if not posts then
    return
  end

  local color = { r = 25, g = 25, b = 25 }
  Net.open_board(player_id, "Known Issues (from Github)", color, posts)
end

function handle_post_selection(player_id, post_id)
  local title = id_to_message[post_id]

  if not title then
    return
  end

  Net.message_player(player_id, title)
end

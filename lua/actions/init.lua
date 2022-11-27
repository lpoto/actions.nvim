local log = require "actions.log"
local setup = require "actions.setup"
local available_actions = require "actions.window.available_actions"
local output_window = require "actions.window.output"

local actions = {}

---Set up the plugin and add actions.
---
---@param user_config table
---@see User_config
function actions.setup(user_config)
  local err = setup.parse(user_config)
  if err ~= nil then
    log.error(err)
  end
end

---Opens a window with all the available actions.
---From that window the actions may then be executed,
---killed and their output or definition shown.
function actions.available_actions()
  available_actions.open()
end

---Reopens the last oppened action output window.
function actions.toggle_last_output()
  output_window.toggle_last()
end

return actions

local log = require "actions.log"
local setup = require "actions.setup"
local available_actions = require "actions.window.available_actions"
local actions_output = require "actions.window.action_output"
local clean_output = require "actions.clean_output"

local actions = {}

---Set up the plugin and add actions.
---
---@param user_config table
---@return nil
function actions.setup(user_config)
  local err = setup.parse(user_config)
  if err ~= nil then
    log.error(err)
  end
end

---Opens a window with all the available actions.
---From that window the actions may then be executed,
---killed, or their output shown.
---@return nil
function actions.open()
  available_actions.open()
end

---Reopens the last oppened action output window.
---@return nil
function actions.toggle_last_output()
  actions_output.toggle_last()
end

---Delete the output directory. When name is provided,
---delete only the output file that belongs to the action identified
---by the provided name.
---
---@param name string?: An action's name
function actions.clean_output(name)
  clean_output.clean(name)
end

return actions

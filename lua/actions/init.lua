local log = require "actions.log"
local setup = require "actions.setup"
local available_actions = require "actions.window.available_actions"
local output_window = require "actions.window.output"

local actions = {}

---@tag actions.nvim
---@config {["name"] = "INTRODUCTION"}

---@brief [[
---Actions.nvim helps you set up custom commands and their environments
---relative to the current context.
---All the currently available actions may be displayed in a floating
---window from which they may be executed, killed and their outputs
---or definitions shown.
---
---Getting started with actions:
---  1. |actions.setup|
---  2. |actions.available_actions|
---  3. |actions.toggle_last_output|
---
---@brief ]]

---Set up the plugin and add actions with a |Actions_user_config| object.
---Calling this function multiple times will merge the added configs.
---
---@param user_config Actions_user_config: See |Actions_user_config|.
function actions.setup(user_config)
  local err = setup.parse(user_config)
  if err ~= nil then
    log.error(err)
  end
end

---Opens a floating window with all the available actions.
---From that window the actions may then be executed,
---killed and their output or definition shown.
function actions.available_actions()
  available_actions.open()
end

---Reopens the last output window of the last run action,
---or the last opened output buffer.
function actions.toggle_last_output()
  output_window.toggle_last()
end

return actions

local setup = require "actions.setup"

local actions = {}

---Set up the plugin and add actions.
---
---@param user_config table
---@return nil
function actions.setup(user_config)
  setup.parse(user_config)
end

---Opens a window with all the available actions.
---From that window the actions may then be executed,
---killed, or their output shown.
---@return nil
function actions.list() end

return actions

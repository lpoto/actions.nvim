local setup = require "actions.setup"

local actions = {}

---Add actions in a table with their names as keys
---and their definitions as values.
---
---@param actions_table table
---@return nil
function actions.setup(actions_table)
  setup.add(actions_table)
end

---Opens a window with all the available actions.
---From that window the actions may then be executed,
---killed, or their output shown.
---@return nil
function actions.list() end

return actions

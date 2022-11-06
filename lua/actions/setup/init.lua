local Action, _ = require "actions.model"

---A table of actions with their names as keys
---and definitions as values
---@type table
local actions = {}

local setup = {}

---Verify the actions in the provided table,
---and add them to the setup.actions table on success.
---Notifies errors and warnings if they occur.
---
---@param actions_table table
---@return nil
function setup.add(actions_table)
  if type(actions_table) ~= "table" then
    vim.notify(
      "Actions.nvim: Param 'actions_table' should be a table!",
      vim.log.levels.ERROR
    )
    return
  end
  for name, o in pairs(actions_table) do
    local action, err = Action.create(name, o)
    if err ~= nil then
      vim.notify("Actions.nvim: " .. err, vim.log.levels.WARN)
    else
      actions[action:get_name()] = action
    end
  end
end

---Get a table of available actions.
---Actions are available when the current filename
---matches their patterns and the current filetype matches
---their filetypes.
---
---@return table: A table of actions.
function setup.get_available()
  local actions_table = {}
  for _, action in pairs(actions) do
    if action:is_available() then
      table.insert(actions_table, action)
    end
  end
  return actions_table
end

return setup

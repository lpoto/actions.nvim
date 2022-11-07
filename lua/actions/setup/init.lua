local log = require "actions.util.log"
local Action = require "actions.model.action"

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
    log.error "Param 'actions_table' should be a table!"
    return
  end
  for name, o in pairs(actions_table) do
    local action, err = Action.create(name, o)
    if err ~= nil then
      log.warn(err)
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

---Get an action identified by the provided name.
---
---@param name string: name of an action
---@return Action|nil: action identified by the provided name
function setup.get_action(name)
  return actions[name]
end

return setup

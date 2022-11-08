local User_config = require "actions.model.user_config"

local setup = {}

setup.config = User_config.default()

---Parse the provided table into a User_config class
---Use default config on any errors.
---
---@param o table
---@return string|nil: Error that occured when parsing
function setup.parse(o)
  local cfg, e = User_config.create(o)
  if e ~= nil then
    return e
  end
  setup.config = cfg
  return nil
end

---Get a table of available actions.
---Actions are available when the current filename
---matches their patterns and the current filetype matches
---their filetypes.
---
---@return table: A table of actions.
function setup.get_available()
  local actions_table = {}
  for _, action in pairs(setup.config.actions) do
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
  return setup.config.actions[name]
end

return setup

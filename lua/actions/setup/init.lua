local User_config = require "actions.model.user_config"

local log = require "actions.util.log"

---@type User_config
local user_config = User_config.default()

local setup = {}
---Parse the provided table into a User_config class
---Use default config on any errors.
---
---@param o table
---@return nil
function setup.parse(o)
  local cfg, e = User_config.create(o)
  if e ~= nil then
    log.error(e)
    return
  end
  user_config = cfg
  log.setup(user_config.log)
end

---Get a table of available actions.
---Actions are available when the current filename
---matches their patterns and the current filetype matches
---their filetypes.
---
---@return table: A table of actions.
function setup.get_available()
  local actions_table = {}
  for _, action in pairs(user_config.actions) do
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
  return user_config.actions[name]
end

---Get the log config from the user config
---
---@return Log_config
function setup.get_log_config()
  return user_config.log
end

return setup

local Actions_user_config = require "actions.model.user_config"
local Action = require "actions.model.action"

local setup = {}

setup.config = Actions_user_config.__default()

---Parse the provided table into a Actions_user_config class
---Use default config on any errors.
---
---@param o table
---@return string|nil: Error that occured when parsing
function setup.parse(o)
  local cfg, e = Actions_user_config.__create(o)
  if e ~= nil then
    return e
  end
  Actions_user_config.__merge(setup.config, cfg)
  return nil
end

---Get a table of available actions.
---Actions are available when the current filename
---matches their patterns and the current filetype matches
---their filetypes.
---
---@param temp_buf number?: A temporary bufer from which to check actions
---@return table: A table of actions.
---@return string?: Error that occured while checking actions.
function setup.get_available(temp_buf)
  ---@type table
  local actions_table = {}
  ---@type string?
  local e = nil
  local check = function()
    for name, action_f in pairs(setup.config.actions) do
      local action, err = Action.__create(name, action_f())
      if err ~= nil then
        e = err
        return
      end
      if Action.__is_available(action) then
        table.insert(actions_table, action)
      end
    end
  end
  if temp_buf == nil or vim.fn.bufexists(temp_buf) ~= 1 then
    check()
  else
    vim.api.nvim_buf_call(temp_buf, check)
  end
  return actions_table, e
end

---Get an action identified by the provided name.
---
---@param name string: name of an action
---@param temp_buf number?: A temporary bufer from which to fetch the action
---@return Action?: action identified by the provided name
---@return string?: Error that occured while fetching the action
function setup.get_action(name, temp_buf)
  local action_f = setup.config.actions[name]
  if action_f == nil then
    return nil, "Action '" .. name .. "' does not exist!"
  end
  local a, e
  if temp_buf == nil or vim.fn.bufexists(temp_buf) ~= 1 then
    a, e = Action.__create(name, action_f())
  else
    vim.api.nvim_buf_call(temp_buf, function()
      a, e = Action.__create(name, action_f())
    end)
  end
  return a, e
end

return setup

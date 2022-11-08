local Log_config = require "actions.model.log_config"
local Action = require "actions.model.action"

---@class User_config
---@field actions table: A table of actions to add
---@field log table: vim.log.levels
---@field before_displaying_output function
local User_config = {
  log = Log_config.default(),
  actions = {},
  before_displaying_output = function()
    pcall(vim.cmd, "vsplit")
  end,
}
User_config.__index = User_config

---Create a default user config
---
---@return User_config
function User_config.default()
  local cfg = {}
  setmetatable(cfg, User_config)
  return cfg
end

---@param o table
---@return User_config
---@return string|nil: An error that occured while creating the config
function User_config.create(o)
  ---@type User_config
  local cfg = {}
  setmetatable(cfg, User_config)

  if type(o) ~= "table" then
    return cfg, "User config should be a table!"
  end
  for key, value in pairs(o) do
    if key == "log" then
      local log, e = Log_config.create(value)
      if e ~= nil then
        return cfg, e
      end
      cfg.log = log
    elseif key == "actions" then
      if type(value) ~= "table" then
        return cfg, "actions should be a table!"
      end
      local actions = {}
      for k, v in pairs(value) do
        local action, err = Action.create(k, v)
        if err ~= nil then
          return cfg, err
        end
        actions[action:get_name()] = action
      end
      cfg.actions = actions
    elseif key == "before_displaying_output" then
      if type(value) ~= "function" then
        return cfg, "before_displaying_output should be a function!"
      end
    else
      return cfg, "Invalid config field: " .. key
    end
  end
  return cfg, nil
end

return User_config

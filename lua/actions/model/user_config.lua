local Log_config = require "actions.model.log_config"
local Action = require "actions.model.action"

---@class User_config
local User_config = {
  log = Log_config.default(),
  ---A table of actions, with actions' names as keys
  actions = {},
  ---Function called before displaying the output buffer in the current window.
  ---@return nil
  ---@type function?
  before_displaying_output = function()
    pcall(vim.cmd, "vsplit")
  end,
  ---Function called after displaying the output buffer
  ---@param buf number?: The number of the output buffer
  ---@return nil
  ---@type function?
  after_displaying_output = function(buf)
    if vim.fn.bufexists(buf) ~= 1 then
      return
    end
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
      cfg.before_displaying_output = value
    elseif key == "after_displaying_output" then
      if type(value) ~= "function" then
        return cfg, "after_displaying_output should be a function!"
      end
      cfg.after_displaying_output = value
    else
      return cfg, "Invalid config field: " .. key
    end
  end
  return cfg, nil
end

---Merge the config with another config
---
---@param cfg User_config
function User_config:add(cfg)
  for k, v in pairs(cfg) do
    if k == "actions" then
      if self.actions == nil then
        self.actions = v
      else
        for k2, v2 in pairs(v) do
          self.actions[k2] = v2
        end
      end
    else
      self[k] = v
    end
  end
end

return User_config

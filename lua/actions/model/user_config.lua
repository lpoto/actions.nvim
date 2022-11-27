local Log_config = require "actions.model.log_config"
local Mappings_config = require "actions.model.mappings_config"

---@class User_config
---@field actions table: A table of Action objects
---@field before_displaying_output function
---@field log Log_config
---@field mapping Mappings_config:
---@see Mappings_config
---@see Log_config
---@see Action
local User_config = {
  log = Log_config.__default(),
  actions = {},
  mappings = Mappings_config.__default(),
}
User_config.__index = User_config

---Create a default user config
---
---@return User_config
function User_config.__default()
  local cfg = {}
  setmetatable(cfg, User_config)
  return cfg
end

---@param o table
---@return User_config
---@return string|nil: An error that occured while creating the config
function User_config.__create(o)
  ---@type User_config
  local cfg = {}
  setmetatable(cfg, User_config)

  if type(o) ~= "table" then
    return cfg, "User config should be a table!"
  end
  for key, value in pairs(o) do
    if key == "log" then
      local log, e = Log_config.__create(value)
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
        if type(k) ~= "string" or string.len(k) == 0 then
          return cfg, "Action should have a non-empty string name!"
        end
        if type(v) ~= "function" then
          return cfg, "Action '" .. k .. "'s config should be a function!"
        end
        actions[k] = v
      end
      cfg.actions = actions
    elseif key == "before_displaying_output" then
      if type(value) ~= "function" then
        return cfg, "before_displaying_output should be a function!"
      end
      cfg.before_displaying_output = value
    elseif key == "mappings" then
      local v, e = Mappings_config.__create(value)
      if e ~= nil then
        return cfg, e
      end
      cfg.mappings = v
    else
      return cfg, "Invalid config field: " .. key
    end
  end
  return cfg, nil
end

---Merge the two provided configs.
---The second is added to the first.
---
---@param o1 User_config
---@param o2 User_config
function User_config.__merge(o1, o2)
  for k, v in pairs(o2) do
    if k == "actions" then
      if o1.actions == nil then
        o1.actions = v
      else
        for k2, v2 in pairs(v) do
          o1.actions[k2] = v2
        end
      end
    else
      o2[k] = v
    end
  end
end

return User_config

local Actions_log_config = require "actions.model.log_config"
local Actions_mappings_config = require "actions.model.mappings_config"

---@tag actions.model.user_config
---@config {["name"] = "USER CONFIG"}

---@brief [[
---Actions_user_config is an object that represents a plugin configuration created
---by the user. The config's actions are functions returning |Action| objects, so 
---that they may be loaded when requested, which allows actions relative to
---the current context.
---@brief ]]

---@class Actions_user_config
---@field action table: A table of functions returning |Action| objects
---@field before_displaying_output function|nil: A function that recieves the output's buffer number and opens it's window
---@field log Actions_log_config: |Actions_log_config| for the plugin's logger
---@field mappings Actions_mappings_config: |Actions_mappings_config| for keymaps in the action's windows

---@type Actions_user_config
local Actions_user_config = {
  log = Actions_log_config.__default(),
  action = {},
  mappings = Actions_mappings_config.__default(),
}
Actions_user_config.__index = Actions_user_config

---Create a default user config
---
---@return Actions_user_config
function Actions_user_config.__default()
  local cfg = {}
  setmetatable(cfg, Actions_user_config)
  return cfg
end

---@param o table
---@return Actions_user_config
---@return string|nil: An error that occured while creating the config
function Actions_user_config.__create(o)
  ---@type Actions_user_config
  local cfg = {}
  setmetatable(cfg, Actions_user_config)

  if type(o) ~= "table" then
    return cfg, "User config should be a table!"
  end
  for key, value in pairs(o) do
    if key == "log" then
      local log, e = Actions_log_config.__create(value)
      if e ~= nil then
        return cfg, e
      end
      cfg.log = log
    elseif key == "action" or key == "actions" then
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
      cfg.action = actions
    elseif key == "before_displaying_output" then
      if type(value) ~= "function" then
        return cfg, "before_displaying_output should be a function!"
      end
      cfg.before_displaying_output = value
    elseif key == "mappings" then
      local v, e = Actions_mappings_config.__create(value)
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
---@param o1 Actions_user_config
---@param o2 Actions_user_config
function Actions_user_config.__merge(o1, o2)
  for k, v in pairs(o2) do
    if k == "action" or k == "actions" then
      if o1.action == nil then
        o1.action = v
      else
        for k2, v2 in pairs(v) do
          o1.action[k2] = v2
        end
      end
    else
      o2[k] = v
    end
  end
end

return Actions_user_config

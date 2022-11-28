---@tag actions.model.log_config
---@config {["name"] = "LOG CONFIG"}

---@brief [[
---Actions_log_config is an object that represents a configuration for the
---plugin's logger.
---@brief ]]

---@class Actions_log_config
---@field level number: a vim.log.levels value (default: INFO).
---@field prefix string: Prefix added before logs (default: 'Actions.nvim').
---@field silent boolean: Whether the logging is disabled (default: false).

---@type Actions_log_config
local Actions_log_config = {
  level = vim.log.levels.INFO,
  prefix = "Actions.nvim",
  silent = false,
}
Actions_log_config.__index = Actions_log_config

---Create a default log config
---
---@return Actions_log_config
function Actions_log_config.__default()
  ---@type Actions_log_config
  local cfg = {}
  setmetatable(cfg, Actions_log_config)
  return cfg
end

---Create the log config from a table
---
---@param o table: Table from which to parse the config
---@return Actions_log_config
---@return string|nil: An error that occured while creating the config
function Actions_log_config.__create(o)
  ---@type Actions_log_config
  local cfg = {}
  setmetatable(cfg, Actions_log_config)

  if type(o) ~= "table" then
    return cfg, "log config should be a table!"
  end

  for key, value in pairs(o) do
    if key == "level" then
      if type(value) ~= "number" then
        return cfg, "log.level should be a number!"
      end
      cfg.level = value
    elseif key == "prefix" then
      if type(value) ~= "string" then
        return cfg, "log.prefix should be a string!"
      end
      cfg.prefix = value
    elseif key == "silent" then
      if type(value) ~= "boolean" then
        return cfg, "log.silent should be a boolean!"
      end
      cfg.silent = value
    else
      return cfg, "Invalid log config field: " .. key
    end
  end
  return cfg, nil
end

return Actions_log_config

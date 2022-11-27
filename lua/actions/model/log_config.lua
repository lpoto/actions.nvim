---@class Log_config
---@field level number: a vim.log.levels value (default: INFO)
---@field prefix string: Prefix added before logs (default: 'Actions.nvim')
---@field silent boolean: Whether the logging is disabled (default: false)
local Log_config = {
  level = vim.log.levels.INFO,
  prefix = "Actions.nvim",
  silent = false,
}
Log_config.__index = Log_config

---Create a default log config
---
---@return Log_config
function Log_config.__default()
  ---@type Log_config
  local cfg = {}
  setmetatable(cfg, Log_config)
  return cfg
end

---Create the log config from a table
---
---@param o table: Table from which to parse the config
---@return Log_config
---@return string|nil: An error that occured while creating the config
function Log_config.__create(o)
  ---@type Log_config
  local cfg = {}
  setmetatable(cfg, Log_config)

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

return Log_config

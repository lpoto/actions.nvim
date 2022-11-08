local Log_config = require "actions.model.log_config"

local config = Log_config.default()

local log = {}

---Notify the provided text with debug level.
---@param txt string: Text to log
function log.debug(txt)
  if config.silent == true or config.level > vim.log.levels.DEBUG then
    return
  end
  vim.notify(config.prefix .. ": " .. txt, vim.log.levels.DEBUG)
end

---Notify the provided text with info level.
---@param txt string: Text to log
function log.info(txt)
  if config.silent == true or config.level > vim.log.levels.INFO then
    return
  end
  vim.notify(config.prefix .. ": " .. txt, vim.log.levels.INFO)
end

---Notify the provided text with warn level.
---@param txt string: Text to log
function log.warn(txt)
  if config.silent == true or config.level > vim.log.levels.WARN then
    return
  end
  vim.notify(config.prefix .. ": " .. txt, vim.log.levels.WARN)
end

---Notify the provided text with error level.
---@param txt string: Text to log
function log.error(txt)
  if config.silent == true or config.level > vim.log.levels.ERROR then
    return
  end
  vim.notify(config.prefix .. ": " .. txt, vim.log.levels.ERROR)
end

---@param log_config Log_config
function log.setup(log_config)
  config = log_config
end

return log

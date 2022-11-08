local setup = require "actions.setup"

---@param txt string: Text to log
---@param level number: A vim.log.levels value
local function notify(txt, level)
  if setup.config.log.silent == true or setup.config.log.level > level then
    return
  end
  vim.notify(setup.config.log.prefix .. ": " .. txt, level)
end

local log = {}

---Notify the provided text with debug level.
---@param txt string: Text to log
function log.debug(txt)
  notify(txt, vim.log.levels.DEBUG)
end

---Notify the provided text with info level.
---@param txt string: Text to log
function log.info(txt)
  notify(txt, vim.log.levels.INFO)
end

---Notify the provided text with warn level.
---@param txt string: Text to log
function log.warn(txt)
  notify(txt, vim.log.levels.WARN)
end

---Notify the provided text with error level.
---@param txt string: Text to log
function log.error(txt)
  notify(txt, vim.log.levels.ERROR)
end

return log

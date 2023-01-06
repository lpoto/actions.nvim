local setup = require "actions.setup"

---@param txt string: Text to log
---@param level number: A vim.log.levels value
---@param title string|nil
local function notify(txt, level, title)
  if setup.config.log_level > level then
    return
  end

  title = title or "Actions.nvim"

  vim.notify(txt, level, {
    title = title,
  })
end

local log = {}

---Notify the provided text with debug level.
---@param txt string: Text to log
---@param title string|nil
function log.debug(txt, title)
  notify(txt, vim.log.levels.DEBUG, title)
end

---Notify the provided text with info level.
---@param txt string: Text to log
---@param title string|nil
function log.info(txt, title)
  notify(txt, vim.log.levels.INFO, title)
end

---Notify the provided text with warn level.
---@param txt string: Text to log
---@param title string|nil
function log.warn(txt, title)
  notify(txt, vim.log.levels.WARN, title)
end

---Notify the provided text with error level.
---@param txt string: Text to log
---@param title string|nil
function log.error(txt, title)
  notify(txt, vim.log.levels.ERROR, title)
end

return log

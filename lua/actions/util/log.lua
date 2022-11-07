local log = {}

---Level of the actions.nvim logger
---@type number
log.level = vim.log.levels.INFO

---Prefix added to text when logging.
---@type string
log.prefix = "Actions.nvim"

---When set to true, actions.nvim logging is disabled.
---@type boolean
log.silent = false

---Notify the provided text with debug level.
---@param txt string: Text to log
function log.debug(txt)
  if log.silent == true or log.level > vim.log.levels.DEBUG then
    return
  end
  vim.notify(log.prefix .. ": " .. txt, vim.log.levels.DEBUG)
end

---Notify the provided text with info level.
---@param txt string: Text to log
function log.info(txt)
  if log.silent == true or log.level > vim.log.levels.INFO then
    return
  end
  vim.notify(log.prefix .. ": " .. txt, vim.log.levels.INFO)
end

---Notify the provided text with warn level.
---@param txt string: Text to log
function log.warn(txt)
  if log.silent == true or log.level > vim.log.levels.WARN then
    return
  end
  vim.notify(log.prefix .. ": " .. txt, vim.log.levels.WARN)
end

---Notify the provided text with error level.
---@param txt string: Text to log
function log.error(txt)
  if log.silent == true or log.level > vim.log.levels.ERROR then
    return
  end
  vim.notify(log.prefix .. ": " .. txt, vim.log.levels.ERROR)
end

return log

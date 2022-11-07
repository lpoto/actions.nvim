local log = require "actions.util.log"

local executor = {}

---Run the action identified by the provided name
---
---@param name string: name of the action
---@return boolean: true on successful start, false on error
function executor.start(name)
  -- TODO
  log.info("Starting action: " .. name)
  return false
end

---Kill the action identified by the provided name
---
---@param name string: name of the action
---@return boolean: true on successful kill, false on error
function executor.kill(name)
  -- TODO
  log.info("Killing action: " .. name)
  return false
end

return executor

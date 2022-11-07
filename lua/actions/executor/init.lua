local log = require "actions.util.log"
local setup = require "actions.setup"

---A table of running actions with
---action names for keys and job id's for
---values.
---
---@type table
local running_actions = {}

local executor = {}

---Returns true if the actions identified
---by the provided name is running, false otherwise.
---
---@param name string: name of an action
---@return boolean
function executor.is_running(name)
  return running_actions[name] ~= nil
end

---Run the action identified by the provided name
---
---@param name string: name of the action
---@return boolean: whether the action was started successfully
function executor.start(name)
  ---@type Action|nil
  local action = setup.get_action(name)
  if action == nil then
    return false
  end
  if executor.is_running(action.name) == true then
    log.warn("Action '" .. name .. "' is already running!")
    return false
  end
  running_actions[name] = 0
  return true
end

---Kill the action identified by the provided name
---
---@param name string: name of the action
---@return boolean: whether the action has been successfully killed
function executor.kill(name)
  if running_actions[name] == nil then
    return false
  end
  pcall(vim.fn.jobstop, running_actions[name])
  running_actions[name] = nil
  return true
end

return executor

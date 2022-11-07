local log = require "actions.util.log"
local setup = require "actions.setup"
local run = require "actions.executor.run_action"
local action_output_window = require "actions.window.action_output"

MAX_RUNNING_JOBS = 10

local executor = {}

---Returns true if the actions identified
---by the provided name is running, false otherwise.
---
---@param name string: name of an action
---@return boolean
function executor.is_running(name)
  return run.get_running_action_buffer(name) ~= nil
end

---Run the action identified by the provided name
---
---@param name string: name of the action
---@param prev_buf number?: number of the buffer from
---which the action is executed
---@param on_exit function: function called when the action exits.
---@return boolean: whether the action was started successfully
function executor.start(name, prev_buf, on_exit)
  ---@type Action|nil
  local action = setup.get_action(name)
  if action == nil then
    log.warn("Action '" .. name .. "' does not exist!!")
    return false
  end
  if executor.is_running(action.name) == true then
    log.warn("Action '" .. name .. "' is already running!")
    return false
  end
  if run.get_running_actions_count() >= MAX_RUNNING_JOBS then
    log.warn("Can only run " .. MAX_RUNNING_JOBS .. " actions at once!")
    return false
  end
  if run.run(action, prev_buf, on_exit) == true then
    if action_output_window.last_oppened == nil then
      action_output_window.last_oppened = name
    end
    return true
  end
  return false
end

---Kill the action identified by the provided name
---
---@param name string: name of the action
---@param callback function:  function called after killing
---@return boolean: whether the action has been successfully killed
function executor.kill(name, callback)
  ---@type Action|nil
  local action = setup.get_action(name)
  if action == nil then
    log.warn("Action '" .. name .. "' does not exist!!")
    return false
  end
  return run.stop(action, callback)
end

return executor

local log = require "actions.util.log"
local setup = require "actions.setup"
local action_window = require "actions.window.running_action"

---A table of running actions with
---action names for keys and tables for
---values. The table values contains keys
---"job" and "buf".
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
function executor.start(name)
  ---@type Action|nil
  local action = setup.get_action(name)
  if action == nil then
    return
  end
  if executor.is_running(action.name) == true then
    if
      action_window.open(action.name, running_actions[action.name]["buf"])
      == -1
    then
      running_actions[action.name] = nil
    else
      log.warn("Action '" .. name .. "' is already running!")
      return
    end
  end
  local buf = action_window.open(action.name, vim.fn.bufnr())
end

---Kill the action identified by the provided name
---
---@param name string: name of the action
function executor.kill(name)
  log.info("Killing action: " .. name)
end

---Kill the action identified by the provided name
---and delete its buffer
---
---@param name string: name of the action
function executor.kill_and_delete_buffer(name)
  pcall(executor.kill, name)
  log.info("Killing action: " .. name)
end

return executor

---A Step represents a single job out of a sequence
---of jobs belonging to an Action:
---
---@class Step
---@field name string
---@field env table|nil
---@field clear_env boolean|nil
---@field cwd string|nil
---@field cmd string
local Step = {}
Step.__index = Step

---Create a step from a table
---
---@param o table
---@return Step
---@return string?: An error occured while creating a Step.
function Step.create(o)
  ---@type Step
  local step = {}
  setmetatable(step, Step)

  if type(o) ~= "table" then
    return step, "A Step should be a table!"
  end

  --NOTE: verify step's fields,
  --if any errors occur, stop with the creation and return
  --the error string.

  if o.name == nil or type(o.name) ~= "string" or string.len(o.name) == 0 then
    return step, "A step should have a non-empty string name!"
  end
  step.name = o.name

  if o.cwd ~= nil and type(o.cwd) ~= "string" then
    return a, "Step '" .. step.name .. "'s cwd should be a string!"
  end
  step.cwd = o.cwd

  if o.env ~= nil and type(o.env) ~= "table" then
    return a, "Step '" .. step.name .. "'s env should be a table!"
  end
  step.env = o.env

  if o.clear_env ~= nil and type(o.clear_env) ~= "boolean" then
    return a, "Step '" .. step.name .. "'s clear_env should be a boolean!"
  end

  step.clear_env = o.clear_env

  if o.cmd == nil or type(o.cmd) ~= "string" then
    return a, "Step '" .. step.name .. "' should have a string cmd field!"
  end
  step.cmd = o.cmd

  return step
end

return Step

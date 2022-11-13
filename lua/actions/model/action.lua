---An Action represents a sequence
---of jobs to be executed synchronously.
---
---@class Action
---@field name string
---@field env table|nil
---@field clear_env boolean|nil
---@field steps table
---@field cwd string|nil
---@field filetypes table|nil
---@field patterns table|nil
local Action = {}
Action.__index = Action

---Create an action from a table
---
---@param name string: The name of the action
---@param o table: Action's fields
---@return Action
---@return string?: An error that occured when creating an Action
function Action.create(name, o)
  ---@type Action
  local a = {}
  setmetatable(a, Action)

  --NOTE: verify action's fields,
  --if any errors occur, stop with the creation and return
  --the error string.

  if type(name) ~= "string" then
    return a, "Action's 'name' should be a string!"
  end
  if type(o) ~= "table" then
    return a, "Action '" .. name .. "' should be a table!"
  end
  if string.len(name) > 35 then
    return a,
      "Action '" .. name .. "'s name should not be longer than 35 characters!"
  end
  a.name = name
  if o.filetypes ~= nil and type(o.filetypes) ~= "table" then
    return a, "Action '" .. name .. "'s filetypes should be a table!"
  end
  a.filetypes = o.filetypes
  if o.patterns ~= nil and type(o.patterns) ~= "table" then
    return a, "Action '" .. name .. "'s filetypes should be a table!"
  end
  a.patterns = o.patterns
  if o.cwd ~= nil and type(o.cwd) ~= "string" then
    return a, "Action '" .. name .. "'s cwd should be a string!"
  end
  a.cwd = o.cwd
  if o.env ~= nil and type(o.env) ~= "table" then
    return a, "Action '" .. name .. "'s env should be a table!"
  end
  a.env = o.env
  if o.clear_env ~= nil and type(o.clear_env) ~= "boolean" then
    return a, "Action '" .. name .. "'s clear_env should be a boolean!"
  end
  a.clear_env = o.clear_env
  if o.steps == nil or type(o.steps) == "table" and next(o.steps) == nil then
    return a, "Action '" .. name .. "' should have at least 1 step!"
  end
  if type(o.steps) ~= "table" then
    return a, "Action '" .. name .. "'s steps should be a table!"
  end

  --NOTE: verify action's steps
  for _, s in ipairs(o.steps) do
    if type(s) ~= "string" then
      return a, "Action '" .. name .. "'s steps should be strings!"
    end
  end
  a.steps = o.steps
  return a
end

---Checks whether the action is available. It is available when
---the current filename matches it's patterns and the current filetype
---matches it's filetypes.
---
---@return boolean
function Action:is_available()
  local filetypes = self.filetypes
  local current_filetype = vim.o["filetype"]
  local continue = filetypes == nil or next(filetypes) == nil
  if filetypes ~= nil then
    for _, ft in ipairs(filetypes) do
      if ft == current_filetype then
        continue = true
        break
      end
    end
  end
  if continue == false then
    return false
  end
  local patterns = self.patterns
  if patterns == nil or next(patterns) == nil then
    return true
  end
  local filename = vim.fn.expand "%:p"
  for _, p in ipairs(patterns) do
    if string.find(filename, p) ~= nil then
      return true
    end
  end
  return false
end

return Action

local Step = require "actions.model.step"

---An Action represents a sequence
---of jobs to be executed synchronously.
---
---@class Action
---@field name string
---@field env table|function|nil
---@field clear_env boolean|function|nil
---@field steps table
---@field cwd string|function|nil
---@field filetypes table|function|nil
---@field patterns table|function|nil
local Action = {}
Action.__index = Action

---Create an action from a table
---
---@param name string: The name of the action
---@param o table: Action's fields
---@return Action
---@return string|nil: An error that occured when creating an Action
function Action.create(name, o)
  ---@type Action
  local a = {}
  setmetatable(a, Action)
  if type(name) ~= "string" then
    return a, "Action's 'name' should be a string!"
  end
  if type(o) ~= "table" then
    return a, "Action '" .. name .. "' should be a table!"
  end
  if string.len(name) > 35 then
    return a,
      "Action '" .. name .. "' should not be longer than 35 characters!"
  end
  a.name = name
  a.filetypes = o.filetypes
  a.cwd = o.cwd
  a.patterns = o.patterns
  a.env = o.env
  a.clear_env = o.clear_env
  if o.steps ~= nil and type(o.steps) == "table" then
    ---@type table: a table of steps
    local steps = {}
    for _, s in ipairs(o.steps) do
      ---@type Step: a step of the action
      local step, e = Step.create(s)
      if e ~= nil then
        return a, e
      end
      table.insert(steps, step)
    end
    a.steps = steps
  end
  if a.steps == nil or next(a.steps) == nil then
    return a, "Action '" .. name .. "' should have at least one step!"
  end
  return a
end

---Get the action's name.
---
---@return string
function Action:get_name()
  return self.name
end

---Get the action's current working directory. When the actions is run,
---it is run in this directory.
---
---@return string|nil: A path to a valid directory
---@return string|nil: An error that occured when fetching action's cwd
function Action:get_cwd()
  local cwd = self.cwd
  if cwd == nil then
    return nil, nil
  end
  if type(cwd) == "function" then
    cwd = cwd()
  end
  if type(cwd) ~= "string" then
    return nil,
      "Action '"
        .. self.name
        .. "': 'cwd' should be a string or a function returning a string!"
  end
  return cwd, nil
end

---Get the action's environment variables. They are in a form of
---a table with keys as variable names, and values as their values.
---
---@return table: A table of environment variables
---@return string|nil: An error that occured when fetching action's env
function Action:get_env()
  local env = self.env
  if env == nil then
    return {}, nil
  end
  if type(env) == "function" then
    env = env()
  end
  if type(env) ~= "table" then
    return {},
      "Action '"
        .. self.name
        .. "': 'env' should be a table or a function returning a table!"
  end
  return env, nil
end

---Get the action's steps. When the actions is run, these steps
---are run as separate jobs one after another.
---Each step may override some of the action's options, just for
---the duration of that step.
---
---@return table: A non-empty table of the action's steps
function Action:get_steps()
  return self.steps
end

---Get the action's clear_env option. When this is true, all
---other variables, not in the action's env table, are cleared when
---the action is run.
---
---@return boolean
---@return string|nil: An error that occured when fetching the option
function Action:get_clear_env()
  local clear_env = self.clear_env
  if clear_env == nil then
    return false, nil
  end
  if type(clear_env) == "function" then
    clear_env = clear_env()
  end
  if type(clear_env) ~= "boolean" then
    return false,
      "Action '"
        .. self.name
        .. "': 'clear_env' should be a boolean or a function returning a boolean!"
  end
  return clear_env, nil
end

---Get the action's filetypes.
---The action is available only in the files with the matching filetype.
---
---@return table: A table of filetypes.
---@return string|nil: An error that occured when fetching the filetypes.
function Action:get_filetypes()
  local ft = self.filetypes
  if ft == nil then
    return {}, nil
  end
  if type(ft) == "function" then
    ft = ft()
  end
  if type(ft) ~= "table" then
    return {},
      "Action '"
        .. self.name
        .. "': 'filetypes' should be a table or a function returning a table!"
  end
  local ft2 = {}
  for _, v in ipairs(ft) do
    if type(v) == "function" then
      v = v()
    end
    if type(v) ~= "string" then
      return {},
        "Action '"
          .. self.name
          .. "': Step's 'filetype' should be a string or a function returning a string!"
    end
    table.insert(ft2, v)
  end
  return ft2, nil
end

---Get the action's patterns.
---The action is available only in the files with names matching any
---of the patterns.
---
---@return table: A table of patterns.
---@return string|nil: An error that occured when fetching the patterns.
function Action:get_patterns()
  local pt = self.patterns
  if pt == nil then
    return {}, nil
  end
  if type(pt) == "function" then
    pt = pt()
  end
  if type(pt) ~= "table" then
    return {},
      "Action '"
        .. self.name
        .. "': 'patterns' should be a table or a function returning a table!"
  end
  local pt2 = {}
  for _, v in ipairs(pt) do
    if type(v) == "function" then
      v = v()
    end
    if type(v) ~= "string" then
      return {},
        "Step's 'pattern' should be a string or a function returning a string!"
    end
    table.insert(pt2, v)
  end
  return pt2, nil
end

---Checks whether the action is available. It is available when
---the current filename matches it's patterns and the current filetype
---matches it's filetypes.
---
---@return boolean
function Action:is_available()
  local filetypes, err = self:get_filetypes()
  if err ~= nil then
    return false
  end
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
  local patterns, err2 = self:get_patterns()
  if err2 ~= nil then
    return false
  end
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

---Returns the path to the output file for this action.
function Action:get_output_path()
  return vim.fn.stdpath "data"
    .. "/actions_output/"
    .. self:get_name()
    .. ".out"
end

---Create a step from a table
---
---@param o table
---@returns Step
---@returns string|nil: An error occured while creating a Step.
function Step.create(o)
  ---@type Step
  local step = {}
  setmetatable(step, Step)
  if type(o) ~= "table" then
    return step, "A Step should be a table!"
  end
  step.name = o.name
  step.env = o.env
  step.clear_env = o.clear_env
  step.cwd = o.cwd
  step.exe = o.exe
  step.args = o.args
  step.string_exe = o.string_exe
  return step
end

return Action

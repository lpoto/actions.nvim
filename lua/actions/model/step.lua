---A Step represents a single job out of a sequence
---of jobs belonging to an Action:
---
---@class Step
---@field name string
---@field env table|function|nil
---@field clear_env boolean|function|nil
---@field cwd string|function|nil
---@field exe string|function|nil
---@field args table|function|nil
---@field string_exe string|function|nil
local Step = {}
Step.__index = Step

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
  if type(o.name) ~= "string" then
    return step, "A Step's 'name' should be a string!"
  end
  if type(o.exe) ~= "string" then
    return step, "A Step's 'exe' should be a string!"
  end
  step.env = o.env
  step.clear_env = o.clear_env
  step.cwd = o.cwd
  step.exe = o.exe
  step.args = o.args
  step.string_exe = o.string_exe
  return step
end

---Get the step's name.
---
---@return string
function Step:get_name()
  return self.name
end

---Get the step's current working directory. When the step is run,
---it is run in this directory. This overrides the action's cwd for
---this step only.
---
---@return string|nil: A path to a valid directory
---@return string|nil: An error that occured when fetching step's cwd
function Step:get_cwd()
  local cwd = self.cwd
  if cwd == nil then
    return nil, nil
  end
  if type(cwd) == "function" then
    cwd = cwd()
  end
  if type(cwd) ~= "string" then
    return nil,
      "Step's 'cwd' should be a string or a function returning a string!"
  end
  local ok, e = vim.fs.dir(cwd)
  if ok == false or e == nil then
    return nil, "Step's 'cwd' should be a path to a valid directory!"
  end
  return cwd, nil
end

---Get the step's environment variables. They are in a form of
---a table with keys as variable names, and values as their values.
---The are added to the action's env, unless the step has clear_env set
---to true, then only these are kept.
---
---@return table: A table of environment variables
---@return string|nil: An error that occured when fetching step's env
function Step:get_env()
  local env = self.env
  if env == nil then
    return {}, nil
  end
  if type(env) == "function" then
    env = env()
  end
  if type(env) ~= "table" then
    return {},
      "Step's 'env' should be a table or a function returning a table!"
  end
  return env, nil
end

---Get the step's clear_env option. When this is true, all
---other variables, not in the step's env table, are cleared when
---the action is run. This overrides the actin's clear_env for this
---step only.
---
---@return boolean|nil
---@return string|nil: An error that occured when fetching the option
function Step:get_clear_env()
  local clear_env = self.clear_env
  if clear_env == nil then
    return nil, nil
  end
  if type(clear_env) == "function" then
    clear_env = clear_env()
  end
  if type(clear_env) ~= "boolean" then
    return nil,
      "Step's 'clear_env' should be a boolean or a function returning a boolean!"
  end
  return clear_env, nil
end

---Get the step's exe.
---
---@return string
---@return string|nil: An error that occured when fetching the exe
function Step:get_exe()
  local exe = self.exe
  if exe == nil then
    return "", nil
  end
  if type(exe) == "function" then
    exe = exe()
  end
  if type(exe) ~= "string" then
    return "",
      "Step's 'exe' should be a string or a function returning a string!"
  end
  return exe, nil
end

---Get the step's args. These are added as arguments to the exe
---field when running the action.
---
---@return table
---@return string|nil: An error that occured when fetching the args.
function Step:get_args()
  local args = self.args
  if args == nil then
    return {}, nil
  end
  if type(args) == "function" then
    args = args()
  end
  if type(args) ~= "table" then
    return {},
      "Step's 'args' should be a table or a function returning a table!"
  end
  local args2 = {}
  for _, v in ipairs(args) do
    if type(v) == "function" then
      v = v()
    end
    if type(v) ~= "string" then
      return {},
        "Step's 'arg' should be a string or a function returning a string!"
    end
    table.insert(args2, v)
  end
  return args2, nil
end

return Step

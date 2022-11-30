local enum = require "actions.enum"

---@tag actions.model.action
---@config {["name"] = "ACTION"}

---@brief [[
---Action is an object that represents a sequence of commands
---and the environment in which they will be run.
---Example action in the |User_config| table:
---<code>
---  {
---    cwd = "/temp",
---    env = {"HELLO_WORLD" = "Hello World"},
---    clear_env = false,
---    filetypes = {"lua", "bash"},
---    patterns = {".*.lua", ".*.sh"},
---    steps = {
---      "echo 'Hello world!'",
---      {"echo", "$HELLO_WORLD", "again!"}
---    }
---  }
---</code>
---@brief ]]

---@class Action
---@field name string: This is taken from the key in the |User_config| table.
---@field env table|nil: A table of environment variables.
---@field clear_env boolean: Whether env defined the whole environment and other environment variables should be deleted (default: false).
---@field steps table: A table of commands (strings or tables) to be executed in order.
---@field cwd string|nil: The working directory of the action.
---@field filetypes table|nil: Filetypes in which the action is available.
---@field patterns table|nil: Action is available ony in files with names that match a pattern in this table of lua patterns.

---@type Action
local Action = {}
Action.__index = Action

---Create an action from a table
---
---@param o table: Action's fields.
---@param name string: Action's name.
---@return Action
---@return string?: An error that occured when creating an Action.
function Action.__create(name, o)
  ---@type Action
  local a = {}
  setmetatable(a, Action)

  --NOTE: verify action's fields,
  --if any errors occur, stop with the creation and return
  --the error string.

  if name == nil or type(name) ~= "string" then
    return a, "Action's 'name' should be a string!"
  end
  if type(o) ~= "table" then
    return a, "Action '" .. name .. "' should be a table!"
  end
  if string.len(name) > enum.FLOATING_WINDOW_WIDTH - 15 then
    return a,
      "Action '" .. name .. "'s name should not be longer than 35 chars!"
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

  local steps = {}
  --NOTE: verify action's steps
  for _, s in ipairs(o.steps) do
    if type(s) == "table" then
      local s2 = ""
      for _, v in ipairs(s) do
        if type(v) ~= "string" then
          return a,
            "Action '"
              .. name
              .. "'s steps should be strings or tables of strings!"
        end
        if string.len(s2) == 0 then
          s2 = v
        else
          s2 = s2 .. " " .. v
        end
      end
      s = s2
    end
    if type(s) ~= "string" then
      return a,
        "Action '" .. name .. "'s steps should be strings or tables of string!"
    end
    table.insert(steps, s)
  end
  a.steps = steps
  return a
end

---Checks whether the action is available. It is available when
---the current filename matches it's patterns and the current filetype
---matches it's filetypes.
---
---@param a Action
---@return boolean
function Action.__is_available(a)
  local filetypes = a.filetypes
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
  local patterns = a.patterns
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

local log = require "actions.log"

local create_output_file

---A table with actions' names as keys
---and their job ids as values
---
---@type table
local running_actions = {}

local run = {}

---Returns the buffer name for the running action identified
---by the provided name. Returns nil if the action is
---not running.
---
---@param name string: name of an action
---@return boolean
function run.is_running(name)
  if running_actions[name] == nil then
    return false
  end
  return true
end

---Returns the number of currently running actions.
---
---@return number
function run.get_running_actions_count()
  local i = 0
  for _, _ in pairs(running_actions) do
    i = i + 1
  end
  return i
end

---@param action Action: action to be run
---@param on_exit function: A function called when a started action exits.
---@return boolean: whether the actions started successfully
---TODO: this function should be refactored, split into multiple smaller functions.
function run.run(action, on_exit)
  ---@type string: Path to the output file
  local path = action:get_output_path()

  --NOTE: make sure the output directory for the
  --output file exists
  if create_output_file(path) == false then
    return false
  end

  ---@type table
  local original_steps = action.steps
  ---@type table
  local env = {}
  if action.env ~= nil then
    env = action.env
  end
  ---@type boolean|nil
  local clear_env = action.clear_env
  ---@type string|nil
  local cwd = action.cwd

  ---@type table: a copy of original steps
  local steps_copy = {}
  for _, step in ipairs(original_steps) do
    table.insert(steps_copy, step)
  end

  run.write_output(path, { "> ACTION [" .. action.name .. "] START" }, true)

  ---@param steps table
  ---@return boolean
  local function run_steps_recursively(steps)
    if next(steps) == nil then
      run.clean(action, true, on_exit, -1)
      return false
    end
    ---@type Step: a step to be run as a job
    local step = table.remove(steps, 1)

    ---@type string
    local step_name = step.name
    ---@type string: executable of the job
    local exe = step.exe
    ---@type table|nil: arguments added to the exe
    local args = step.args
    ---@type string|nil: step's working directory
    local step_cwd = step.cwd
    ---@type table: step's env variables
    local step_env = {}
    if step.env ~= nil then
      step_env = step.env
    end
    ---@type boolean|nil: step's working directory
    local step_clear_env = step.clear_env

    --NOTE: primarily use step's fields, they override the
    --action's fields. Use action's fields for those fields
    --that are undefined in the step.

    log.debug("Running step: " .. step_name)

    ---@type string|table: cmd sent to the job
    local cmd = exe
    if args ~= nil and next(args) ~= nil then
      cmd = { exe }
      for _, arg in ipairs(args) do
        table.insert(cmd, arg)
      end
    end

    run.write_output(path, { "", "> STEP [" .. step_name .. "]", "", "" })

    if step_clear_env ~= true then
      local env3 = {}
      for k, v in pairs(env) do
        env3[k] = v
      end
      for k, v in pairs(step_env) do
        env3[k] = v
      end
      step_env = env3
    end
    if step_clear_env == nil then
      step_clear_env = clear_env
    end

    if step_cwd == nil then
      step_cwd = cwd
    end

    ---@type table|nil
    local step_env2 = nil

    if step_env ~= nil and next(step_env) ~= nil then
      step_env2 = step_env
    end
    local ok, started_job = pcall(vim.fn.jobstart, cmd, {
      detach = false,
      env = step_env2,
      clear_env = step_clear_env,
      cwd = step_cwd,
      on_stderr = function(_, d)
        local s = {}
        if type(d) == "string" then
          s = { d }
        elseif type(d) == "table" then
          for _, v in ipairs(d) do
            if string.len(v) > 0 then
              s = d
              break
            end
          end
        end
        if next(s) ~= nil and run.write_output(path, s) == false then
          run.clean(action, true, on_exit, -1)
        end
      end,
      on_stdout = function(_, d)
        local s = {}
        if type(d) == "string" then
          s = { d }
        elseif type(d) == "table" then
          for _, v in ipairs(d) do
            if string.len(v) > 0 then
              s = d
              break
            end
          end
        end
        if next(s) ~= nil and run.write_output(path, s) == false then
          run.clean(action, true, on_exit, -1)
        end
      end,
      on_exit = function(_, code)
        local ok_code = code == nil or (type(code) == "number") and code == 0
        if ok_code == false then
          run.write_output(path, {
            "> ACTION ["
              .. action.name
              .. "] "
              .. "exited with code: "
              .. code,
          })
          run.clean(action, true, on_exit, code)
          return
        end
        if next(steps) ~= nil then
          return run_steps_recursively(steps)
        end
        run.write_output(
          path,
          { "", "> ACTION [" .. action.name .. "] SUCCESS" }
        )
        run.clean(action, true, on_exit, code)
      end,
    })
    if ok == true then
      running_actions[action.name] = started_job
      return true
    end
    log.warn(started_job)
    run.clean(action, true, on_exit, -1)
    return false
  end

  return run_steps_recursively(steps_copy)
end

---Kills the provided action and saves the output from
---the buffer to the file in neovim's log directory.
---Deletes the output buffer.
---
---@param action Action
---@param clean? boolean: Whether to remove action from running_actions
---@param callback function?: Function to call after killing
---@param exit_code number?: Action's exit code
---@return boolean: whether successfully killed
function run.clean(action, clean, callback, exit_code)
  if running_actions[action.name] == nil then
    return false
  end
  local job = running_actions[action.name]
  pcall(vim.fn.jobstop, job)
  if clean == true then
    running_actions[action.name] = nil
  end
  if callback ~= nil then
    pcall(callback, exit_code)
  end
  return true
end

---Stop a running action
---
---@param action Action: Action to be stopped
---@param callback function?: Function to be called on successful stop
function run.stop(action, callback)
  if running_actions[action.name] == nil then
    return false
  end
  local job = running_actions[action.name]
  pcall(vim.fn.jobstop, job)
  if callback ~= nil then
    pcall(callback)
  end
  return true
end

---Writes provided text to the action's
---output file.
---
---@param path string: Path to the the output file
---@param lines table: output to write
---@param first boolean?: whether this is the first output to the buffer
---@return boolean: successful write
function run.write_output(path, lines, first)
  local ok, e
  if first then
    ok, e = pcall(vim.fn.writefile, lines, path, "S")
  else
    ok, e = pcall(vim.fn.writefile, lines, path, "aS")
  end
  if ok == false then
    log.warn(e)
  end
  if e == -1 then
    return false
  end

  return true
end

---Check if the output file exists, if it does not, create it with
---all its parent directories.
---
---@param output_file_path string: Path to the output file
---@return boolean: Whether the file exists, or was successfully created.
create_output_file = function(output_file_path)
  --NOTE: check if the provided file exists
  local ok, v = pcall(vim.fn.filereadable, output_file_path)
  if ok == false then
    log.warn(v)
    return false
  end
  if v == 1 then
    --NOTE: file exists
    ok, v = pcall(vim.fn.filewritable, output_file_path)
    if v ~= 1 then
      --NOTE: Check whether the file is writable
      log.warn("File '" .. output_file_path .. "' is not writable!")
      return false
    end
    return true
  end
  --NOTE: the file does not exist, first check
  --if it's parent directory exists
  local dirname
  ok, dirname = pcall(vim.fs.dirname, output_file_path)
  if ok == false then
    log.warn(dirname)
    return false
  end
  ok, v = pcall(vim.fs.dir, dirname)
  if ok == false then
    log.warn(v)
    return false
  end
  --NOTE: try to create the parent directory with
  --all it's subdirectories in the path
  --NOTE: this will silently exit if it already exists
  ok, v = pcall(vim.fn.mkdir, dirname, "p")
  if ok == false then
    log.warn(v)
    return false
  end
  if v ~= 1 then
    return false
  end
  --NOTE: now try to create the missing file
  ok, v = pcall(io.open, output_file_path, "w")
  if ok == false and type(v) == "string" then
    log.warn(v)
    return false
  end
  if v == nil then
    return false
  end
  pcall(v.close, v)
  return true
end

return run

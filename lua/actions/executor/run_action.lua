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
---@param prev_buf number?: parent buffer from which the action has been started
---@param on_exit function: A function called when a started action exits.
---@return boolean: whether the actions started successfully
---TODO: this function should be refactored, split into multiple smaller functions.
function run.run(action, prev_buf, on_exit)
  ---@type string: Path to the output file
  local path = action:get_output_path()

  --NOTE: make sure the output directory for the
  --output file exists
  if create_output_file(path) == false then
    return false
  end

  ---@type table
  local original_steps
  ---@type table
  local env
  ---@type boolean|nil
  local clear_env
  ---@type string|nil
  local cwd
  ---@type string|nil
  local err

  ---fetch the action's fields
  local function fetch_action_data()
    original_steps = action:get_steps()
    env, err = action:get_env()
    if err ~= nil then
      log.warn(err)
    end

    ---are cleared.
    clear_env, err = action:get_clear_env()
    if err ~= nil then
      log.warn(err)
    end

    ---may be overriden by step's cwd
    cwd, err = action:get_cwd()
    if err ~= nil then
      log.warn(err)
    end
  end

  if prev_buf ~= nil and vim.fn.bufexists(prev_buf) then
    --NOTE: fetch action data from the buffer from which the action
    --has been called

    vim.api.nvim_buf_call(prev_buf, fetch_action_data)
  else
    fetch_action_data()
  end

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
      run.clean(action, true, on_exit)
      return false
    end
    ---@type Step: a step to be run as a job
    local step = table.remove(steps, 1)

    ---@type string|nil
    local step_name
    ---@type string: executable of the job
    local exe = ""
    ---@type table: arguments added to the exe
    local args
    ---@type string|nil: step's working directory
    local step_cwd
    ---@type table: step's env variables
    local step_env
    ---@type boolean|nil: step's working directory
    local step_clear_env

    --NOTE: primarily use step's fields, they override the
    --action's fields. Use action's fields for those fields
    --that are undefined in the step.

    ---Fetch data for the step
    ---@return boolean
    local function get_step_data()
      step_name, err = step:get_name()
      if err ~= nil then
        log.error(err)
        return false
      end

      exe, err = step:get_exe()
      if err ~= nil then
        log.error(err)
        return false
      end
      args, err = step:get_args()
      if err ~= nil then
        log.error(err)
        return false
      end

      step_cwd, err = step:get_cwd()
      if err ~= nil then
        log.warn(err)
      end
      if step_cwd == nil then
        step_cwd = cwd
      end

      step_env, err = step:get_env()
      if err ~= nil then
        log.warn(err)
      end

      step_clear_env, err = step:get_clear_env()
      if err ~= nil then
        log.warn(err)
      end
      return true
    end

    local continue = false
    if prev_buf ~= nil and vim.fn.bufexists(prev_buf) == 1 then
      --NOTE: fetch step data from the buffer from which the action
      --has been called

      vim.api.nvim_buf_call(prev_buf, function()
        continue = get_step_data()
      end)
    else
      continue = get_step_data()
    end
    if continue == false then
      run.clean(action, true, on_exit)
      return false
    end

    log.debug("Running step: " .. step_name)

    ---@type string|table: cmd sent to the job
    local cmd = exe
    if next(args) ~= nil then
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

    ---@type table|nil
    local step_env2 = nil
    if next(step_env) ~= nil then
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
          run.clean(action, true, on_exit)
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
          run.clean(action, true, on_exit)
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
          run.clean(action, true, on_exit)
          return
        end
        if next(steps) ~= nil then
          return run_steps_recursively(steps)
        end
        run.write_output(
          path,
          { "", "> ACTION [" .. action.name .. "] SUCCESS" }
        )
        run.clean(action, true, on_exit)
      end,
    })
    if ok == true then
      running_actions[action.name] = started_job
      return true
    end
    log.warn(started_job)
    run.clean(action, true, on_exit)
    return false
  end

  return run_steps_recursively(steps_copy)
end

---Kills the provided action and saves the output from
---the buffer to the file in neovim's data directory.
---Deletes the output buffer.
---
---@param action Action
---@param clean? boolean: Whether to remove action from running_actions
---@param callback function?: Function to call after killing
---@return boolean: whether successfully killed
function run.clean(action, clean, callback)
  if running_actions[action.name] == nil then
    return false
  end
  local job = running_actions[action.name]
  pcall(vim.fn.jobstop, job)
  if clean == true then
    running_actions[action.name] = nil
  end
  if callback ~= nil then
    pcall(callback)
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
    ok, e = pcall(vim.fn.writefile, lines, path)
  else
    ok, e = pcall(vim.fn.writefile, lines, path, "a")
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

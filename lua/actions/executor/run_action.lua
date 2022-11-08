local log = require "actions.log"

---A table with actions' names as keys
---and their job ids as values
---
---@type table
local running_actions = {}

local open_temp_win

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
  ---@type number|nil: A temporary window with
  ---buffer from which the action has been started oppened.
  ---Fetch action's field from this window, so if the fields
  ---are functions, they may be relative to current buffer.
  local temp_win
  if prev_buf ~= vim.fn.bufnr() then
    temp_win = open_temp_win(prev_buf)
  end

  ---@type string: Path to the output file
  local path = action:get_output_path()

  ---NOTE: fetch the action's fields

  local original_steps = action:get_steps()

  ---@type table: a copy of original steps
  local steps_copy = {}
  for _, step in ipairs(original_steps) do
    table.insert(steps_copy, step)
  end

  local env, err = action:get_env()
  if err ~= nil then
    log.warn(err)
  end

  ---@type boolean|nil: Env variables not in action's env
  ---are cleared.
  local clear_env
  clear_env, err = action:get_clear_env()
  if err ~= nil then
    log.warn(err)
  end

  ---@type string|nil: working directory of the actions
  ---may be overriden by step's cwd
  local cwd
  cwd, err = action:get_cwd()
  if err ~= nil then
    log.warn(err)
  end

  ---NOTE: close the temporaty window, it will be oppened
  ---again when fetching data for steps
  pcall(vim.api.nvim_win_close, temp_win, true)

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

    if prev_buf ~= vim.fn.bufnr() then
      temp_win = open_temp_win(prev_buf)
    end

    local step_name = step:get_name()
    log.debug("Running step: " .. step_name)
    --
    ---@type string: executable of the job
    local exe = ""
    exe, err = step:get_exe()
    if err ~= nil then
      log.error(err)
      pcall(vim.api.nvim_win_close, temp_win, true)
      run.clean(action, true, on_exit)
      return false
    end
    ---@type table: arguments added to the exe
    local args
    args, err = step:get_args()
    if err ~= nil then
      log.error(err)
      run.clean(action, true, on_exit)
    end
    ---@type string|table: cmd sent to the job
    local cmd = exe
    if next(args) ~= nil then
      cmd = { exe }
      for _, arg in ipairs(args) do
        table.insert(cmd, arg)
      end
    end

    run.write_output(path, { "", "> STEP [" .. step_name .. "]", "", "" })

    --NOTE: primarily use step's fields, they override the
    --action's fields. Use action's fields for those fields
    --that are undefined in the step.

    ---@type string|nil: step's working directory
    local step_cwd
    step_cwd, err = step:get_cwd()
    if err ~= nil then
      log.warn(err)
    end
    if step_cwd == nil then
      step_cwd = cwd
    end

    ---@type table|nil: step's env variables
    local step_env
    step_env, err = step:get_env()
    if err ~= nil then
      log.warn(err)
    end

    ---@type boolean|nil: step's working directory
    local step_clear_env
    step_clear_env, err = step:get_clear_env()
    if err ~= nil then
      log.warn(err)
    end

    pcall(vim.api.nvim_win_close, temp_win, true)

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

    if next(step_env) == nil then
      step_env = nil
    end
    local ok, started_job = pcall(vim.fn.jobstart, cmd, {
      detach = false,
      env = step_env,
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

---Open a 1x1 temporary window
---
---@param buf number?: the number of a buffer
---@return number|nil: id of the oppened window, nil on failure
open_temp_win = function(buf)
  if buf == nil then
    return
  end
  local ok, v = pcall(vim.fn.bufexists, buf)
  if ok == false or v ~= 1 then
    return
  end
  ok, v = pcall(vim.api.nvim_open_win, buf, true, {
    relative = "editor",
    style = "minimal",
    width = 1,
    height = 1,
    row = 1,
    col = 1,
    focusable = false,
    noautocmd = true,
  })
  if ok then
    return v
  end
  return nil
end

return run

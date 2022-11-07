local log = require "actions.util.log"

---A table with actions' names as keys
---and tables as values. Values have fields
---"buf" and "job"
---
---@type table
local running_actions = {}

local run = {}

---Returns the buffer name for the running action identified
---by the provided name. Returns nil if the action is
---not running.
---
---@param name string: name of an action
---@return number|nil
function run.get_running_action_buffer(name)
  if running_actions[name] == nil then
    return nil
  end
  return running_actions[name].buf
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
function run.run(action, on_exit)
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

  local output_buf = vim.api.nvim_create_buf(false, true)

  running_actions[action.name] = {
    buf = output_buf,
  }

  run.write_output(
    output_buf,
    { "> ACTION [" .. action.name .. "] START" },
    true
  )

  ---@param steps table
  ---@return boolean
  local function run_steps_recursively(steps)
    if next(steps) == nil then
      run.clean(action, true, on_exit)
      return false
    end
    ---@type Step: a step to be run as a job
    local step = table.remove(steps, 1)

    local step_name = step:get_name()
    log.debug("Running step: " .. step_name)
    --
    ---@type string: executable of the job
    local exe = ""
    exe, err = step:get_exe()
    if err ~= nil then
      log.error(err)
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

    run.write_output(
      output_buf,
      { "", "> STEP [" .. step_name .. "]", "", "" }
    )

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
          s = d
        end
        if next(s) ~= nil and run.write_output(output_buf, s) == false then
          run.clean(action, true, on_exit)
        end
      end,
      on_stdout = function(_, d)
        local s = {}
        if type(d) == "string" then
          s = { d }
        elseif type(d) == "table" then
          s = d
        end
        if next(s) ~= nil and run.write_output(output_buf, s) == false then
          run.clean(action, true, on_exit)
        end
      end,
      on_exit = function(_, code)
        local ok_code = code == nil or (type(code) == "number") and code == 0
        if ok_code == false then
          run.write_output(output_buf, {
            "> ACTION ["
              .. action.name
              .. "] "
              .. " exited witih code: "
              .. code,
          })
          run.clean(action, true, on_exit)
          return
        end
        if next(steps) ~= nil then
          return run_steps_recursively(steps)
        end
        run.write_output(
          output_buf,
          { "", "> ACTION [" .. action.name .. "] SUCCESS" }
        )
        run.clean(action, true, on_exit)
      end,
    })
    if ok == true then
      running_actions[action.name].job = started_job
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
  local buf = running_actions[action.name].buf
  local job = running_actions[action.name].job
  pcall(vim.fn.jobstop, job)
  if clean == true then
    running_actions[action.name] = nil
  end
  if callback ~= nil then
    pcall(callback)
  end
  local ok, v = pcall(vim.fn.bufexists, buf)
  if ok == false or v ~= 1 then
    return false
  end
  if clean == true then
    run.save_output_buffer(action, buf)
  end
  return true
end

---Stop a running action
---
---@param action Action: Action to be stopped
---@param callback function: Function to be called on successful stop
function run.stop(action, callback)
  if running_actions[action.name] == nil then
    return false
  end
  local job = running_actions[action.name].job
  pcall(vim.fn.jobstop, job)
  if callback ~= nil then
    pcall(callback)
  end
  return true
end

---Writes provided text to the action's
---output file.
---
---@param buf number: output buffer
---@param lines table: output to write
---@param first boolean?: whether this is the first output to the buffer
---@return boolean: successful write
function run.write_output(buf, lines, first)
  if vim.fn.bufexists(buf) ~= 1 then
    return false
  end
  local ok, e
  if first == true then
    ok, e = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  else
    ok, e = pcall(vim.api.nvim_buf_set_lines, buf, -1, -1, false, lines)
  end
  if ok == false then
    log.warn(e)
  end

  return ok
end

---Save the output buffer to an output file
---in the neovim's data directory.
---
---@param action Action
---@param buf number
function run.save_output_buffer(action, buf)
  if vim.fn.bufexists(buf) ~= 1 then
    return
  end
  local path = action:get_output_path()
  local ok, dirname = pcall(vim.fs.dirname, path)
  if ok == false then
    log.warn(dirname)
    return
  end
  local dir
  ok, dir = pcall(vim.fs.dir, dirname)
  if ok == false then
    log.warn(dir)
    return
  end
  if dir == nil then
    ok, dir = pcall(vim.fn.mkdir, dirname, "p")
    if ok == false then
      log.warn(dir)
      return
    end
  end
  local v
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
  if ok == false then
    return
  end
  pcall(vim.api.nvim_buf_set_option, buf, "buftype", "")
  pcall(vim.fn.delete, path)
  pcall(vim.cmd, "silent update! >>" .. path)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  pcall(vim.api.nvim_win_close, v, true)
end

return run

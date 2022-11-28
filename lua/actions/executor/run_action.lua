local log = require "actions.log"
local enum = require "actions.enum"

---A table with actions' names as keys
---and their job ids as values
---
---@type table
local running_actions = {}

local run = {}

---Returns the buffer number for the action identified
---by the provided name.
---
---@param name string: name of an action
---@return number?: the buffer number
function run.get_buf_num(name)
  if running_actions[name] == nil then
    return nil
  end
  return running_actions[name].buf
end

---Returns the buffer number for the action identified
---by the provided name.
---
---@param name string: name of an action
---@return number?: the buffer number
function run.get_job_id(name)
  if running_actions[name] == nil then
    return nil
  end
  return running_actions[name].job
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
  ---@type table
  local steps = action.steps
  ---@type table
  local env = nil
  if action.env ~= nil and next(action.env) ~= nil then
    env = action.env
  end
  ---@type boolean|nil
  local clear_env = action.clear_env
  ---@type string|nil
  local cwd = action.cwd

  -- NOTE: join all steps into a single command
  -- and echo current step
  local cmd = "echo '==> ACTION: ["
    .. vim.fn.shellescape(action.name)
    .. "]\n' "
  if cwd ~= nil then
    cmd = cmd .. " && echo '\n==> CWD: [" .. cwd .. "]\n'"
  end
  for _, step in ipairs(steps) do
    cmd = cmd
      .. " && "
      .. "echo '\n==> STEP: ["
      .. step:gsub("'", "'\\''")
      .. "]\n'"
    cmd = cmd .. " && " .. step
  end

  --NOTE: if an output buffer for the same action already exists,
  --open terminal in that one instead of creating a new one
  local term_buf = run.get_buf_num(action.name)
  if term_buf == nil or vim.fn.bufexists(term_buf) ~= 1 then
    local ok
    ok, term_buf = pcall(vim.api.nvim_create_buf, false, true)
    if ok == false then
      log.warn(term_buf)
      return false
    end
  end
  vim.api.nvim_buf_set_option(term_buf, "modified", false)
  vim.api.nvim_buf_set_option(term_buf, "modifiable", true)

  vim.api.nvim_clear_autocmds {
    event = { "TermClose", "TermEnter" },
    buffer = term_buf,
    group = enum.ACTIONS_AUGROUP,
  }
  --NOTE: set the autocmd for the terminal buffer, so that
  --when it finishes, we cannot enter the insert mode.
  --(when we enter insert mode in the closed terminal, it is deleted)
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = term_buf,
    group = enum.ACTIONS_AUGROUP,
    callback = function()
      vim.cmd "stopinsert"
      vim.api.nvim_create_autocmd("TermEnter", {
        group = enum.ACTIONS_AUGROUP,
        callback = function()
          vim.cmd "stopinsert"
        end,
        buffer = term_buf,
      })
    end,
    nested = true,
    once = true,
  })
  --NOTE: open a terminal in the created buffer
  --set the terminal's properties to match the action
  local job_id
  local ok1, err = pcall(vim.api.nvim_buf_call, term_buf, function()
    _, job_id = pcall(vim.fn.termopen, cmd, {
      cwd = cwd,
      env = env,
      clear_env = clear_env,
      detach = false,
      on_exit = function(_, code)
        if running_actions[action.name] ~= nil then
          running_actions[action.name].job = nil
        end
        on_exit(code)
      end,
    })
  end)
  if ok1 == false then
    log.warn(err)
    return false
  end
  --NOTE: if job_id is string, it means
  --an error occured when starting the action
  if type(job_id) == "string" then
    log.warn(job_id)
    return false
  end
  --NOTE: try to name the buffer, add index to
  --the end of it, in case a buffer with the same
  --name is already loaded
  for i = 0, 20 do
    local name = action.name
    if i > 0 then
      name = name .. "_" .. i
    end
    local ok, _ = pcall(vim.api.nvim_buf_set_name, term_buf, name)
    if ok == true then
      break
    end
  end
  --NOTE: set some options for the output buffer,
  --make sure it is not modifiable and that it is hidden
  --when closing it.
  --Set it's filetype to 'action_output' so it differs from
  --other terminal windows.
  vim.api.nvim_buf_set_option(term_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(term_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(term_buf, "modified", false)
  vim.api.nvim_buf_set_option(
    term_buf,
    "filetype",
    enum.OUTPUT_BUFFER_FILETYPE
  )

  running_actions[action.name] = {
    job = job_id,
    buf = term_buf,
  }
  return true
end

---Stop a running action.
---
---@param action Action: Action to be stopped
---@param callback function?: Function to be called on successful stop
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

return run

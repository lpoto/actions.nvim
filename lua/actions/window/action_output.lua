local run_action = require "actions.executor.run_action"
local setup = require "actions.setup"
local log = require "actions.util.log"

---@type number|nil: Buffer number of the oppened
local oppened_buf = nil

local window = {}

---@type string|nil: Name of the last oppened action
window.last_oppened = nil

---Open the output buffer for the provided
---action in the current window.
---
---@param action Action
function window.open(action)
  if action == nil then
    return
  end

  pcall(vim.api.nvim_exec_autocmds, "BufLeave", {
    group = "ActionsWindow",
  })
  if setup.config.before_displaying_output ~= nil then
    pcall(setup.config.before_displaying_output)
  end

  local buf = run_action.get_running_action_buffer(action.name)
  if buf == nil or vim.fn.bufexists(buf) ~= 1 then
    local path = action:get_output_path()
    local ok, v = pcall(vim.fn.filereadable, path)
    if ok == false or v == nil then
      log.warn("Action '" .. action.name .. "' has no output!")
      return
    end

    --NOTE: check if buffer is alread loaded
    -- if it is, open that one

    local get_ls = vim.tbl_filter(function(b)
      return vim.api.nvim_buf_is_valid(b)
        and vim.api.nvim_buf_get_name(b) == path
    end, vim.api.nvim_list_bufs())

    if next(get_ls) ~= nil then
      _, buf = next(get_ls)
    else
      buf = vim.api.nvim_create_buf(false, true)
    end

    --NOTE: navigate to the output buffer

    ok, v = pcall(vim.cmd, "silent buf " .. buf)
    if ok == false then
      log.error(v)
      return
    end

    --NOTE: open the output file in the buffer

    ok, v = pcall(vim.cmd, "find " .. path)
    if ok == false then
      log.error(v)
      return
    end
  else
    local ok, v = pcall(vim.cmd, "silent buf " .. buf)
    if ok == false then
      log.error(v)
      return
    end
  end
  pcall(vim.api.nvim_buf_set_option, buf, "modifiable", false)
  pcall(vim.api.nvim_buf_set_option, buf, "readonly", true)
  pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")

  pcall(vim.fn.matchadd, "Function", "^> ACTION \\[.*\\] SUCCESS$")
  pcall(vim.fn.matchadd, "Function", "^> ACTION \\[.*\\] START$")
  pcall(vim.fn.matchadd, "Constant", "^> STEP \\[.*\\]$")

  oppened_buf = buf

  pcall(vim.api.nvim_create_augroup, "ActionsWindow", {
    clear = true,
  })
  pcall(vim.api.nvim_create_autocmd, "BufLeave", {
    buffer = buf,
    group = "ActionsWindow",
    command = "delmarks!",
    callback = function()
      oppened_buf = nil
    end,
    once = true,
  })

  window.last_oppened = action.name
  pcall(
    vim.api.nvim_win_set_cursor,
    0,
    { vim.api.nvim_buf_line_count(buf), 0 }
  )
end

---Reopens last oppened output window.
---If there is any.
function window.open_last()
  if window.last_oppened == nil then
    log.warn "There is no last oppened action output!"
    return
  end
  local action = setup.get_action(window.last_oppened)
  if action == nil then
    log.warn "There is no last oppened action output!"
    return
  end
  window.open(action)
end

---Reopens last oppened output window.
---If there is any.
function window.toggle_last()
  if
    oppened_buf == nil
    or vim.fn.bufexists(oppened_buf) ~= 1
    or vim.fn.bufloaded(oppened_buf) ~= 1
  then
    window.open_last()
  else
    vim.api.nvim_buf_delete(oppened_buf, { force = true })
    oppened_buf = nil
  end
end

return window

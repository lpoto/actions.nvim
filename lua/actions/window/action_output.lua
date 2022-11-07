local run_action = require "actions.executor.run_action"
local setup = require "actions.setup"
local log = require "actions.util.log"

---@type string|nil: Name of the last oppened action
local last_oppened = nil

local window = {}

---@type function|nil: Function called before oppening output
---buffer in the current window.
---Useful for changing windows before oppening the buffer etc.
window.fn = function()
  pcall(vim.cmd, "vsplit")
end

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
  if window.fn ~= nil and type(window.fn) == "function" then
    pcall(window.fn)
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

  pcall(vim.fn.matchadd, "Function", "^> ACTION \\[.*\\]")
  pcall(vim.fn.matchadd, "Constant", "^> STEP \\[.*\\]")

  pcall(vim.api.nvim_create_augroup, "ActionsWindow", {
    clear = true,
  })
  pcall(vim.api.nvim_create_autocmd, "BufLeave", {
    buffer = buf,
    group = "ActionsWindow",
    command = "delmarks!",
    once = true,
  })

  last_oppened = action.name
  pcall(
    vim.api.nvim_win_set_cursor,
    0,
    { vim.api.nvim_buf_line_count(buf), 0 }
  )
end

---Reopens last oppened output window.
---If there is any.
function window.open_last()
  if last_oppened == nil then
    log.warn "There is no last oppened action output!"
    return
  end
  local action = setup.get_action(last_oppened)
  if action == nil then
    log.warn "There is no last oppened action output!"
    return
  end
  window.open(action)
end

return window

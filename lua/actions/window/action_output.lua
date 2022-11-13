local setup = require "actions.setup"
local log = require "actions.log"
local run_action = require "actions.executor.run_action"

local oppened_win = nil

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
  local buf = run_action.get_buf_num(action.name)
  if buf == nil or vim.fn.bufexists(buf) ~= 1 then
    log.warn("Action '" .. action.name .. "' has no output!")
    return
  end

  vim.api.nvim_exec_autocmds("BufLeave", {
    group = "ActionsWindow",
  })

  vim.fn.execute "vertical new"
  vim.fn.execute("buf " .. buf)
  oppened_win = vim.fn.winnr()

  vim.fn.matchadd("Function", "^==> ACTION: \\[.*\\]$")
  vim.fn.matchadd("Constant", "^==> STEP: \\[.*\\]$")
  vim.fn.matchadd("Statement", "^\\[Process exited .*\\]$")
  vim.fn.matchadd("Function", "^\\[Process exited 0\\]$")

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      pcall(vim.api.nvim_buf_call, buf, function()
        pcall(vim.fn.execute, "delm!")
      end)
    end,
    once = true,
  })
  window.last_oppened = action.name
end

---Reopens last oppened output window.
---If there is any.
function window.toggle_last()
  local action, err = setup.get_action(window.last_oppened)
  if err ~= nil then
    log.warn(err)
    return
  elseif action == nil then
    return
  end
  local ok, v = pcall(vim.fn.win_getid, oppened_win)
  if ok == false or v == nil or v < 1 then
    return window.open(action)
  end
  vim.api.nvim_win_close(v, false)
end

return window

local setup = require "actions.setup"
local log = require "actions.log"
local enum = require "actions.enum"
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

  --NOTE: make sure the provided action is running.
  local buf = run_action.get_buf_num(action.name)
  if buf == nil or vim.fn.bufexists(buf) ~= 1 then
    log.warn("Action '" .. action.name .. "' has no output!")
    return
  end

  --NOTE: execute the BufLeave autocmds, so the
  --available actions window is wiped
  vim.api.nvim_exec_autocmds("BufLeave", {
    group = enum.ACTIONS_AUGROUP,
  })

  --NOTE: if the action already has a window oppened for
  --it's output, navigate to that window instead of oppening
  --another one.
  local existing_buf = run_action.get_buf_num(action.name)
  if existing_buf ~= nil and vim.fn.bufexists(existing_buf) == 1 then
    local winnr = vim.fn.bufwinnr(existing_buf)
    if winnr ~= -1 then
      vim.fn.execute("keepjumps " .. winnr .. "wincmd w", true)
      if winnr == vim.fn.bufwinnr(vim.fn.bufnr()) then
        return
      end
    end
  end

  if setup.config.before_displaying_output ~= nil then
    --NOTE: allow user defining how the output
    --window should be displayed.

    setup.config.before_displaying_output(buf)
  else
    --NOTE: oppen the output window in a vertical
    --split by default.

    --NOTE: use keepjumps to no add the output buffer
    --to the jumplist
    vim.fn.execute("keepjumps vertical sb " .. buf)
  end
  local ow = vim.fn.bufwinid(buf)
  if ow == -1 then
    log.warn("There is no output window for action: " .. action.name)
    return
  end
  oppened_win = ow

  --NOTE: match some higlights in the output window
  --to distinguish the echoed step and action info from
  --the actual output
  pcall(vim.api.nvim_win_call, ow, function()
    vim.fn.matchadd("Function", "^==> ACTION: \\[\\_.\\{-}\\]$")
    vim.fn.matchadd("Constant", "^==> STEP: \\[\\_.\\{-}\\]$")
    vim.fn.matchadd("Statement", "^\\[Process exited .*\\]$")
    vim.fn.matchadd("Function", "^\\[Process exited 0\\]$")

    if setup.config.after_displaying_output ~= nil then
      --NOTE: allow the user to
      setup.config.after_displaying_output(oppened_win)
    end
  end)

  --NOTE: save which action's output has last been
  --opened, so it may be toggled
  window.last_oppened = action.name
end

---Reopens last oppened output window.
---If there is any.
function window.toggle_last()
  --NOTE: make sure there was any action oppened previously
  local action, err = setup.get_action(window.last_oppened)
  if err ~= nil then
    log.warn(err)
    return
  elseif action == nil then
    return
  end

  --NOTE: if there is no active window for the
  --last oppened action open it, else close it.
  local ok, v = pcall(vim.api.nvim_win_is_valid, oppened_win)

  if ok == false or v ~= true then
    return window.open(action)
  end
  --NOTE: this should hide the buffer as it has
  --bufhidden=hide
  vim.api.nvim_win_close(oppened_win, false)
end

return window

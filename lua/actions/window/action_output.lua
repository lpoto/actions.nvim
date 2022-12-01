local log = require "actions.log"
local run_action = require "actions.executor.run_action"
local output_window = require "actions.window.output"

local window = {}

---Open the output buffer for the provided
---action in the current window.
---
---@param action Action
function window.open(action)
  if action == nil then
    return
  end
  -- NOTE: make sure the provided action is running.
  local buf = run_action.get_buf_num(action.name)
  if buf == nil or vim.fn.bufexists(buf) ~= 1 then
    log.warn("Action '" .. action.name .. "' has no output!")
    return
  end
  local create_buffer, handle_window = window.get_init_functions(action)
  output_window.open(create_buffer, handle_window)
  output_window.set_previous(create_buffer, handle_window)
end

---Set the provided action identified b
---action in the current window.
---
---@param action Action
function window.set_as_previous(action)
  if action == nil then
    return
  end
  -- NOTE: make sure the provided action is running.
  local buf = run_action.get_buf_num(action.name)
  if buf == nil or vim.fn.bufexists(buf) ~= 1 then
    return
  end
  output_window.set_previous(window.get_init_functions(action))
end

---@param action Action: the action for which the output will be shown.
---@return function: Function to get the output buffer number
---@return function: Function to handle the oppened window
function window.get_init_functions(action)
  ---@return number?: An action output buffer number
  local create_buffer = function()
    return run_action.get_buf_num(action.name)
  end
  local handle_window = function(winid)
    -- NOTE: set wrap for the oppened window
    vim.api.nvim_win_set_option(winid, "wrap", true)

    -- NOTE: match some higlights in the output window
    -- to distinguish the echoed step and action info from
    -- the actual output
    pcall(vim.api.nvim_win_call, winid, function()
      vim.fn.matchadd("Function", "^==> ACTION: \\[\\_.\\{-}\\n\\n")
      vim.fn.matchadd("Constant", "^==> STEP: \\[\\_.\\{-}\\n\\n")
      vim.fn.matchadd("Comment", "^==> CWD: \\[\\_.\\{-}\\n\\n")
      vim.fn.matchadd("Statement", "^\\[Process exited .*\\]$")
      vim.fn.matchadd("Function", "^\\[Process exited 0\\]$")

      if vim.fn.winwidth(winid) < 50 and vim.o.columns >= 70 then
        -- NOTE: make sure the output window is at least 50 columns wide
        vim.fn.execute("vertical resize " .. 50, true)
      end
    end)
  end
  return create_buffer, handle_window
end

return window

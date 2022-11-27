local log = require "actions.log"
local run_action = require "actions.executor.run_action"
local output_window = require "actions.window.output"

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
  -- NOTE: make sure the provided action is running.
  local buf = run_action.get_buf_num(action.name)
  if buf == nil or vim.fn.bufexists(buf) ~= 1 then
    log.warn("Action '" .. action.name .. "' has no output!")
    return
  end
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
  output_window.open(create_buffer, handle_window)
end

return window

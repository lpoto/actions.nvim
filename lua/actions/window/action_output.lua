local setup = require "actions.setup"
local log = require "actions.log"
local run_action = require "actions.executor.run_action"

local ready_output_buffer
local ready_output_window
local update_on_changes

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

  local path = action:get_output_path()
  local ok, v = pcall(vim.fn.filereadable, path)
  if ok == false or v ~= 1 then
    log.warn("Action '" .. action.name .. "' has no output!")
    return
  end

  pcall(vim.api.nvim_exec_autocmds, "BufLeave", {
    group = "ActionsWindow",
  })

  --NOTE: check if buffer is alread loaded
  -- if it is, open that one

  local get_ls = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_valid(b)
      and vim.api.nvim_buf_is_loaded(b)
      and vim.api.nvim_buf_get_name(b) == path
  end, vim.api.nvim_list_bufs())

  if next(get_ls) ~= nil then
    local _, loaded_buf = next(get_ls)
    pcall(vim.api.nvim_buf_delete, loaded_buf, { force = true })
  end

  if setup.config.before_displaying_output ~= nil then
    setup.config.before_displaying_output()
  end

  --NOTE: open the output file in the buffer

  ok, v = pcall(vim.fn.execute, "find " .. path)
  if ok == false then
    log.error(v)
    return
  end
  local buf = vim.fn.bufnr()

  ready_output_buffer(buf)
  ready_output_window(buf)

  if setup.config.after_displaying_output ~= nil then
    setup.config.after_displaying_output(buf)
  end

  window.last_oppened = action.name

  update_on_changes(path, action.name)
end

---Reopens last oppened output window.
---If there is any.
function window.toggle_last()
  local name = window.last_oppened
  if name == nil then
    log.warn "There is no last oppened action output!"
    return
  end
  local action, err = setup.get_action(window.last_oppened)
  if err ~= nil then
    log.warn(err)
    return
  elseif action == nil then
    return
  end
  local path = action:get_output_path()
  local get_ls = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_valid(b)
      and vim.api.nvim_buf_is_loaded(b)
      and vim.api.nvim_buf_get_name(b) == path
  end, vim.api.nvim_list_bufs())

  if next(get_ls) ~= nil then
    local _, loaded_buf = next(get_ls)
    pcall(vim.api.nvim_buf_delete, loaded_buf, { force = true })
    return
  end
  window.open(action)
end

---@param buf number
---@type function
ready_output_buffer = function(buf)
  pcall(vim.api.nvim_buf_set_option, buf, "modifiable", false)
  pcall(vim.api.nvim_buf_set_option, buf, "readonly", true)
  pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
  pcall(vim.api.nvim_buf_set_option, buf, "autoread", true)
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
end

---@param buf number
---@type function
ready_output_window = function(buf)
  pcall(vim.fn.matchadd, "Function", "^> ACTION \\[.*\\] SUCCESS$")
  pcall(vim.fn.matchadd, "Function", "^> ACTION \\[.*\\] START$")
  pcall(vim.fn.matchadd, "Constant", "^> STEP \\[.*\\]$")
  pcall(vim.fn.matchadd, "Statement", "^> ACTION \\[.*\\] exited with code: ")

  pcall(vim.api.nvim_create_augroup, "ActionsWindow", {
    clear = true,
  })
  pcall(vim.api.nvim_create_autocmd, "BufLeave", {
    buffer = buf,
    group = "ActionsWindow",
    command = "delmarks!",
    once = true,
  })

  pcall(
    vim.api.nvim_win_set_cursor,
    0,
    { vim.api.nvim_buf_line_count(buf), 0 }
  )
end

---If a buffer exists with the provided path oppened,
---refresh it every 500 ms
---@param path string: path to a file
---@param name string: action name
update_on_changes = function(path, name)
  local watch_file

  local w = vim.loop.new_timer()

  local not_running = 0

  local function on_change(file_path)
    w:stop()
    if run_action.is_running(name) == false then
      not_running = not_running + 1
    else
      not_running = 0
    end
    if not_running < 2 then
      local get_ls = vim.tbl_filter(function(b)
        return vim.api.nvim_buf_is_valid(b)
          and vim.api.nvim_buf_get_name(b) == file_path
      end, vim.api.nvim_list_bufs())

      if next(get_ls) == nil then
        return
      end
      local _, buf = next(get_ls)
      -- NOTE: try to move cursor to the bottom of the window
      local ok, winid = pcall(vim.fn.bufwinid, buf)
      local line_count, cursor_pos
      if ok == false then
        log.warn(winid)
      else
        local _, lc = pcall(vim.api.nvim_buf_line_count, buf)
        local _, cp = pcall(vim.api.nvim_win_get_cursor, winid)
        line_count, cursor_pos = lc, cp
      end
      local ok1, e1, ok2, e2
      ok1, e1 = pcall(vim.api.nvim_buf_call, buf, function()
        ok2, e2 = pcall(vim.fn.execute, "e", true)
      end)
      if ok1 == false then
        log.warn(e1)
        return
      end
      if ok2 == false then
        log.warn(e2)
        return
      end
      if type(cursor_pos) == "table" and cursor_pos[1] == line_count then
        ok, line_count = pcall(vim.api.nvim_buf_line_count, buf)
        if ok ~= false then
          pcall(vim.api.nvim_win_set_cursor, winid, { line_count, 0 })
        end
      end
    end
    watch_file(file_path)
  end
  function watch_file(file_path)
    w:start(
      500,
      0,
      vim.schedule_wrap(function()
        on_change(file_path)
      end)
    )
  end
  watch_file(path)
end

return window

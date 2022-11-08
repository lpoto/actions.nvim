local log = require "actions.log"
local setup = require "actions.setup"
local executor = require "actions.executor"
local output_window = require "actions.window.action_output"

local prev_buf = nil
local buf = nil
local outter_buf = nil

local window = {}

local set_window_lines
local set_outter_window_lines
local set_window_options
local set_window_highlights
local set_outter_window_highlights

---Opens a floating window displayed
---over the center of the editor.
---
---@return number: the oppened buffer number, -1 on failure
function window.open()
  local actions = setup.get_available()

  if actions == nil or next(actions) == nil then
    log.warn "There are no available actions"
    return -1
  end

  prev_buf = vim.fn.bufnr()

  local width = 50
  local height = 30
  local row = vim.o.lines / 2 - height / 2
  local col = vim.o.columns / 2 - width / 2

  outter_buf = vim.api.nvim_create_buf(false, true)
  buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_open_win(outter_buf, true, {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    focusable = false,
    noautocmd = true,
  })
  set_outter_window_highlights()
  set_outter_window_lines(width, actions)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    width = width - 13,
    height = height - 5,
    row = row + 5,
    col = col + 3,
    noautocmd = true,
    --border = "rounded",
  })

  set_window_highlights()
  set_window_lines(actions)
  set_window_options()

  return buf
end

---Reads the name of the actions in the line under the cursor.
---Passes the name of the action to executor.start_or_kill(name).
function window.select_action_under_cursor()
  local bufnr = vim.fn.bufnr()
  if buf ~= bufnr then
    return
  end
  local linenr = vim.fn.line "."
  local name = vim.fn.getline(linenr)
  ---@type Action|nil
  local action = setup.get_action(name)
  if action == nil then
    log.warn("Action '" .. name .. "' does not exist!")
    return
  end
  -- NOTE: if action is running kill it and remove
  -- [running] from the actions's row in the window
  if executor.is_running(action.name) == true then
    if
      executor.kill(name, function()
        local l = "> " .. string.rep(" ", 37) .. "[killed]"
        pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", true)
        pcall(
          vim.api.nvim_buf_set_lines,
          outter_buf,
          linenr + 3,
          linenr + 4,
          false,
          { l }
        )
        pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", false)
      end) == true
    then
      local l = "> "
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", true)
      pcall(
        vim.api.nvim_buf_set_lines,
        outter_buf,
        linenr + 3,
        linenr + 4,
        false,
        { l }
      )
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", false)
    end
    return
  end
  if
    executor.start(name, prev_buf, function()
      local l = "> " .. string.rep(" ", 37) .. "[done]"
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", true)
      pcall(
        vim.api.nvim_buf_set_lines,
        outter_buf,
        linenr + 3,
        linenr + 4,
        false,
        { l }
      )
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", false)
    end) == true
  then
    if executor.is_running(name) == true then
      local l = "> " .. string.rep(" ", 37) .. "[running]"
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", true)
      pcall(
        vim.api.nvim_buf_set_lines,
        outter_buf,
        linenr + 3,
        linenr + 4,
        false,
        { l }
      )
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", false)
    end
  end
end

---Reads the name of the actions in the line under the cursor.
---If the action is running, shows its output in another window.
function window.output_of_action_under_cursor()
  local bufnr = vim.fn.bufnr()
  if buf ~= bufnr then
    return
  end
  local linenr = vim.fn.line "."
  local name = vim.fn.getline(linenr)
  ---@type Action|nil
  local action = setup.get_action(name)
  if action == nil then
    log.warn("Action '" .. name .. "' does not exist!")
    return
  end
  output_window.open(action)
end

---Replace lines in the actions window with
---the available actions.
---Also sets higlightings for the inserted text.
---NOTE: this requires the actions window to
---be the currently oppened window.
---
---@param actions table: a table of available actions
set_window_lines = function(actions)
  local bufnr = vim.fn.bufnr()
  if buf ~= bufnr then
    return
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  local lines = {}
  for _, action in ipairs(actions) do
    local l = action:get_name()
    table.insert(lines, l)
  end
  vim.api.nvim_buf_set_lines(
    buf,
    0,
    vim.api.nvim_buf_line_count(buf),
    false,
    lines
  )
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

---Replace lines in the outter actions window with instructions
---
---@param width number: width of the actions window
---@param actions table: a table of available actions
set_outter_window_lines = function(width, actions)
  local bufnr = vim.fn.bufnr()
  if bufnr ~= outter_buf then
    return
  end

  vim.api.nvim_buf_set_option(outter_buf, "modifiable", true)

  local lines = {
    " Run an action with: '<ENTER>'",
    " Kill a running action with: '<ENTER>'",
    " See the output of an action with: 'o'",
    string.rep("-", width),
  }
  for _, action in ipairs(actions) do
    local l = "> "
    if executor.is_running(action.name) then
      l = l .. string.rep(" ", 37) .. "[running]"
    end
    table.insert(lines, l)
  end
  vim.api.nvim_buf_set_lines(
    outter_buf,
    0,
    vim.api.nvim_buf_line_count(outter_buf),
    false,
    lines
  )
  vim.cmd "silent normal 6j"

  vim.api.nvim_buf_set_option(outter_buf, "modifiable", false)
end

---Set higlights for the actions window.
---NOTE: actions window should be the
---currently oppened window.
set_window_highlights = function()
  local bufnr = vim.fn.bufnr()
  if bufnr ~= buf then
    return
  end
  local winnid = vim.fn.bufwinid(bufnr)
  vim.api.nvim_win_set_option(
    winnid,
    "winhighlight",
    "NormalFloat:Normal,FloatBorder:Normal,CursorLine:Constant"
  )

  vim.opt_local.cursorline = true
end

---Set higlights for the outter actions window.
---NOTE: outter actions window should be the
---currently oppened window.
set_outter_window_highlights = function()
  local bufnr = vim.fn.bufnr()
  if bufnr ~= outter_buf then
    return
  end
  local winnid = vim.fn.bufwinid(bufnr)
  vim.api.nvim_win_set_option(
    winnid,
    "winhighlight",
    "NormalFloat:Normal,FloatBorder:Normal,Normal:Comment"
  )
end

---Set buffer options, remappings and autocommands
---for the actions window.
set_window_options = function()
  if vim.fn.bufnr() ~= buf then
    return
  end
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(outter_buf, "bufhidden", "wipe")

  vim.api.nvim_create_augroup("ActionsWindow", {
    clear = true,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    group = "ActionsWindow",
    callback = function()
      prev_buf = nil
      vim.api.nvim_buf_delete(buf, {
        force = true,
      })
      vim.api.nvim_buf_delete(outter_buf, {
        force = true,
      })
    end,
    once = true,
  })
  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "<Esc>",
    "<CMD>call nvim_exec_autocmds('BufLeave', {'buffer':"
      .. buf
      .. ", 'group':'ActionsWindow'})<CR>",
    {
      noremap = true,
    }
  )
  vim.api.nvim_buf_set_keymap(
    buf,
    "",
    "<CR>",
    "<CMD>lua require('actions.window.available_actions')"
      .. ".select_action_under_cursor()<CR>",
    {}
  )
  vim.api.nvim_buf_set_keymap(
    buf,
    "",
    "o",
    "<CMD>lua require('actions.window.available_actions')"
      .. ".output_of_action_under_cursor()<CR>",
    {}
  )
  vim.api.nvim_buf_set_keymap(
    buf,
    "",
    "<CR>",
    "<CMD>lua require('actions.window.available_actions')"
      .. ".select_action_under_cursor()<CR>",
    {}
  )
end

return window

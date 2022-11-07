local log = require "actions.util.log"
local setup = require "actions.setup"

local window = {}

local set_actions_window_lines
local set_outter_actions_window_lines
local set_actions_window_options
local set_actions_window_highlights
local set_outter_actions_window_highlights

---Opens a floating window displayed
---over the right half of the editor.
---
---@return number: the oppened buffer number, -1 on failure
function window.open()
  local actions = setup.get_available()

  if actions == nil or next(actions) == nil then
    log.warn "There are no available actions"
    return -1
  end

  local width = 50
  local height = 30
  local row = vim.o.lines / 2 - height / 2
  local col = vim.o.columns / 2 - width / 2

  local outter_buf = vim.api.nvim_create_buf(false, true)
  local buf = vim.api.nvim_create_buf(false, true)

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
  set_outter_actions_window_highlights()
  set_outter_actions_window_lines(outter_buf, width, actions)

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

  set_actions_window_highlights()
  set_actions_window_lines(actions)
  set_actions_window_options(buf, outter_buf)

  return buf
end

function window.select_action_under_cursor()
  local linenr = vim.fn.line "."
  local line = vim.fn.getline(linenr)
  print(line)
end

function window.output_of_action_under_cursor()
  print "OUTPUT OF ACTION"
end

---Replace lines in the actions window with
---the available actions.
---Also sets higlightings for the inserted text.
---NOTE: this requires the actions window to
---be the currently oppened window.
---
---@param actions table: a table of available actions
set_actions_window_lines = function(actions)
  local buf = vim.fn.bufnr()

  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  local lines = {}
  for i, action in ipairs(actions) do
    local l = action:get_name()
    if action.running == true then
      local n = string.len(l) + 2
      l = l .. "  [running]"
      for j = 1, 9 do
        vim.fn.matchaddpos("Function", { { i, n + j } })
      end
    end
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
---@param outter_buf number: buffer number of the actions buffer
---@param width number: width of the actions window
---@param actions table: a table of available actions
set_outter_actions_window_lines = function(outter_buf, width, actions)
  vim.api.nvim_buf_set_option(outter_buf, "modifiable", true)

  local lines = {
    " Run an action with: '<ENTER>'",
    " Kill a running action with: '<ENTER>'",
    " Display output of a an action with: 'o'",
    string.rep("-", width),
  }
  for i, _ in ipairs(actions) do
    local l = "> "
    vim.fn.matchaddpos("Comment", { { i + 4, 1 }, { i + 4, 2 } })
    l = l .. string.rep(" ", 37) .. "[running]"
    for j = 1, 9 do
      vim.fn.matchaddpos("Function", { { i + 4, j + 39 } })
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
set_actions_window_highlights = function()
  vim.api.nvim_set_hl(0, "NormalFloat", {})
  vim.api.nvim_set_hl(0, "FloatBorder", {})
end

---Set higlights for the outter actions window.
---NOTE: outter actions window should be the
---currently oppened window.
set_outter_actions_window_highlights = function()
  vim.api.nvim_set_hl(0, "NormalFloat", {})
  vim.api.nvim_set_hl(0, "FloatBorder", {})
  vim.fn.matchaddpos("Comment", { 1, 2, 3, 4 })
end

---Set buffer options, remappings and autocommands
---for the actions window.
---
---@param buf number: buffer number of the actions buffer
---@param outter_buf number: buffer number of the outter actions buffer
set_actions_window_options = function(buf, outter_buf)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(outter_buf, "bufhidden", "wipe")

  vim.api.nvim_create_augroup("ActionsWindow", {
    clear = true,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    group = "ActionsWindow",
    callback = function()
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
end

return window

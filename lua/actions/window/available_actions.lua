local log = require "actions.log"
local setup = require "actions.setup"
local executor = require "actions.executor"
local output_window = require "actions.window.action_output"
local Action = require "actions.model.action"

local window = {}

---@type number?: The buffer from which the actions buffer
---was oppened
local prev_buf = nil
---@type number?: Currently oppened actions buffer
local buf = nil
---@type number?: The currently oppened
--actions buffer's background buffer
local outter_buf = nil

--utility functions to handle the
--creation and the appearance of the
--actions window and buffer
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
  local cur_buf = vim.fn.bufnr()
  local buf_name = vim.api.nvim_buf_get_name(cur_buf)
  local match_against = Action.output_dir
  if string.find(buf_name, match_against) == nil then
    prev_buf = vim.fn.bufnr()
  end

  local actions, err = setup.get_available(prev_buf)
  if err ~= nil then
    log.warn(err)
    return -1
  end

  if actions == nil or next(actions) == nil then
    log.warn "There are no available actions"
    return -1
  end

  --NOTE: oppene 2 floating windows, the outter window
  --contains the border,the instructions text and the
  --action's labels, while the inner window contains
  --only the actions' names.
  --User may only navigate the inner window.

  local width = 50
  local height = 30
  local row = vim.o.lines / 2 - height / 2
  local col = vim.o.columns / 2 - width / 2

  --NOTE: make sure that both windows are closed
  --when the inner window loses focus

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
    height = height - 6,
    row = row + 6,
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
  local action, err = setup.get_action(name, prev_buf)
  if err ~= nil then
    log.warn(err)
    return
  elseif action == nil then
    return
  end
  -- NOTE: if action is running kill it and remove
  -- [running] from the actions's row in the window
  -- (replace it with [killed])
  if executor.is_running(action.name) == true then
    executor.kill(name, prev_buf)
    return
  end
  --NOTE: the action was not yet running, so we may start it.
  --Pass a callback function to the executor, and replace
  --the [running] label on finish.
  if
    executor.start(name, prev_buf, function(exit_code)
      --NOTE: set output label based on the exit code of
      --the action's job.
      --Use [done] as default label
      local label = "[done]"
      if exit_code == 0 then
        --NOTE: action exited with code 0, therefore the
        --job was successful
        label = "[success]"
      elseif exit_code == -1 then
        --NOTE: exit_code -1 means an error occured while running the job
        --(in execution of the job, not in the program itself)
        label = "[error]"
      elseif type(exit_code) == "number" and exit_code > 0 then
        --NOTE: The action exited with an error code
        --which means there is an error in the program itself, not
        --in the execution of the job
        label = "[exit]"
      end
      local l = "> " .. string.rep(" ", 37) .. label
      --NOTE: make sure the buffer is modifiable before
      --replacing text
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", true)
      pcall(
        vim.api.nvim_buf_set_lines,
        outter_buf,
        linenr + 4,
        linenr + 5,
        false,
        { l }
      )
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", false)
    end) == true
  then
    --NOTE: the executor successfully started the job, so
    --add the [running] label to the actino.
    if executor.is_running(name) == true then
      local l = "> " .. string.rep(" ", 37) .. "[running]"
      --NOTE: make sure the buffer is modifiable before
      --replacing any lines
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", true)
      pcall(
        vim.api.nvim_buf_set_lines,
        outter_buf,
        linenr + 4,
        linenr + 5,
        false,
        { l }
      )
      pcall(vim.api.nvim_buf_set_option, outter_buf, "modifiable", false)
    end
  end
end

---Reads the name of the actions in the line under the cursor.
---Displays the current definition of the action in the command line.
---NOTE: the displayed definition may differ based on the buffer
---the actions window was oppened from, but it is the same as the one
---that would be used for execution.
function window.definition_of_action_under_cursor()
  local bufnr = vim.fn.bufnr()
  if buf ~= bufnr then
    return
  end
  local linenr = vim.fn.line "."
  local name = vim.fn.getline(linenr)
  local action, err = setup.get_action(name, prev_buf)
  if err ~= nil then
    log.warn(err)
    return
  end
  if action == nil then
    return
  end
  --NOTE: recursively print the current definition
  --of the action
  --NOTE: displayed fields are the ones that would be used
  --for the execution
  print "action: "
  local function tprint(tbl, indent)
    if not indent then
      indent = 0
    end
    for k, v in pairs(tbl) do
      local formatting = string.rep("  ", indent) .. k .. ": "
      if type(v) == "table" then
        print(formatting)
        tprint(v, indent + 1)
      elseif type(v) == "boolean" then
        print(formatting .. tostring(v))
      else
        print(formatting .. v)
      end
    end
  end
  tprint(action, 1)
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
  local action, err = setup.get_action(name, prev_buf)
  if err ~= nil then
    log.warn(err)
    return
  end
  if action == nil then
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
    local l = action.name
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
    " See the action's definition with: 'd'",
    string.rep("-", width),
  }
  for _, action in ipairs(actions) do
    local l = "> "
    if executor.is_running(action.name) then
      l = l .. string.rep(" ", 37) .. "[running]"
    else
      local path = action:get_output_path()
      local ok, v = pcall(vim.fn.filereadable, path)
      if ok == true and v == 1 then
        l = l .. string.rep(" ", 37) .. "[output]"
      end
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
  vim.fn.execute("normal 6j", true)

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
      vim.api.nvim_buf_delete(buf, {
        force = true,
      })
      vim.api.nvim_buf_delete(outter_buf, {
        force = true,
      })
    end,
    once = true,
  })
  --NOTE: <Esc> closes the window by triggering
  --the BufLeave autocmd for the actions buffer
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
  --NOTE: select the action under the cursor with <Enter>
  --if the action is running this will kill it, otherwise
  --it will kill it
  vim.api.nvim_buf_set_keymap(
    buf,
    "",
    "<CR>",
    "<CMD>lua require('actions.window.available_actions')"
      .. ".select_action_under_cursor()<CR>",
    {}
  )
  --NOTE: show the output of an action with 'o' (if there is any)
  --this will close the actions window and oppen
  --the output in the current window
  vim.api.nvim_buf_set_keymap(
    buf,
    "",
    "o",
    "<CMD>lua require('actions.window.available_actions')"
      .. ".output_of_action_under_cursor()<CR>",
    {}
  )
  --NOTE: show the definition of an action with 'd'
  vim.api.nvim_buf_set_keymap(
    buf,
    "",
    "d",
    "<CMD>lua require('actions.window.available_actions')"
      .. ".definition_of_action_under_cursor()<CR>",
    {}
  )
end

return window

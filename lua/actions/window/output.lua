local setup = require "actions.setup"
local enum = require "actions.enum"

---@type number?: Window ID of the currently oppened output window
local oppened_win = nil

local previous_create_buffer = nil
local previous_handle_window = nil

local window = {}

---Opens an output buffer based on the provided
---functions.
---@param create_buffer function: Returns a valid buffer number
---@param handle_window function: Recieves window id as input param
function window.open(create_buffer, handle_window)
  if
    create_buffer == nil
    or type(create_buffer) ~= "function"
    or handle_window == nil
    or type(handle_window) ~= "function"
  then
    return
  end

  -- NOTE: execute the BufLeave autocmds, so the
  -- available actions window is wiped
  vim.api.nvim_exec_autocmds("BufLeave", {
    group = enum.ACTIONS_AUGROUP,
  })

  -- Get the buffer from the provided function
  local buf = create_buffer()

  -- NOTE: make sure a valid buffer was returned
  if type(buf) ~= "number" or vim.api.nvim_buf_is_valid(buf) ~= true then
    return
  end

  local existing_winid = vim.fn.bufwinid(buf)
  if vim.api.nvim_win_is_valid(existing_winid) then
    -- NOTE: a valid window already exists for the provided
    -- buffer so don't open another one.
    -- Rather just jump to it.
    vim.fn.win_gotoid(existing_winid)
    return
  end

  if setup.config.before_displaying_output ~= nil then
    -- NOTE: allow user defining how the output
    -- window should be displayed.

    setup.config.before_displaying_output(buf)
  else
    -- NOTE: oppen the output window in a vertical
    -- split by default.

    -- NOTE: use keepjumps to no add the output buffer
    -- to the jumplist
    local winid = vim.fn.win_getid(vim.fn.winnr())
    vim.fn.execute("keepjumps vertical sb " .. buf, true)
    vim.fn.win_gotoid(winid)
  end

  local ow = vim.fn.bufwinid(buf)
  if ow == -1 then
    -- NOTE: the output window has not been opened in the
    -- 'before_displaying_output' function.
    log.warn(
      "A window has not been opened for the output buffer! "
        .. "Make sure that 'before_displaying_output' "
        .. "opens a window for the buffer."
    )
    return
  end
  -- handle the oppened output window
  handle_window(ow)

  -- NOTE: save the oppened window so we know when to close it
  -- when toggling
  oppened_win = ow

  -- NOTE: save the provided functions to be used
  -- when toggling the previously oppened output window
  previous_handle_window = handle_window
  previous_create_buffer = create_buffer
end

---Reopens the last oppened output window, if there was any.
function window.toggle_last()
  -- NOTE: if an output window is already oppened, remove it
  if oppened_win ~= nil and vim.api.nvim_win_is_valid(oppened_win) then
    vim.api.nvim_win_close(oppened_win, false)
    return
  end

  -- NOTE: there is currently no oppened output window.
  -- Check if there is a previous output call and execute it
  if
    previous_create_buffer ~= nil
    and type(previous_create_buffer) == "function"
    and previous_handle_window ~= nil
    and type(previous_handle_window) == "function"
  then
    window.open(previous_create_buffer, previous_handle_window)
  end
end

return window

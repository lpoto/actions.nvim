local window = {}

local set_window_highlights

---Opens a floating window displayed
---over the right hald of the editor.
---If buffer number if provided, that buffer is displayed.
---
---@param name string: name of the buffer
---@param buf number|nil: an existing buffer number
---@return number: the oppened buffer number, -1 on failure
function window.open(name, buf)
  if buf ~= nil and vim.fn.bufexists(buf) ~= 1 then
    return -1
  end
  pcall(vim.api.nvim_exec_autocmds, "BufLeave", {
    group = "ActionsWindow",
  })

  if buf == nil then
    buf = vim.api.nvim_create_buf(false, true)
  end

  pcall(vim.api.nvim_buf_set_name, buf, name)

  local width = math.floor(vim.o.columns / 2)
  local height = vim.o.lines
  local row = vim.o.lines
  local col = vim.o.columns
  local anchor = "SE"

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    row = row,
    col = col,
    border = { "", "", "", "", "", "", "", "║" },
    anchor = anchor,
    focusable = true,
    noautocmd = true,
  })

  set_window_highlights()

  return buf
end

set_window_highlights = function()
  local winnid = vim.fn.bufwinid(vim.fn.bufnr())
  vim.api.nvim_win_set_option(
    winnid,
    "winhighlight",
    "NormalFloat:Normal,FloatBorder:Normal"
  )
end

return window

---@tag actions.model.user_config
---@config {["name"] = "USER CONFIG"}

---@brief [[
---Actions_user_config is an object that represents a plugin configuration
---created by the user.
---The config's actions are functions returning |Action| objects, so
---that they may be loaded when requested, which allows actions relative to
---the current context.
---
---Default value:
---<code>
---  {
---    log_level = vim.log.levels.INFO,
---    actions = {
---      ["Example action"] = function()
---        return {
---          filetypes = { "help" },
---          steps = {
---            "echo 'Current file: " .. (vim.fn.expand "%:p") .. "'"
---          }
---        }
---      end
---    },
---    -- open a window for the output buffer,
---    -- but keep focus on the current window
---    before_displaying_output = function(bufnr)
---      local winid = vim.fn.win_getid(vim.fn.winnr())
---      vim.fn.execute("keepjumps vertical sb " .. bufnr, true)
---      vim.fn.win_gotoid(winid)
---    end,
---  }
---</code>
---@brief ]]

---@class Actions_user_config
---@field actions table: A table with action names as keys and functions returning |Action| objects as values.
---@field before_displaying_output function: Should always open a window for the output buffer.
---@field log_level number: A vim.log.levels value.

---@type Actions_user_config
local M = {
  log_level = vim.log.levels.INFO,
  actions = {
    ["Example action"] = function()
      return {
        filetypes = { "help" },
        steps = {
          "echo 'Current file: " .. (vim.fn.expand "%:p") .. "'",
        },
      }
    end,
  },
  before_displaying_output = function(bufnr)
    local winid = vim.fn.win_getid(vim.fn.winnr())
    vim.fn.execute("keepjumps vertical sb " .. bufnr, true)
    vim.fn.win_gotoid(winid)
  end,
}
M.__index = M

---Create a default user config
---
---@return Actions_user_config
function M.__default()
  local cfg = {}
  setmetatable(cfg, M)
  return cfg
end

---@param o table
---@return Actions_user_config
---@return string|nil: An error that occured while creating the config
function M.__create(o)
  ---@type Actions_user_config
  local cfg = {}
  setmetatable(cfg, M)

  if type(o) ~= "table" then
    return cfg, "User config should be a table!"
  end
  for key, value in pairs(o) do
    if key == "log_level" then
      if type(value) ~= "number" then
        return cfg, "log_level should be a vim.log.levels value!"
      end
      cfg.log_level = value
    elseif key == "actions" then
      if type(value) ~= "table" then
        return cfg, "actions should be a table!"
      end
      local actions = {}
      for k, v in pairs(value) do
        if type(v) ~= "function" then
          return cfg, "Action's config should be a function!"
        end
        actions[k] = v
      end
      cfg.actions = actions
    elseif key == "before_displaying_output" then
      if type(value) ~= "function" then
        return cfg, "before_displaying_output should be a function!"
      end
      cfg.before_displaying_output = value
    else
      return cfg, "Invalid config field: " .. key
    end
  end
  return cfg, nil
end

---Merge the two provided configs.
---The second is added to the first.
---
---@param o1 Actions_user_config
---@param o2 Actions_user_config
function M.__merge(o1, o2)
  for k, v in pairs(o2) do
    if k == "actions" then
      if o1.actions == nil then
        o1.actions = v
      else
        for k2, v2 in pairs(v) do
          o1.actions[k2] = v2
        end
      end
    else
      o2[k] = v
    end
  end
end

return M

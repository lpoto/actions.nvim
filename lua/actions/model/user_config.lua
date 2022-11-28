local Actions_log_config = require "actions.model.log_config"
local Actions_mappings_config = require "actions.model.mappings_config"

---@tag actions.model.user_config
---@config {["name"] = "USER CONFIG"}

---@brief [[
---Actions_user_config is an object that represents a plugin configuration
---created by the user.
---The config's actions are functions returning |Action| objects, so
---that they may be loaded when requested, which allows actions relative to
---the current context.
---@brief ]]

---@class Actions_user_config
---@field actions table: A table of functions returning |Action| objects.
---@field before_displaying_output function: See |before_displaying_output|.
---@field log Actions_log_config: |Actions_log_config| for the plugin's logger.
---@field mappings Actions_mappings_config: |Actions_mappings_config| for keymaps in the action's windows.

---@type Actions_user_config
local M = {
  log = Actions_log_config.__default(),
  action = {},
  mappings = Actions_mappings_config.__default(),
}
M.__index = M

---This function should always open a window for the provided
---buffer number.
---Default value:
---<code>
---  -- Opens a new vertical window but keeps focus on the current window
---  function()
---    local winid = vim.fn.win_getid(vim.fn.winnr())
---    vim.fn.execute("keepjumps vertical sb " .. bufnr, true)
---    vim.fn.win_gotoid(winid)
---  end
---</code>
---@param bufnr number: The number of the output buffer
function M.before_displaying_output(bufnr)
  -- NOTE: oppen the output window in a vertical
  -- split by default.
  -- NOTE: use keepjumps to no add the output buffer
  -- to the jumplist
  local winid = vim.fn.win_getid(vim.fn.winnr())
  vim.fn.execute("keepjumps vertical sb " .. bufnr, true)
  vim.fn.win_gotoid(winid)
end

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
    if key == "log" then
      local log, e = Actions_log_config.__create(value)
      if e ~= nil then
        return cfg, e
      end
      cfg.log = log
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
    elseif key == "mappings" then
      local v, e = Actions_mappings_config.__create(value)
      if e ~= nil then
        return cfg, e
      end
      cfg.mappings = v
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

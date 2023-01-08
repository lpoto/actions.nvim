local executor = require "actions.executor"
local setup = require "actions.setup"
local enum = require "actions.enum"
local log = require "actions.log"
local output_window = require "actions.window.action_output"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local telescope_actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local previewers = require "telescope.previewers"
local entry_display = require "telescope.pickers.entry_display"

local telescope = {}

---@tag actions.telescope
---@config {["name"] = "TELESCOPE"}
--
---@brief [[
---Actions.nvim allow displaying and managing actions in a telescope
---prompt.
---@brief ]]

local prev_buf = nil
local available_actions_telescope_prompt

---Displays available actions in a telescope prompt.
---In the opened window, the action may be run or killed by
---selecting it with enter. It's output may then be displayed
---with 'o' in normal more or 'Ctrl + o' in insert mode.
---
---You may pass a different theme to the picker.
---
---Example:
---<code>
---  telescope.available_actions(require("telescope.themes").get_dropdown())
---</code>
---
---@param opts table?: options to pass to the picker
function telescope.available_actions(opts)
  available_actions_telescope_prompt(opts)
end

local function quote_string(v)
  if
    type(v) == "string"
    and (string.find(v, "'") or string.find(v, "`") or string.find(v, '"'))
  then
    if string.find(v, "'") == nil then
      v = "'" .. v .. "'"
    elseif string.find(v, '"') == nil then
      v = '"' .. v .. '"'
    elseif string.find(v, "`") == nil then
      v = "`" .. v .. "`"
    end
  end
  return v
end

local function get_action_definition(action)
  local def = {}
  if action.name ~= nil then
    table.insert(def, "name: " .. quote_string(action.name))
  end
  local function generate(tbl, indent)
    if not indent then
      indent = 0
    end
    for k, v in pairs(tbl) do
      if k ~= "name" then
        v = quote_string(v)
        if type(k) == "number" then
          k = "- "
        else
          k = k .. ": "
        end
        local formatting = string.rep("  ", indent) .. k
        if type(v) == "table" then
          table.insert(def, formatting)
          generate(v, indent + 1)
        elseif type(v) == "boolean" then
          table.insert(def, formatting .. tostring(v))
        else
          table.insert(def, formatting .. v)
        end
      end
    end
  end

  generate(action, 0)
  return def
end

local function get_action_display(action)
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 8 },
      { remaining = true },
    },
  }
  if executor.is_running(action.name) then
    return displayer {
      { "Running", "Function" },
      action.name,
    }
  end
  local buf = executor.get_action_output_buf(action.name)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
    return displayer {
      { "Output", "Comment" },
      action.name,
    }
  end
  return displayer {
    { "" },
    action.name,
  }
end

local actions_finder

local function select_action(picker, action)
  if executor.is_running(action.name) == true then
    executor.kill(action.name, prev_buf)
    return
  end

  local function reset_picker()
    vim.defer_fn(function()
      picker:refresh(actions_finder(), { reset_prompt = true })
    end, 60)
  end

  executor.start(action.name, prev_buf, reset_picker)
  reset_picker()
end

local function output_of_action_under_cursor(picker_buf)
  local selection = action_state.get_selected_entry()
  output_window.open(selection.value, function()
    telescope_actions.close(picker_buf)
  end)
end

local function delete_output_of_action_under_cursor(picker_buf)
  local picker = action_state.get_current_picker(picker_buf)
  local selection = action_state.get_selected_entry()
  executor.delete_action_buffer(selection.value.name)
  vim.defer_fn(function()
    picker:refresh(actions_finder(), { reset_prompt = true })
  end, 60)
end

local function attach_picker_mappings()
  return function(prompt_bufnr, map)
    telescope_actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()
      local picker = action_state.get_current_picker(prompt_bufnr)
      select_action(picker, selection.value)
    end)
    for _, mode in ipairs { "i", "n" } do
      map(mode, "<C-o>", function()
        output_of_action_under_cursor(prompt_bufnr)
      end)
      map(mode, "<C-d>", function()
        delete_output_of_action_under_cursor(prompt_bufnr)
      end)
    end
    return true
  end
end

available_actions_telescope_prompt = function(options)
  local cur_buf = vim.fn.bufnr()
  if
    vim.api.nvim_buf_get_option(cur_buf, "buftype") ~= "terminal"
    or vim.api.nvim_buf_get_option(cur_buf, "filetype")
      ~= enum.OUTPUT_BUFFER_FILETYPE
  then
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

  actions_finder = function()
    return finders.new_table {
      results = actions,
      entry_maker = function(entry)
        return {
          value = entry,
          ordinal = entry.name,
          display = function(entry2)
            return get_action_display(entry2.value)
          end,
        }
      end,
    }
  end

  local function actions_previewer()
    return previewers.new {
      teardown = function(self)
        pcall(
          vim.api.nvim_buf_delete,
          telescope.old_preview_buf,
          { force = true }
        )
        local _, winid = pcall(vim.fn.bufwinid, self.state.bufnr)
        self.state.bufnr = nil
        if
          type(winid) ~= "number"
          or winid == -1
          or not vim.api.nvim_win_is_valid(winid)
        then
          return
        end
        local buf = vim.api.nvim_create_buf(false, true)
        pcall(vim.api.nvim_win_set_buf, winid, buf)
      end,
      preview_fn = function(self, entry, status)
        output_window.highlight_added_text(status.preview_win)
        local running_buf = executor.get_action_output_buf(entry.value.name)
        local old_buf = telescope.old_preview_buf
        if running_buf and vim.api.nvim_buf_is_valid(running_buf) then
          vim.api.nvim_win_call(status.preview_win, function()
            vim.api.nvim_win_set_buf(status.preview_win, running_buf)
          end)
        else
          telescope.old_preview_buf = vim.api.nvim_create_buf(false, true)
          pcall(
            vim.api.nvim_buf_set_lines,
            telescope.old_preview_buf,
            0,
            -1,
            false,
            get_action_definition(entry.value)
          )
          pcall(
            vim.api.nvim_buf_set_option,
            telescope.old_preview_buf,
            "filetype",
            "yaml"
          )
          local ok, e = pcall(
            vim.api.nvim_win_set_buf,
            status.preview_win,
            telescope.old_preview_buf
          )
          if ok == false then
            log.error(e)
          end
        end
        if old_buf ~= nil and vim.api.nvim_buf_is_valid(old_buf) then
          vim.api.nvim_buf_delete(old_buf, { force = true })
        end

        self.state = self.state or {}
        self.state.bufnr = vim.api.nvim_win_get_buf(status.preview_win)
      end,
      dynamic_title = function(_, entry)
        local running_buf = executor.get_action_output_buf(entry.value.name)
        if running_buf and vim.api.nvim_buf_is_valid(running_buf) then
          return entry.value.name .. " (output)"
        end
        return entry.value.name .. " (definition)"
      end,
    }
  end

  local function actions_picker(opts)
    opts = opts or {}
    print(vim.inspect(opts))
    pickers
      .new(opts, {
        prompt_title = "Actions",
        results_title = "<CR> - Run/kill , <C-o> - Show output, <C-d> - Delete output",
        finder = actions_finder(),
        sorter = conf.generic_sorter(opts),
        previewer = actions_previewer(),
        dynamic_preview_title = true,
        selection_strategy = "row",
        attach_mappings = attach_picker_mappings(),
      })
      :find()
  end

  actions_picker(options)
end

return telescope

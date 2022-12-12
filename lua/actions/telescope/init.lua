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

local t = {}

local prev_buf = nil
local available_actions_telescope_prompt

function t.available_actions()
  available_actions_telescope_prompt()
end

local function get_action_definition(action)
  local def = {}
  if action.name ~= nil then
    table.insert(def, "name: " .. action.name)
  end
  local function generate(tbl, indent)
    if not indent then
      indent = 0
    end
    for k, v in pairs(tbl) do
      if k ~= "name" then
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
      { width = 0.75 },
      { remaining = true },
    },
  }
  if executor.is_running(action.name) then
    return displayer {
      action.name,
      { "Running", "Function" },
    }
  end
  local buf = executor.get_action_output_buf(action.name)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
    return displayer {
      action.name,
      { "Output", "Comment" },
    }
  end
  return displayer {
    action.name,
  }
end
local function picker_preview()
  return function(self, entry)
    if self.state.bufname then
      return
    end
    vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "yaml")
    vim.api.nvim_buf_set_lines(
      self.state.bufnr,
      0,
      -1,
      false,
      get_action_definition(entry.value)
    )
  end
end

local function select_action(picker, action)
  if executor.is_running(action.name) == true then
    executor.kill(action.name, prev_buf)
    return
  end
  executor.start(action.name, prev_buf, function()
    picker:refresh()
  end)
end

local function output_of_action_under_cursor(picker_buf)
  local selection = action_state.get_selected_entry()
  output_window.open(selection.value, function()
    telescope_actions.close(picker_buf)
  end)
end

local function attach_picker_mappings()
  return function(prompt_bufnr, map)
    telescope_actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()
      local picker = action_state.get_current_picker(prompt_bufnr)
      select_action(picker, selection.value)
      picker:refresh()
    end)
    map("n", "o", function()
      output_of_action_under_cursor(prompt_bufnr)
    end)
    map({ "n", "i" }, "<C-o>", function()
      output_of_action_under_cursor(prompt_bufnr)
    end)
    return true
  end
end

available_actions_telescope_prompt = function()
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

  local function actions_picker(opts)
    opts = opts or {}
    print(vim.inspect(opts))
    pickers
      .new(opts, {
        prompt_title = "Actions",
        finder = finders.new_table {
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
        },
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer {
          title = "Action Preview",

          define_preview = picker_preview(),
        },
        attach_mappings = attach_picker_mappings(),
      })
      :find()
  end

  actions_picker()
end

return t

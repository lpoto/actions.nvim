# actions.nvim

## Installation

With [packer.nvim](https://github.com/wbthomason/packer.nvim):
```lua
use "lpoto/actions.nvim"
```
With [vim.plug](https://github.com/junegunn/vim-plug)
```vim
Plug "lpoto/actions.nvim"
```

## Setup
```lua
require("actions").setup {
  log = {
    level = vim.log.levels.WARN, -- default: INFO
    silent = false, -- default: false, when true, actions logging is disabled
    prefix = "Custom-Prefix", -- default: "Actions.nvim"
  },
  actions = {
    example_action = {
      filetypes = {}, -- a list of filetypes in which the action is available (optional)
      patterns = {}, -- a list of patterns, action is only available in files that match a pattern (optional)
      cwd = "<valid-directory-path>", -- A directory in which the action will run (optinal)
      env = {}, -- A table of env. variables with their names as keys (optional)
      clear_env = false, -- When this is true, env. variables not in `env` field will be removed for this action (optinal)
      steps = { 
      -- Each action should have at least one step
      -- Steps will be run one after another in order, as separate jobs
        name = "example_step_name",
        cwd = "<valid-directory-path>", -- this overrides the action's cwd for this step (optional)
        env = {}, -- a list of env. variables for this step (merged with action's env unless step's clear_env is true) (optional)
        clear_env = false, -- This overrides the action's clear_env when not nil (optional)
        exe = "command", -- command passed to the job (when `args` field has a value, this should be an executable)
        args = {}, -- A table of arguments added to `exe` (optional)
        -- NOTE: example: command could be defined as `exe="echo 'Hello world!'"` or `exe="echo", args={"'Hello world!'"}`
      }
    },
    before_displaying_output = function(bufnr)
      -- Example: to display the ouput of an action in a vertical split
      -- instead of in the current buffer.
      vim.cmd('silent vsplit')
      -- Could also add remappings for the output buffer here etc.
      -- Example: Kill action running in the output buffer with CTRL + c
      vim.api.nvim_buf_set_keymap(
        bufnr,
        "n",
        "<C-c>",
        "<CMD>lua require('actions.executor').kill(vim.fn.expand('%:t:r'))<CR>",
        {}
      )
    end
  }
}
```

## Usage

### Open a window with available actions for the current file:
```lua
require('actions').open()
```
In this window actions may be started, killed, or their outputs displayed (in a different window).

### Toggle the last oppened output window:
```lua
require('actions').toggle_last_output()
```
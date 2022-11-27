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
  mappings = {
    available_actions = {
        run_kill = "<Enter>", -- <Enter> is default
        show_output = "o", -- o is default
        show_definition = "d", -- d is default
    }
  },
  actions = {
    -- NOTE: action configs are functions that are called when running the actions
    -- this is useful for creating actions with fields relative to the oppened file
    example_action = function()
      return {
        filetypes = {}, -- a list of filetypes in which the action is available (optional)
        patterns = {}, -- a list of lua patterns, action is only available in files that match a pattern (optional)
        cwd = "<valid-directory-path>", -- A directory in which the action will run (optional)
        env = {}, -- A table of env. variables with their names as keys (optional)
        clear_env = false, -- When this is true, env. variables not in `env` field will be removed for this action (optional)
        steps = {
          -- Each action should have at least one step.
          -- Steps should be strings or tables of strings
          -- Examples:
          "echo 'hello world!'", -- step 1
          {"echo", "'hello world again!'"} -- step 2
        }
      }
    end
  },
  before_displaying_output = function(bufnr)
    -- This function should always open a window for the provided bufnr
    -- (the number of the action's output buffer),
    -- if this function is not defined, the default is used:
    local winid = vim.fn.win_getid(vim.fn.winnr())
    vim.fn.execute("keepjumps vertical sb " .. buf, true)
    vim.fn.win_gotoid(winid)
  end
}
```

## Usage

### Open a window with available actions for the current file:

```lua
require('actions').available_actions()
```

In this window actions may be started, killed, or their outputs displayed (in a different window).

### Toggle the last oppened output window:

```lua
require('actions').toggle_last_output()
```

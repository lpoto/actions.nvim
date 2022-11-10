local Action = require "actions.model.action"
local log = require "actions.log"

local clean = {}

---Clean the output directory, if name is provided
---clean only the file that belongs to the action identified
---by the provided name.
---
---@param name string?: Name of an action
function clean.clean(name)
  local dir = Action.output_dir
  print(dir)
  if name == nil then
    local ok, e = pcall(vim.fn.delete, dir, "rf")
    if ok == false then
      log.warn(e)
    end
    return
  end
  local path = dir .. "/" .. name .. ".out"
  local ok, e = pcall(vim.fn.delete, path)
  if ok == false then
    log.warn(e)
  end
end

return clean

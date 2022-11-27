---@class Available_actions_mappings_config
---@field run_kill string: (default: "<Enter>")
---@field show_output string: (default: "o")
---@field show_definition string: (default: "d")
local Available_actions_mappings_config = {
  run_kill = "<Enter>",
  show_output = "o",
  show_definition = "d",
}
Available_actions_mappings_config.__index = Available_actions_mappings_config

---Create a default available actions mappings config
---
---@return Available_actions_mappings_config
function Available_actions_mappings_config.__default()
  ---@type Available_actions_mappings_config
  local cfg = {}
  setmetatable(cfg, Available_actions_mappings_config)
  return cfg
end

---@param o table
---@return Available_actions_mappings_config
---@return string|nil: An error that occured while creating the config
function Available_actions_mappings_config.__create(o)
  ---@type Available_actions_mappings_config
  local cfg = Available_actions_mappings_config.__default()
  if type(o) ~= "table" then
    return cfg, "Available actions mappings config should be a table!"
  end
  for key, value in pairs(o) do
    if type(value) ~= "string" then
      return cfg, "'" .. key .. "' should be a string!"
    end
    if key == "run_kill" then
      cfg.run_kill = value
    elseif key == "show_output" then
      cfg.show_output = value
    elseif key == "show_definition" then
      cfg.show_definition = value
    else
      return cfg, "Invalid config field: " .. key
    end
  end
  return cfg, nil
end

---@class Mappings_config
---@field available_actions Available_actions_mappings_config
---@see Available_actions_mappings_config
local Mappings_config = {
  available_actions = Available_actions_mappings_config.__default(),
}
Mappings_config.__index = Mappings_config

---Create a default mappings config
---
---@return  Mappings_config
function Mappings_config.__default()
  ---@type Mappings_config
  local cfg = {}
  setmetatable(cfg, Mappings_config)
  return cfg
end

---@param o table
---@return Mappings_config
---@return string|nil: An error that occured while creating the config
function Mappings_config.__create(o)
  ---@type Mappings_config
  local cfg = Mappings_config.__default()
  if type(o) ~= "table" then
    return cfg, "Mappings config should be a table!"
  end
  for key, value in pairs(o) do
    if key == "available_actions" then
      local a, e = Available_actions_mappings_config.__create(value)
      if e ~= nil then
        return cfg, e
      end
      cfg.available_actions = a
    else
      return cfg, "Invalid config field: " .. key
    end
  end
  return cfg, nil
end

return Mappings_config

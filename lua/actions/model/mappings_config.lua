---@tag actions.model.mappings_config
---@config {["name"] = "ACTIONS MAPPING CONFIG"}

---@brief [[
---Actions_mappings_config is a table of keymaps used in normal
---mode in the plugin's windows.
---@brief ]]

---@class Actions_mappings_config
---@field run_kill string: Run or kill the action under the cursor in available actions window (default: "<Enter>")
---@field show_output string: Show output of the action under the cursor (default: "o")
---@field show_definition string: Show definition of the action under the cursor (default: "d")

---@type Actions_mappings_config
local Actions_mappings_config = {
  run_kill = "<Enter>",
  show_output = "o",
  show_definition = "d",
}
Actions_mappings_config.__index = Actions_mappings_config

---Create a default mappings config
---
---@return  Actions_mappings_config
function Actions_mappings_config.__default()
  ---@type Actions_mappings_config
  local cfg = {}
  setmetatable(cfg, Actions_mappings_config)
  return cfg
end

---@param o table
---@return Actions_mappings_config
---@return string|nil: An error that occured while creating the config
function Actions_mappings_config.__create(o)
  ---@type Actions_mappings_config
  local cfg = Actions_mappings_config.__default()
  if type(o) ~= "table" then
    return cfg, "Mappings config should be a table!"
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

return Actions_mappings_config

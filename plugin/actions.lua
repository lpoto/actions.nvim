if 1 ~= vim.fn.has "nvim-0.7.0" then
  vim.notify(
    "Actions.nvim: requires at least nvim-0.7.0",
    vim.log.levels.ERROR
  )
  return
end

if vim.g.loaded_actions_nvim == 1 then
  return
end
vim.g.loaded_actions_nvim = 1

vim.api.nvim_create_augroup(
  require("actions.enum").ACTIONS_AUGROUP,
  { clear = true }
)

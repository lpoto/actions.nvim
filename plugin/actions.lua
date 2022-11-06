if 1 ~= vim.fn.has "nvim-0.7.0" then
  vim.api.nvim_err_writeln "actions.nvim requires at least nvim-0.7.0"
  return
end

if vim.g.loaded_actions_nvim == 1 then
  return
end
vim.g.loaded_actions_nvim = 1

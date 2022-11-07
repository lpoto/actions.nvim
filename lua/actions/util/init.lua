local util = {}

---Open a file in the provided path
---If it does not already exist, it creates it and
---all the missing directories in the path.
---
---@param path string: full path to the file
---@param mode "r"|"w"|"a": Mode with which to open the file
---@return file*|nil: file oppened for writing
function util.open_file(path, mode)
  if vim.fn.filereadable(path) == 1 then
    return io.open(path, mode)
  end
  local parent_dir = vim.fs.dirname(path)
  local ok, v = pcall(vim.fs.dir(parent_dir))
  if ok == false or v == nil then
    ok, v = pcall(vim.fn.mkdir, parent_dir, "p")
    if ok == false or v ~= 1 then
      return nil
    end
  end
  return io.open(path, mode)
end

return util

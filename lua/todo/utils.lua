local M = {}

--- Clears all TODOs from the target file and resets it to the default
--- file content.
---@param config todo-nvim.Config
function M.clear(config)
  local file = io.open(config.todo_file, "w+")
  if not file then
    vim.notify("todo.nvim: unable to clear file: " .. config.todo_file, vim.log.levels.ERROR)
    return
  end
  file:write("# TODOs\n")
  file:close()

  vim.notify("todo.nvim: TODOs cleared!", vim.log.levels.INFO)
end

return M

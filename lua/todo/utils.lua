local M = {}

--- Expands paths starting with `~` to the fully expanded path, substituting
--- `~` if present with `$HOME`
---@param path string the filepath with potential `~`
---@return string the fully expanded path without `~`
function M.expand_path(path)
  if path:sub(1, 1) == "~" then
    return os.getenv("HOME") .. path:sub(2)
  end
  return path
end

--- Creates a new starter todo file at the given filepath
---@param filepath string file to write
function M.create_new_todo_file(filepath)
  local file = io.open(filepath, "w")
  if file == nil then
    vim.notify("Unable to create todo-nvim file, quiting...")
    return
  end
  -- setup with a basic to-do list to start
  file:write("# TODOS\n\n")
  file:write("- [ ] my first todo")
  file:close()
end

--- Parses the given file and returns all todo items
---@param filepath string expanded path to the todo file
---@return todo-nvim.TodoItem[]
function M.parse_todos(filepath)
  local file = io.open(filepath, "r")
  local todos = {}

  if file == nil then
    vim.notify("todo.nvim: unable to open todo file, quitting...", vim.log.levels.ERROR)
    return todos
  end

  -- pattern match over the lines to retrieve the todos
  for line in file:lines() do
    local completed = string.match(line, "%- %[x%]") ~= nil
    local desc = string.match(line, "%- %[[x ]%] (.+)")

    if desc then
      ---@type todo-nvim.TodoItem
      local todo = {
        desc = desc,
        completed = completed,
      }
      table.insert(todos, todo)
    end
  end

  return todos
end

--- Creates a window and scratch buffer with the given configuration
---@param win_opts vim.api.keyset.win_config
---@param enter? boolean whether to enter the created window
---@return table
function M.create_floating_scratch_window(win_opts, enter)
  if enter == nil then
    enter = false
  end

  local buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
  local win = vim.api.nvim_open_win(buf, enter or false, win_opts)

  return { buf = buf, win = win }
end

return M

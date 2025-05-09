local utils = require("todo.utils")

local M = {}

--- Default configurations
---@type todo-nvim.Config
local config = {
  border = "rounded",
  todo_file = vim.fn.stdpath("data") .. "/todos.md",
  -- TODO: additional configuration options
  -- remove_completed = false,
  -- save_on_exit = true,
}

--- Creates the window configurations for the floating TODO menu(s)
---@return table <string, vim.api.keyset.win_config> window configurations
local function create_todo_menu_win_configs()
  local width = math.min(math.floor(vim.o.columns * 0.8), 64)
  local height = math.floor(vim.o.lines * 0.8)

  -- Calculate the centered row and col values for the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    menu = {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      border = config.border,
    },
  }
end

--- Opens a floating buffer for the specified file, creating it if it does not
--- exists.
function M.open()
  local target_file = config.todo_file
  local expanded_path = utils.expand_path(target_file)

  -- check if the file can be read
  if vim.fn.filereadable(expanded_path) == 0 then
    vim.notify("todo: todo_file does not exist: " .. target_file .. "\nCreating...", vim.log.levels.INFO)
    -- create a new file instead
    utils.create_new_todo_file(expanded_path)
  end

  -- create a new buffer for the file
  local buf = vim.fn.bufnr(expanded_path, true)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, expanded_path)
  end

  local win_configs = create_todo_menu_win_configs()

  -- treat as Markdown file regardless and disable swapfiles
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].swapfile = false

  -- open the buffer
  local win = vim.api.nvim_open_win(buf, true, win_configs.menu)

  -- local keymappings for TODO file
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      if vim.api.nvim_get_option_value("modified", {
        buf = buf,
      }) then
        vim.notify("todo.nvim: unsaved changes", vim.log.levels.WARN)
      else
        vim.api.nvim_win_close(0, true)
      end
    end,
  })

  -- add auto command to responsive layout
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("todo-resized", {}),
    callback = function()
      if not vim.api.nvim_buf_is_valid(buf) or win == nil then
        return
      end
      local updated_configs = create_todo_menu_win_configs()
      vim.api.nvim_win_set_config(win, updated_configs.menu)
    end,
  })
end

--- Add a variable number of todo items
---@param item string the description of the todo item to add
function M.add(item)
  -- some defensive checking
  if item == "" or item == nil then
    vim.notify("todo.nvim: No TODO item(s) specified.", vim.log.levels.ERROR)
    return
  end

  local file = io.open(config.todo_file, "a")
  if file == nil then
    vim.notify("todo.nvim: unable to open todo file" .. config.todo_file, vim.log.levels.ERROR)
    return
  end

  file:write("- [ ] " .. item .. "\n")
  file:close()
  vim.notify("todo.nvim: added " .. item, vim.log.levels.INFO)
end

---Prints the current todos, filtering on state if provided
---@param state? '"completed"' | '"undone"' | '"all"' Optional state filter
function M.show(state)
  state = state or "all"
  local fp = utils.expand_path(config.todo_file)
  local todos = utils.parse_todos(fp)

  for _, value in ipairs(todos) do
    if state == "completed" and not value.completed then
      -- skip
    elseif state == "undone" and value.completed then
      -- skip
    else
      print(value.desc)
    end
  end
end

--- Clears all TODOs from the target file and resets it to the default
--- file content.
function M.clear()
  local file = io.open(config.todo_file, "w+")
  if not file then
    vim.notify("todo.nvim: unable to clear file: " .. config.todo_file, vim.log.levels.ERROR)
    return
  end
  file:write("# TODOs\n\n")
  file:write("- [ ] ")

  file:close()

  vim.notify("todo.nvim: TODOs cleared!", vim.log.levels.INFO)
end

--- Initializes terminal commands and completions.
local function init_terminal_cmds()
  -- Terminal commands
  vim.api.nvim_create_user_command("Todo", function(args)
    local sub = args.fargs[1]
    if not sub or sub == "open" then
      M.open()
    elseif sub == "clear" then
      M.clear()
    elseif sub == "show" then
      M.show(args.fargs[2])
    elseif sub == "add" then
      local item = vim.fn.input("Todo item: ", "")
      M.add(item)
    else
      vim.notify("todo.nvim: Unknown subcommand: " .. sub, vim.log.levels.WARN)
    end
  end, {
    nargs = "*",
    complete = function(_, line)
      local args = vim.split(line, "%s+")
      if #args == 2 then
        return { "open", "add", "show", "clear" }
      end
      if #args > 2 and args[2] == "show" then
        return { "all", "completed", "undone" }
      end
    end,
  })
end

--- Initializes the plugin with any user-provided overrides, if any.
---@param opts todo-nvim.Config?
M.setup = function(opts)
  opts = opts or {}

  -- override defaults
  config = vim.tbl_deep_extend("force", config, opts)

  init_terminal_cmds()
end

return M

local M = {}

--- Default configurations
---@type todo-nvim.Config
local config = {
  border = "rounded",
  todo_file = vim.fn.stdpath("data") .. "/todos.md",
}

--- Expands paths starting with `~` to the fully expanded path, substituting
--- `~` if present with `$HOME`
---@param path string the filepath with potential `~`
---@return string the fully expanded path without `~`
local function expand_path(path)
  if path:sub(1, 1) == "~" then
    return os.getenv("HOME") .. path:sub(2)
  end
  return path
end

--- Creates the window configuration (`vim.api.nvim_open_win(.., **config**)`)
---@param opts table Optional configuration settings for the window
---@return vim.api.keyset.win_config
local function create_win_config(opts)
  opts = opts or {}
  local width = math.min(math.floor(vim.o.columns * 0.8), 64)
  local height = math.floor(vim.o.lines * 0.8)

  -- Calculate the centered row and col values for the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    border = config.border,
  }
end

--- Opens a floating buffer for the specified file, creating it if it does not
--- exists.
--- @param target_file string filepath to the Markdown file to store TODOs
local function create_floating_window(target_file)
  local expanded_path = expand_path(target_file)

  -- check the filetype of the provided file
  -- local ft = require("plenary.filetype").detect(expanded_path, {})
  -- if ft ~= "markdown" then
  --   vim.notify("todo.nvim: specified filetype is not Markdown: " .. expanded_path, vim.log.levels.ERROR)
  --   return
  -- end

  if vim.fn.filereadable(expanded_path) == 0 then
    vim.notify("todo: target_file does not exist: " .. target_file .. "\nCreating...", vim.log.levels.INFO)

    -- create a new file instead
    local file = io.open(expanded_path, "w")

    if file == nil then
      vim.notify("Unable to create todo-nvim file, quiting...")
      return
    end

    file:write("- [ ] my first todo")
    file:close()
  end

  local buf = vim.fn.bufnr(expanded_path, true)

  -- create buffer manually if not created
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, expanded_path)
  end

  -- disable swap file on the buffer
  vim.bo[buf].swapfile = false

  local win = vim.api.nvim_open_win(buf, true, create_win_config({}))

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
end

--- Initializes the user's configuration options, if any
local function init_user_commands()
  local todo_file = config.todo_file

  -- Terminal commands
  vim.api.nvim_create_user_command("Todo", function(args)
    local sub = args.fargs[1]
    if not sub then
      create_floating_window(todo_file)
    elseif sub == "clear" then
      require("todo.utils").clear(config)
    else
      vim.notify("todo.nvim: Unknown subcommand: " .. sub, vim.log.levels.WARN)
    end
  end, {
    nargs = "*",
    complete = function()
      return { "clear" }
    end,
  })
end

--- Initializes the plugin with any user-provided overrides, if any.
---@param opts todo-nvim.Config?
M.setup = function(opts)
  opts = opts or {}

  -- override defaults
  config = vim.tbl_deep_extend("force", config, opts)

  init_user_commands()

  -- Lua API
  M.open = function()
    create_floating_window(config.todo_file)
  end

  M.clear = function()
    require("todo.utils").clear(config)
  end
end

return M

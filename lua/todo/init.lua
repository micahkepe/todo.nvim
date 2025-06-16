local utils = require("todo.utils")

local M = {}

--- State management for created windows and buffers
local state = {
  floats = setmetatable({}, {
    __index = function()
      return { win = nil, buf = nil }
    end,
  }),
}

--- Second-order function to apply a callback function to each float
---@param callback function
local foreach_float = function(callback)
  for name, float in pairs(state.floats) do
    callback(name, float)
  end
end

--- Default configurations
---@type todo-nvim.Config
local config = {
  border = "rounded",
  todo_file = vim.fn.stdpath("data") .. "/todos.md",
  todo_title = "TODOs",
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
    body = {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      border = config.border,
    },
    -- add additional windows configs here
  }
end

--- Toggle a floating buffer for the specified file, creating it if it does not
--- exists.
function M.toggle()
  -- if existing menu exists, toggle it closed
  if state.floats.body.win ~= nil and vim.api.nvim_win_is_valid(state.floats.body.win) then
    foreach_float(function(_, float)
      pcall(vim.api.nvim_win_close, float.win, true)
    end)
    -- close body buffer as well
    if vim.api.nvim_buf_is_valid(state.floats.body.buf) then
      vim.api.nvim_buf_delete(state.floats.body.buf, {})
    end
    return
  end

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

  -- open the buffer
  local win = vim.api.nvim_open_win(buf, true, win_configs.body)
  state.floats.body = { win = win, buf = buf }

  -- disable swap files
  foreach_float(function(_, float)
    vim.bo[float.buf].swapfile = false
    vim.bo[float.buf].filetype = "markdown"
  end)

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
        foreach_float(function(_, float)
          pcall(vim.api.nvim_win_close, float.win, true)
        end)
        -- delete the created buffer as well so that it doesn't pollute
        -- buffer tabs
        vim.api.nvim_buf_delete(buf, {})
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
      foreach_float(function(name, _)
        vim.api.nvim_win_set_config(state.floats[name].win, updated_configs[name])
      end)
    end,
  })

  -- close all floats on BufLeave
  vim.api.nvim_create_autocmd("BufLeave", {
    group = vim.api.nvim_create_augroup("todo-menu-left", {}),
    callback = function()
      foreach_float(function(_, float)
        pcall(vim.api.nvim_win_close, float.win, true)
      end)
    end,
  })
end

--- Adds a todo section for the current day (MM-DD-YYYY) at the top of the todo
--- file below the title, if it exists
function M.today()
  local filepath = utils.expand_path(config.todo_file)

  -- Check if file exists, create it if it doesn't
  if vim.fn.filereadable(filepath) == 0 then
    vim.notify("todo.nvim: todo_file does not exist: " .. config.todo_file .. "\nCreating...", vim.log.levels.INFO)
    utils.create_new_todo_file(filepath)
    return
  end

  local contents = utils.read_file(filepath)
  if contents == nil then
    vim.notify("todo.nvim: unable to read todo file " .. config.todo_file, vim.log.levels.ERROR)
    return
  end

  local date = os.date("%m-%d-%Y")
  local section_header = string.format("## %s", date)

  ---@diagnostic disable-next-line: param-type-mismatch
  local section_pattern = "## " .. date:gsub("%-", "%%-") -- Escape hyphens in the date
  if contents:match(section_pattern) then
    vim.notify(string.format("todo.nvim: section for %s already exists", date), vim.log.levels.INFO)
    return
  end

  -- Add empty todo item
  local today_section = section_header .. "\n\n- [ ] "

  -- Insert the section after the title, if it exists
  local title_pattern = "^# .-\n"
  local title_match = contents:match(title_pattern)
  if not title_match then
    -- If no title is found, can add directly to beginning of file
    local file = io.open(filepath, "w")
    if not file then
      vim.notify("todo.nvim: unable to open todo file for writing: " .. config.todo_file, vim.log.levels.ERROR)
      return
    end
    local updated_content = today_section .. "\n\n" .. contents
    file:write(updated_content)
    file:close()
  else
    local title_end = contents:find("\n", contents:find(title_pattern)) or 0
    local updated_content = contents:sub(1, title_end) .. "\n" .. today_section .. "\n" .. contents:sub(title_end + 1)

    -- Write the modified content back to the file
    local file = io.open(filepath, "w")
    if not file then
      vim.notify("todo.nvim: unable to open todo file for writing: " .. config.todo_file, vim.log.levels.ERROR)
      return
    end

    file:write(updated_content)
    file:close()
  end

  vim.notify(string.format("todo.nvim: added section for %s", date), vim.log.levels.INFO)
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
  vim.notify(string.format("todo.nvim: added '%s'", item), vim.log.levels.INFO)
end

--- Remove the item matching the description from the todo list
---@param desc string the description of the item to remove
function M.remove(desc)
  if desc == "" or desc == nil then
    vim.notify("todo.nvim: no item to remove specified")
    return
  end

  utils.remove_todo(config.todo_file, desc)
end

---Prints the current todos, filtering on state if provided
---@param progress? '"completed"' | '"incomplete"' | '"all"' Optional state filter
function M.list(progress)
  progress = progress or "all"
  local fp = utils.expand_path(config.todo_file)
  local todos = utils.parse_todos(fp)

  -- rust mind go brr
  local todo_descs = vim
    .iter(todos)
    :filter(function(todo)
      return (progress == "all")
        or (progress == "completed" and todo.completed)
        or (progress == "incomplete" and not todo.completed)
    end)
    :map(function(todo)
      if todo.completed then
        return "- ✅ " .. todo.desc
      else
        return "- ❌ " .. todo.desc
      end
    end)
    :totable()

  if #todo_descs == 0 then
    local msg = string.format("todo.nvim: no items found for '%s'", progress)
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local msg = table.concat(todo_descs, "\n")
  vim.notify(msg, vim.log.levels.INFO)
end

--- Mark the todo item of the given description as complete
---@param description string the description of the todo item
function M.complete(description)
  if description == "" or description == nil then
    vim.notify("todo.nvim: no item provided to complete", vim.log.levels.ERROR)
    return
  end

  local filepath = utils.expand_path(config.todo_file)
  local file = io.open(filepath, "r")
  if not file then
    vim.notify("todo.nvim: unable to open todo file: " .. filepath, vim.log.levels.ERROR)
    return
  end

  local lines = {}
  local marked = false
  local pattern = "%- %[ %] " .. vim.pesc(description) .. "$"

  for line in file:lines() do
    if not marked and string.match(line, pattern) then
      -- mark the line as done
      line = string.gsub(line, "%- %[ %]", "- [x]")
      marked = true
    end
    table.insert(lines, line)
  end
  file:close()

  -- write updated contents
  file = assert(io.open(filepath, "w"))
  for _, line in ipairs(lines) do
    file:write(line .. "\n")
  end
  file:close()

  if not marked then
    local msg = string.format("todo.nvim: unable to find item to mark: '%s'", description)
    vim.notify(msg, vim.log.levels.WARN)
  else
    local msg = string.format("todo.nvim: Marked complete: '%s'", description)
    vim.notify(msg, vim.log.levels.INFO)
  end
end

--- Clears all TODOs from the target file and resets it to the default
--- file content.
function M.reset()
  local file = io.open(config.todo_file, "w+")
  if not file then
    vim.notify("todo.nvim: unable to clear file: " .. config.todo_file, vim.log.levels.ERROR)
    return
  end

  local todo_title = string.format("# %s\n\n", config.todo_title)
  file:write(todo_title)
  file:close()
  vim.notify("todo.nvim: TODOs cleared!", vim.log.levels.INFO)
end

--- Initializes terminal commands and completions.
local function init_terminal_cmds()
  -- Terminal commands
  vim.api.nvim_create_user_command("Todo", function(args)
    local sub = args.fargs[1]
    if not sub then
      M.toggle()
    elseif sub == "Today" then
      M.today()
    elseif sub == "reset" then
      M.reset()
    elseif sub == "list" then
      M.list(args.fargs[2])
    elseif sub == "add" then
      M.add(table.concat(vim.list_slice(args.fargs, 2), " "))
    elseif sub == "remove" then
      M.remove(table.concat(vim.list_slice(args.fargs, 2), " "))
    elseif sub == "complete" then
      M.complete(table.concat(vim.list_slice(args.fargs, 2), " "))
    else
      vim.notify("todo.nvim: Unknown subcommand: " .. sub, vim.log.levels.WARN)
    end
  end, {
    nargs = "*",
    -- generate completion options for commands
    complete = function(_, line)
      local args = vim.split(line, "%s+")
      if #args == 2 then
        return { "Today", "add", "complete", "remove", "list", "reset" }
      end
      if #args > 2 then
        if args[2] == "list" then
          return { "all", "completed", "incomplete" }
        elseif args[2] == "remove" then
          local todos = utils.parse_todos(config.todo_file)
          local suggested = {}
          for _, todo in ipairs(todos) do
            table.insert(suggested, todo.desc)
          end
          return suggested
        elseif args[2] == "complete" then
          return vim
            .iter(utils.parse_todos(config.todo_file))
            :filter(function(todo)
              return not todo.completed
            end)
            :map(function(todo)
              return todo.desc
            end)
            :totable()
        end
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

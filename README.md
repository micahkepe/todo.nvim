# `todo.nvim` 📔

A minimal TODO scratch buffer for jotting down quick notes.

<div align="center">
    <img src="./images/todo-screenshot.png" alt="Screenshot of open TODO buffer"
        width="80%">
</div>

## 📦 Installation

**[lazy.nvim](https://github.com/folke/lazy.nvim)**:

```lua
{
    "micahkepe/todo.nvim",
    lazy = false,
    ---@type todo-nvim.Config
    opts = {
        -- optional default overrides here
    }

    -- Optionally, uncomment the following to set `<leader>td` to open the
    -- buffer
    -- keys = {
    --   { "<leader>td", ":Todo<CR>", mode = "n", { desc = "Open Todos scratch file" },
    --   },
    -- },
}
```

## ⚙️ Configuration

Default configuration:

```lua
---@class todo-nvim.Config
---@field todo_file string the path to the file to modify
---@alias border string
---| '"rounded"' # Like 'single' but with rounded corners
---| '"single"' # Single line box
---| '"double"' # Double line box
---| '"solid"' # Adds padding by a single whitespace cell
---| '"none"' # No border
---| '"shadow"' # Drop shadow effect with background

--- Default configurations
---@type todo-nvim.Config
local config = {
  border = "rounded",
  todo_file = vim.fn.stdpath("data") .. "/todos.md",
}
```

## ✍️ Usage

<center>

| Command       | Description                    |
| ------------- | ------------------------------ |
| `:Todo`       | Opens your TODO buffer         |
| `:Todo clear` | Clears all TODOs from the file |
| `q`           | Close the TODO buffer          |

</center>

## 🗺️ TODOs

- [x] Floating window for TODO file
- [x] Clear/reset TODOs
- [ ] Enhanced buffer styling + advanced configuration options
- [ ] Add new items from the command line
- [ ] Mark as done/ archive
- [ ] Testing

---

## Contributing

Pull requests welcome! If you have a feature or suggestion, feel free to open
an issue or a pull request, I would be happy to review and merge any
contributions.

---

## License

This repository is licensed under the MIT License. See [LICENSE](./LICENSE) for
more details.

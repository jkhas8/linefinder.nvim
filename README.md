# linefinder.nvim

A fast, zero-dependency Neovim plugin for searching and jumping to lines in the current buffer. Type a keyword, fuzzy-filter lines in real-time, and jump to the selected line on Enter.

![Neovim](https://img.shields.io/badge/Neovim-0.7%2B-green?logo=neovim)

## Features

- **Fuzzy matching** — characters matched in order, not necessarily adjacent (like fzf)
- **Multi-token search** — split query by spaces, tokens matched independently in any order
- **Smart scoring** — exact substring matches rank above fuzzy matches; earlier tokens have higher priority
- **Per-character highlighting** — each matched character is highlighted individually
- **Floating window UI** — centered input + results window with rounded borders
- **Zero dependencies** — pure Lua, no external tools required

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jkhas8/linefinder.nvim",
  keys = {
    { "<leader>fl", "<cmd>LineFinder<cr>", desc = "LineFinder" },
  },
}
```

### Local development

```lua
{
  dir = "~/path/to/linefinder.nvim",
  keys = {
    { "<leader>fl", "<cmd>LineFinder<cr>", desc = "LineFinder" },
  },
}
```

## Usage

Open LineFinder with `:LineFinder` or your configured keymap.

| Key | Action |
|-----|--------|
| Type text | Fuzzy-filter lines in real-time |
| `<CR>` | Jump to selected line |
| `<Esc>` | Close without jumping |
| `<C-j>` / `<Down>` | Move selection down |
| `<C-k>` / `<Up>` | Move selection up |

### Search examples

| Query | Matches |
|-------|---------|
| `flt` | Lines containing `f...l...t` in order (e.g., "filter") |
| `split token` | Lines containing both "split" and "token" in any order |
| `fn open` | Lines containing both "fn" and "open" in any order |

## API

```lua
-- Open the finder
require("linefinder").open()

-- Setup (optional, reserved for future config)
require("linefinder").setup({})
```

## License

MIT

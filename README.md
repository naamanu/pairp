# pairp

A Neovim plugin that embeds [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a floating terminal window.

## Requirements

- Neovim >= 0.10
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and available in your PATH

## Installation

### lazy.nvim

```lua
{
  "naamanu/pairp",
  config = function()
    require("pairp").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "naamanu/pairp",
  config = function()
    require("pairp").setup()
  end,
}
```

## Configuration

All options with their defaults:

```lua
require("pairp").setup({
  keymap = "<leader>cc",       -- toggle the chat window
  send_keymap = "<leader>cs",  -- send visual selection to Claude
  context_keymap = "<leader>cx", -- send current file path as context
  cli_path = "claude",         -- path to the Claude Code CLI
  position = "right",          -- "right", "left", "center", "top", "bottom"
  width = 0.4,                 -- width as a fraction of the editor (0.0 - 1.0)
  height = 0.8,                -- height as a fraction of the editor (0.0 - 1.0)
})
```

## Usage

### Commands

| Command | Description |
|---|---|
| `:Pairp [session]` | Toggle the Claude Code window (optional named session) |
| `:'<,'>PairpSend [session]` | Send visual selection to the running Claude session |
| `:PairpContext [session]` | Send the current file path to Claude as context |

### Keymaps

| Key | Mode | Description |
|---|---|---|
| `<leader>cc` | Normal | Toggle Claude Code window |
| `<leader>cs` | Visual | Send selection to Claude |
| `<leader>cx` | Normal | Send current file path as context |
| `q` | Normal (in Pairp window) | Hide the window (keeps session alive) |
| `<Esc><Esc>` | Terminal (in Pairp window) | Exit terminal mode |

### Named Sessions

You can run multiple Claude sessions in parallel:

```vim
:Pairp debug
:Pairp refactor
```

### Health Check

Verify your setup:

```vim
:checkhealth pairp
```

## License

MIT

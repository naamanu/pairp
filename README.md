# pairp

A Neovim plugin that embeds [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a styled floating terminal window.

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
  keymap = "<leader>cc",         -- toggle the chat window
  send_keymap = "<leader>cs",    -- send visual selection to Claude
  context_keymap = "<leader>cx", -- send current file path as context
  cli_path = "claude",           -- path to the Claude Code CLI
  position = "right",            -- "right", "left", "center", "top", "bottom"
  width = 0.4,                   -- width as a fraction of the editor (0.0 - 1.0)
  height = 0.8,                  -- height as a fraction of the editor (0.0 - 1.0)
})
```

### Custom Highlights

Pairp defines highlight groups you can override in your colorscheme:

| Highlight Group | Default Link | Used For |
|---|---|---|
| `PairpBorder` | `FloatBorder` | Window border |
| `PairpTitle` | `Title` | Window title |
| `PairpFooter` | `Comment` | Keybinding hints in footer |
| `PairpNormal` | `NormalFloat` | Window background |

Example:

```lua
vim.api.nvim_set_hl(0, "PairpBorder", { fg = "#7aa2f7" })
vim.api.nvim_set_hl(0, "PairpTitle", { fg = "#bb9af7", bold = true })
```

## Usage

### Commands

| Command | Description |
|---|---|
| `:Pairp [session]` | Toggle the Claude Code window (optional named session) |
| `:'<,'>PairpSend [session]` | Send visual selection to the running Claude session |
| `:PairpSendFile [session]` | Send the entire current buffer to Claude |
| `:PairpContext [session]` | Send the current file path to Claude as context |
| `:PairpList` | List all active sessions |
| `:PairpClose [session]` | Kill a session and its terminal |

All commands that accept `[session]` support tab-completion of active session names.

### Keymaps

| Key | Mode | Description |
|---|---|---|
| `<leader>cc` | Normal | Toggle Claude Code window |
| `<leader>cs` | Visual | Send selection to Claude |
| `<leader>cx` | Normal | Send current file path as context |
| `q` | Normal (in Pairp window) | Hide the window (keeps session alive) |
| `<C-q>` | Terminal (in Pairp window) | Hide the window from terminal mode |
| `<Esc><Esc>` | Terminal (in Pairp window) | Exit terminal mode |
| `<C-w>h/j/k/l` | Terminal (in Pairp window) | Navigate to adjacent editor windows |

### Named Sessions

Run multiple Claude sessions in parallel:

```vim
:Pairp debug
:Pairp refactor
:PairpList
:PairpClose debug
```

### Health Check

Verify your setup:

```vim
:checkhealth pairp
```

## License

[MIT](LICENSE)

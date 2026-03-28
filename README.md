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
  menu_keymap = "<leader>cm",    -- open quick actions menu
  cli_path = "claude",           -- path to the Claude Code CLI
  position = "right",            -- "right", "left", "center", "top", "bottom"
  width = 0.4,                   -- width as a fraction of the editor (0.1 - 1.0)
  height = 0.8,                  -- height as a fraction of the editor (0.1 - 1.0)
  watch_interval = 500,          -- file watcher interval in ms (for new file detection)
  system_prompt = "",            -- additional instructions appended to Claude's system prompt
})
```

Invalid values for `position`, `width`, `height`, or `watch_interval` are caught at setup time with a warning, and safe defaults are used.

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
| `:PairpToggle [session]` | Toggle the Claude Code window (optional named session) |
| `:'<,'>PairpSend [session]` | Send visual selection with file:line context |
| `:PairpSendFile [session]` | Send the entire current buffer to Claude |
| `:PairpContext [session]` | Send the current file path to Claude as context |
| `:PairpDiff [session]` | Send unstaged git diff to Claude |
| `:PairpDiffStaged [session]` | Send staged git diff to Claude |
| `:PairpDiagnostics [session]` | Send LSP diagnostics for the current buffer |
| `:PairpMenu` | Open quick actions menu |
| `:PairpReview` | Review Claude's changes in a diff view |
| `:PairpRevertAll` | Revert all files Claude touched to HEAD |
| `:PairpSwitch` | Switch between active sessions |
| `:PairpList` | List all active sessions |
| `:PairpClose [session]` | Kill a session and its terminal |

All commands that accept `[session]` support tab-completion of active session names.

### Keymaps

| Key | Mode | Description |
|---|---|---|
| `<leader>cc` | Normal | Toggle Claude Code window |
| `<leader>cs` | Visual | Send selection to Claude (with file:line context) |
| `<leader>cx` | Normal | Send current file path as context |
| `<leader>cm` | Normal | Open quick actions menu |
| `q` | Normal (in Pairp window) | Hide the window (keeps session alive) |
| `<C-q>` | Terminal (in Pairp window) | Hide the window from terminal mode |
| `<Esc><Esc>` | Terminal (in Pairp window) | Exit terminal mode |
| `<C-w>h/j/k/l` | Terminal (in Pairp window) | Navigate to adjacent editor windows |

### Smart Context

Send rich context to Claude without copy-pasting:

- **Visual selection** (`<leader>cs`) includes the filename and line range automatically
- **Git diff** (`:PairpDiff`) sends unstaged changes wrapped in a diff code block
- **Staged diff** (`:PairpDiffStaged`) sends only staged/cached changes
- **Diagnostics** (`:PairpDiagnostics`) sends LSP errors, warnings, and hints with line numbers

### Review Workflow

After Claude edits files, review the changes one-by-one:

```vim
:PairpReview
```

This opens a diff tab for each file Claude touched that has git changes. Keybinds in the review tab:

| Key | Description |
|---|---|
| `ga` | Accept changes (keep as-is, move to next file) |
| `gr` | Revert to HEAD (`git checkout`) and move to next file |
| `gn` | Skip to next file |
| `gq` | Close the review |

To revert everything at once:

```vim
:PairpRevertAll
```

### Live Buffer Reload

When a Pairp session is active, Neovim automatically detects and reloads files that Claude edits on disk using efficient filesystem event watchers. Changes appear in your editor buffers in real-time as Claude writes code.

Claude can also open files in your editor before editing them using the `pairp-nvim` bridge (automatically available inside the Pairp terminal):

```bash
pairp-nvim open src/main.lua        # open a file in the editor
pairp-nvim open src/main.lua 42     # open and jump to line 42
pairp-nvim buffers                  # list open buffers
```

### Named Sessions

Run multiple Claude sessions in parallel:

```vim
:PairpToggle debug
:PairpToggle refactor
:PairpSwitch           " pick a session to switch to
:PairpList
:PairpClose debug
```

### Telescope Integration

If [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) is installed, `:PairpSwitch` automatically uses a Telescope picker. You can also call it directly:

```vim
:Telescope pairp sessions
```

Telescope picker actions:

| Key | Description |
|---|---|
| `<CR>` | Switch to selected session |
| `<C-d>` | Close/kill selected session |

### Statusline

Add the active session to your statusline:

```lua
-- lualine example
lualine_x = { require("pairp").statusline }

-- manual usage
require("pairp").statusline()
-- Returns: "" (no sessions), "Pairp: default", or "Pairp: 3 sessions"
```

### Health Check

Verify your setup:

```vim
:checkhealth pairp
```

## License

[MIT](LICENSE)

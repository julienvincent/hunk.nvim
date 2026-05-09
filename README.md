<div align="center">
  <h1>hunk.nvim</h1>
</div>

<div align="center">
  <p>
    A tool for splitting diffs in Neovim
  </p>
</div>

This is a Neovim tool for splitting/editing diffs. It operates over a `left` and `right` directory, producing a diff of
the two which can subsequently be inspected and modified. The `DiffEditor` allows selecting changes by file, hunk or
individual line to produce a new partial diff.

This was primarily built to be used with [jujutsu](https://github.com/jj-vcs/jj) as an alternative diff-editor to it's
`:builtin` option, but it's designed generically enough that it can be used for other use cases.

To use it you need to give it two to three directories: a `left`, a `right`, and optionally a `output` directory. These
directories will then be read in and used to produce a set of diffs between the two directories. You will then be
presented with the left and right side of each file and can select the lines from each diff hunk you would like to keep.

When you are happy with your selection you can accept changes and the diff editor will modify the `output` directory (or
the `right` directory if no output is provided) to match your selection.

![preview](https://github.com/user-attachments/assets/eb323913-41a7-4043-8bff-cf08eeba20c5)

## Installation

### Using [folke/lazy.vim](https://github.com/folke/lazy.nvim)

```lua
{
  "julienvincent/hunk.nvim",
  cmd = { "DiffEditor" },
  config = function()
    require("hunk").setup()
  end,
}
```

### Dependencies

- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (optional)
- [mini.icons](https://github.com/echasnovski/mini.icons) (optional)

If you want file type icons in the file tree then you should have one of either `mini.icons` or `nvim-web-devicons`
installed. Otherwise, neither are required.

## Configuration

```lua
local hunk = require("hunk")
hunk.setup({
  keys = {
    global = {
      quit = { "q" },
      accept = { "<leader><Cr>" },
      -- In float mode this toggles the tree open/closed; in split mode it focuses it
      focus_tree = { "<leader>e" },
    },

    tree = {
      expand_node = { "l", "<Right>" },
      collapse_node = { "h", "<Left>" },

      open_file = { "<Cr>" },

      toggle_file = { "a" },
    },

    diff = {
      toggle_hunk = { "A" },
      toggle_line = { "a" },
      -- This is like toggle_line but it will also toggle the line on the other
      -- 'side' of the diff.
      toggle_line_pair = { "s" },

      prev_hunk = { "[h" },
      next_hunk = { "]h" },

      -- Jump between the left and right diff view
      toggle_focus = { "<Tab>" },
    },
  },

  ui = {
    tree = {
      -- Mode can either be `nested` or `flat`
      mode = "nested",
      -- Width of the tree (or float). 0 < n <= 1 = fraction of editor width, n > 1 = columns
      width = 35,
      -- When true the file tree opens as a floating window instead of a fixed split
      use_float = false,
      float = {
        -- Height of the floating window.
        -- 0 < n <= 1 = fraction of editor height, n > 1 = lines
        height = 1.0,
        -- Border style: nil, "rounded", "single", "double", "solid", "shadow", "none",
        -- or a custom array of border characters (see nui.popup docs).
        -- nil: use value of vim.o.winborder
        border = nil,
        -- Where to place the float: "left", "right", or "center"
        -- left/right are top-aligned; center is fully centered
        position = "left",
        -- Padding inside the float border: top/right/bottom/left
        padding = { left = 1, right = 1 },
        -- Keys to close the floating tree
        close = { "<Esc>" },
      },
    },
    --- Can be either `vertical` or `horizontal`
    layout = "vertical",
    --- Show a confirmation before quitting
    confirm_before_quit = false,
  },

  icons = {
    enable_file_icons = true,

    selected = "󰡖",
    deselected = "",
    partially_selected = "󰛲",

    folder_open = "",
    folder_closed = "",

    expanded = "",
    collapsed = "",
  },
  -- Called right after each window and buffer are created.
  hooks = {
    ---@param _context { buf: number, tree: NuiTree, opts: table }
    on_tree_mount = function(_context) end,
    ---@param _context { buf: number, win: number }
    on_diff_mount = function(_context) end,
  },
})
```

> [!NOTE]
>
> You can always press `g?` to get a help menu of the available commands

### Accepting / Rejecting Changes

Once you are happy with your selected set of hunks and/or lines you can accept the change by using the
`key.global.accept` keybinding. See **[configuration](#configuration)** or press `g?` to see what this is bound to
(default `<leader><Cr>`).

If Neovim exits with a non-0 exit code then the selection will be aborted and no changes will be written. You can use
the `keys.global.quit` keybinding (default `q`) to exit with a non-0 exit code. This just calls `:cq` internally - so
you can do that too.

### Highlights

Most of the hunk colors can be configured by defining your own highlight overrides. Refer to the below table for a list
of available highlights:

| Highlight               | Default           |
| ----------------------- | ----------------- |
| `HunkTreeFileAdded`     | `DiagnosticOk`    |
| `HunkTreeFileDeleted`   | `DiagnosticError` |
| `HunkTreeFileModified`  | `DiagnosticInfo`  |
| `HunkTreeDir`           | `Directory`       |
| `HunkTreeDirIcon`       | `Directory`       |
| `HunkTreeSelectionIcon` | `Comment`         |
| `HunkSignAdd`           | `DiagnosticOk`    |
| `HunkSignDelete`        | `DiagnosticError` |
| `HunkHelpTitle`         | `Title`           |
| `HunkHelpCommandName`   | `Identifier`      |

### Using Hooks

Hooks can be used to bind keys with "complex" logic, or to set buffer/window local options on the tree or diff splits.

<details>
  <summary>Skipping Folders in the File Tree</summary>

These bindings allow `j`/`k` to skip over folders in the file tree (b/c they're generally not relevant). You can still
access folders with `gj`/`gk`.

```lua
-- track all the lines of leaf nodes so we don't have to recompute them on each key press
local jumpable_lines
local function set_jumpabe_lines(context)
  jumpable_lines = {}
  local i = 1
  local n, _, _ = context.tree:get_node(i)
  while n do
    if not n:has_children() then
      table.insert(jumpable_lines, i)
    end
    i = i + 1
    n, _, _ = context.tree:get_node(i)
  end
end
require("hunk").setup({
  hooks = {
    on_tree_mount = function(context)
      vim.keymap.set("n", "j", function()
        -- unfortunately we have to recompute every time because folding ruins these computed values
        set_jumpabe_lines(context)
        local row = vim.api.nvim_win_get_cursor(0)[1]
        if row < jumpable_lines[1] then
          vim.api.nvim_win_set_cursor(0, { jumpable_lines[1], 0 })
          return
        end
        for idx = #jumpable_lines, 1, -1 do
          if jumpable_lines[idx] <= row then
            if jumpable_lines[idx + 1] then
              vim.api.nvim_win_set_cursor(0, { jumpable_lines[idx + 1], 0 })
            end
            return
          end
        end
      end, { buffer = context.buf })

      vim.keymap.set("n", "k", function()
        set_jumpabe_lines(context)
        local row = vim.api.nvim_win_get_cursor(0)[1]
        if row > jumpable_lines[#jumpable_lines] then
          vim.api.nvim_win_set_cursor(0, { jumpable_lines[#jumpable_lines], 0 })
          return
        end
        for idx, node_row in ipairs(jumpable_lines) do
          if node_row >= row then
            if jumpable_lines[idx - 1] then
              vim.api.nvim_win_set_cursor(0, { jumpable_lines[idx - 1], 0 })
            end
            return
          end
        end
      end, { buffer = context.buf })
    end,
  },
})
```

</details>

<details>
  <summary>Set `nospell` in File Tree</summary>

```lua
require("hunk").setup({
  hooks = {
    on_tree_mount = function(context)
      vim.api.nvim_set_option_value("spell", false, { win = context.win })
    end,
  },
})
```

</details>

## Using with Jujutsu

[Jujutsu](https://github.com/jj-vcs/jj) is an alternative VCS that has a focus on working with individual commits and
their diffs.

A lot of commands in jujutsu allow you to select parts of a diff. The tool used to select the diff can be configured via
their `ui.diff-editor` config option. To use `hunk.nvim` add the following to your jujutsu `config.toml`:

```toml
[ui]
diff-editor = ["nvim", "-c", "DiffEditor $left $right $output"]
```

You can find more info on this config in [the jujutsu docs](https://docs.jj-vcs.dev/latest/config/#editing-diffs).

### Suppressing the `JJ-INSTRUCTIONS` file

To suppress the `JJ-INSTRUCTIONS` file that jujutsu injects into the diff editor, set
[`ui.diff-instructions = false`](https://docs.jj-vcs.dev/latest/config/#jj-instructions) in your jujutsu `config.toml`:

```toml
[ui]
diff-instructions = false
```

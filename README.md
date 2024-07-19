<div align="center">
  <h1>difftool.nvim</h1>
</div>

<div align="center">
  <p>
    A tool for editing diffs in Neovim
  </p>
</div>

---

This is a Neovim tool for splitting/editing diffs. It operates over a `left` and `right` directory, producing a diff of
the two which can subsiquently be inspected and modified. The `DiffEditor` allows selecting changes by file, hunk or
individual line to produce a new partial diff.

This was primarilly built to be used with [jujutsu](https://github.com/martinvonz/jj) as an alternative diff-editor to
it's `:builtin` option, but it's designed generically enough that it can be used for other usecases.

To use it you need to give it two to three directories: a `left`, a `right`, and optionally and `output` directory.
These directories will then be read in by the diffeditor and used to produce a set of diffs between the two directories.
You will then be presented with the left and right side of each file and can select the lines from each diff hunk you
would like to keep.

When you are happy with your selection you can accept changes and the diffeditor will modify the `output` directory (or
the `right` directory if no output is provided) to match your selection.

## Installation

### Using [folke/lazy.vim](https://github.com/folke/lazy.nvim)

```lua
{
  "julienvincent/difftool.nvim",
  cmd = { "DiffEditor" },
  config = function()
    require("difftool").setup()
  end,
  dependencies = {
    { "MunifTanjim/nui.nvim" }
  }
}
```

## Configuration

```lua
local difftool = require("difftool")
difftool.setup({
  keys = {
    global = {
      quit = { "q" },
      accept = { "<leader><Cr>" },
    },

    tree = {
      expand_node = { "l", "<Right>" },
      collapse_node = { "h", "<Left>" },

      open_file = { "<Cr>" },

      toggle_file = { "a" },
    },

    diff = {
      toggle_line = { "a" },
      toggle_hunk = { "A" },
    },
  },

  icons = {
    selected = "󰡖",
    deselected = "",
  },

  hooks = {
    on_tree_mount = function() end,
    on_diff_mount = function() end,
  }
})
```

## Configuring Jujutsu

Add the following to your jujutsu `config.toml`:

```toml
[ui]
diff-editor = ["nvim", "-c", "DiffEditor $left $right $output"]
```

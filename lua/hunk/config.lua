local M = {
  keys = {
    global = {
      quit = { "q" },
      accept = { "<leader><Cr>" },
      focus_tree = { "<leader>e" },
    },

    tree = {
      expand_node = { "l", "<Right>" },
      collapse_node = { "h", "<Left>" },

      open_file = { "<Cr>" },

      toggle_file = { "a" },

      prev_file = { "[f" },
      next_file = { "]f" },
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
      width = 35,
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

  hooks = {
    ---@param _context { buf: number, tree: NuiTree, opts: table }
    on_tree_mount = function(_context) end,
    ---@param _context { buf: number, win: number }
    on_diff_mount = function(_context) end,
  },
}

function M.update_config(new_config)
  local config = vim.tbl_deep_extend("force", M, new_config)
  for key, value in pairs(config) do
    M[key] = value
  end
end

return M

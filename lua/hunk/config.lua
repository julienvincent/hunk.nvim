local M = {
  keys = {
    global = {
      n = {
        ["q"] = "<Plug>(hunk.global.quit)",
        ["<leader><cr>"] = { "<Plug>(hunk.global.accept)", { desc = "Accept" } },
        ["<leader>e"] = { "<Plug>(hunk.global.focus_tree)", { desc = "Focus Tree" } },
      },
    },

    tree = {
      n = {
        ["l"] = "<Plug>(hunk.tree.expand_node)",
        ["<right>"] = "<Plug>(hunk.tree.expand_node)",

        ["h"] = "<Plug>(hunk.tree.collapse_node)",
        ["<left>"] = "<Plug>(hunk.tree.collapse_node)",

        ["<cr>"] = "<Plug>(hunk.tree.open_file)",

        ["a"] = "<Plug>(hunk.tree.toggle_file)",
      },
    },

    diff = {
      n = {
        ["a"] = "<Plug>(hunk.diff.toggle_line)",
        ["A"] = "<Plug>(hunk.diff.toggle_hunk)",
      },
      v = {
        ["a"] = { "<Plug>(hunk.diff.toggle_visual_lines)", { desc = "Toggle Visual Lines", nowait = true } },
      },
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
  },

  icons = {
    selected = "󰡖",
    deselected = "",
    partially_selected = "󰛲",

    folder_open = "",
    folder_closed = "",
  },

  hooks = {
    on_tree_mount = function() end,
    on_diff_mount = function() end,
  },
}

function M.update_config(new_config)
  local config = vim.tbl_deep_extend("force", M, new_config)
  for key, value in pairs(config) do
    M[key] = value
  end
end

return M

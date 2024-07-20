local M = {
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

  ui = {
    tree = {
      -- Mode can either be `nested` or `flat`
      mode = "nested"
    }
  },

  icons = {
    selected = "󰡖",
    deselected = "",
  },

  hooks = {
    on_tree_mount = function() end,
    on_diff_mount = function() end,
  }
}

function M.update_config(new_config)
  local config = vim.tbl_deep_extend("force", M, new_config)
  for key, value in pairs(config) do
    M[key] = value
  end
end

return M

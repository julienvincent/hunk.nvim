---@class hunk.KeysGlobal
---@field quit string|string[] Keybinding(s) to quit (exit with non-zero code)
---@field accept string|string[] Keybinding(s) to accept the current selection
---@field focus_tree string|string[] Keybinding(s) to focus the file tree

---@class hunk.KeysTree
---@field expand_node string|string[] Keybinding(s) to expand a tree node
---@field collapse_node string|string[] Keybinding(s) to collapse a tree node
---@field open_file string|string[] Keybinding(s) to open file under cursor
---@field toggle_file string|string[] Keybinding(s) to toggle all hunks in file

---@class hunk.KeysDiff
---@field toggle_hunk string|string[] Keybinding(s) to toggle entire hunk under cursor
---@field toggle_line string|string[] Keybinding(s) to toggle line under cursor
---@field toggle_line_pair string|string[] Keybinding(s) to toggle line pair on both sides
---@field prev_hunk string|string[] Keybinding(s) to jump to previous hunk
---@field next_hunk string|string[] Keybinding(s) to jump to next hunk
---@field toggle_focus string|string[] Keybinding(s) to toggle focus between left/right

---@class hunk.KeysMerge
---@field accept string|string[] Keybinding(s) to accept hunk under cursor into center
---@field accept_left string|string[] Keybinding(s) to accept left hunk from center
---@field accept_right string|string[] Keybinding(s) to accept right hunk from center
---@field accept_all_left string|string[] Keybinding(s) to accept left entirely and quit
---@field accept_all_right string|string[] Keybinding(s) to accept right entirely and quit
---@field automerge string|string[] Keybinding(s) to accept all non-conflicting hunks
---@field next_hunk string|string[] Keybinding(s) to jump to next hunk
---@field prev_hunk string|string[] Keybinding(s) to jump to previous hunk

---@class hunk.Keys
---@field global hunk.KeysGlobal
---@field tree hunk.KeysTree
---@field diff hunk.KeysDiff
---@field merge hunk.KeysMerge

---@class hunk.UiTree
---@field mode "nested"|"flat" Tree display mode
---@field width number Width of the file tree panel

---@class hunk.Ui
---@field tree hunk.UiTree
---@field layout "vertical"|"horizontal" Diff split layout direction
---@field confirm_before_quit boolean Show a confirmation before quitting

---@class hunk.Icons
---@field enable_file_icons boolean Whether to show file type icons
---@field selected string Icon for selected items
---@field deselected string Icon for deselected items
---@field partially_selected string Icon for partially selected items
---@field folder_open string Icon for open folders
---@field folder_closed string Icon for closed folders
---@field expanded string Icon for expanded tree nodes
---@field collapsed string Icon for collapsed tree nodes

---@class hunk.Hooks
---@field on_tree_mount fun(context: { buf: number, tree: NuiTree, opts: table }) Called after tree buffer is mounted
---@field on_diff_mount fun(context: { buf: number, win: number }) Called after diff buffer is mounted

---@class hunk.Config
---@field keys hunk.Keys
---@field ui hunk.Ui
---@field icons hunk.Icons
---@field hooks hunk.Hooks

---@type hunk.Config
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

    merge = {
      accept = { "a" },
      accept_left = { "gl" },
      accept_right = { "gr" },
      accept_all_left = { "gL" },
      accept_all_right = { "gR" },
      automerge = { "gA" },
      next_hunk = { "]h" },
      prev_hunk = { "[h" },
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

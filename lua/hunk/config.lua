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

---@class hunk.Keys
---@field global hunk.KeysGlobal
---@field tree hunk.KeysTree
---@field diff hunk.KeysDiff

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
      -- Width of the tree (or float). 0 < n <= 1 = fraction of editor width, n > 1 = columns
      width = 35,
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
        -- left/right are top-aligned; center is fully centered.
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

  hooks = {
    ---@param _context { buf: number, tree: NuiTree, opts: table }
    on_tree_mount = function(_context) end,
    ---@param _context { buf: number, win: number }
    on_diff_mount = function(_context) end,
  },
}

local function validate_positive_number(value, config_path)
  if type(value) ~= "number" or value <= 0 then
    error("Expected positive number for config entry `" .. config_path .. "`")
  end
end

local function validate_enum(value, allowed_values, config_path)
  for _, allowed in ipairs(allowed_values) do
    if value == allowed then
      return
    end
  end

  error("Unknown value '" .. tostring(value) .. "' for config entry `" .. config_path .. "`")
end

local function validate_config(config)
  validate_enum(config.ui.layout, { "vertical", "horizontal" }, "ui.layout")
  validate_enum(config.ui.tree.mode, { "nested", "flat" }, "ui.tree.mode")
  validate_enum(config.ui.tree.float.position, { "left", "right", "center" }, "ui.tree.float.position")
  validate_positive_number(config.ui.tree.width, "ui.tree.width")
  validate_positive_number(config.ui.tree.float.height, "ui.tree.float.height")
end

function M.update_config(new_config)
  local config = vim.tbl_deep_extend("force", M, new_config)
  validate_config(config)
  for key, value in pairs(config) do
    M[key] = value
  end
end

return M

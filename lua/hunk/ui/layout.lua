local highlights = require("hunk.api.highlights")
local config = require("hunk.config")

local NuiPopup = require("nui.popup")

local M = {}

local function create_vertical_split()
  vim.api.nvim_command("rightbelow vsplit")
  local winid = vim.api.nvim_get_current_win()
  -- vim.api.nvim_set_option_value("diff", true, {
  --   win = winid,
  -- })
  return winid
end

local function create_horizontal_split()
  vim.api.nvim_command("rightbelow split")
  local winid = vim.api.nvim_get_current_win()
  return winid
end

local function create_right_diff_split()
  local layouts = {
    vertical = create_vertical_split,
    horizontal = create_horizontal_split,
  }

  return layouts[config.ui.layout]()
end

local function resolve_dimension(value, max)
  if value <= 1 then
    return math.max(1, math.floor(max * value))
  else
    return math.floor(value)
  end
end

local function resize_tree(tree, left, right)
  local total_width = vim.api.nvim_get_option_value("columns", {})
  local size = resolve_dimension(config.ui.tree.width, total_width)
  local remaining_width = total_width - size
  local equal_width = math.floor(remaining_width / 2)

  vim.api.nvim_win_set_width(tree, size)

  if config.ui.layout == "vertical" then
    vim.api.nvim_win_set_width(left, equal_width)
    vim.api.nvim_win_set_width(right, equal_width)
  end
end

local function resolve_float_position(pos_cfg, width, border_w, pad, center_row)
  -- nui treats position as the content origin; border/padding extend outward.
  local left_extra = border_w + (pad.left or 0)
  local right_extra = border_w + (pad.right or 0)
  local positions = {
    center = { row = center_row, col = "50%" },
    left = { row = 0, col = left_extra },
    right = { row = 0, col = math.max(0, vim.o.columns - width - right_extra) },
  }

  return positions[pos_cfg]
end

local function create_tree_popup()
  local float_cfg = config.ui.tree.float
  local pad = float_cfg.padding or {}
  local border_style = float_cfg.border or vim.o.winborder
  if border_style == "" then
    border_style = "none"
  end
  local border_w = border_style ~= "none" and 1 or 0
  local padding_w = (pad.left or 0) + (pad.right or 0)
  local border_h = border_w * 2 + (pad.top or 0) + (pad.bottom or 0)
  local tabline_rows
  if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") > 1) then
    tabline_rows = 1
  else
    tabline_rows = 0
  end
  local statusline_rows = vim.o.laststatus > 0 and 1 or 0
  local available_rows = vim.o.lines - vim.o.cmdheight - statusline_rows - tabline_rows
  local available_columns = vim.o.columns - border_w * 2 - padding_w
  local width = resolve_dimension(config.ui.tree.width, available_columns)
  local height = resolve_dimension(float_cfg.height, available_rows - border_h)
  local center_row = tabline_rows + math.floor((available_rows - height) / 2)

  local popup = NuiPopup({
    enter = true,
    focusable = true,
    border = { style = border_style, padding = float_cfg.padding },
    relative = "editor",
    position = resolve_float_position(float_cfg.position, width, border_w, pad, center_row),
    size = { width = width, height = height },
  })
  popup:mount()

  -- nui's QuitPre handler calls self:unmount(), which destroys the buffer
  -- backing the NuiTree. Override unmount on this instance so :q behaves
  -- like hide() instead. This keeps nui's BufWinEnter handler intact,
  -- which re-registers WinClosed -> hide() after each show().
  function popup:unmount()
    self:hide()
  end

  return popup
end

local function create_floating_window_layout()
  local left_diff = vim.api.nvim_get_current_win()
  local right_diff = create_right_diff_split()

  if config.ui.layout == "vertical" then
    local total_width = vim.api.nvim_get_option_value("columns", {})
    local half = math.floor(total_width / 2)
    vim.api.nvim_win_set_width(left_diff, half)
    vim.api.nvim_win_set_width(right_diff, half)
  end

  local tree_popup = create_tree_popup()

  return {
    tree = tree_popup.winid,
    tree_popup = tree_popup,
    left = left_diff,
    right = right_diff,
  }
end

local function create_split_window_layout()
  local tree_window = vim.api.nvim_get_current_win()
  local left_diff = create_vertical_split()
  local right_diff = create_right_diff_split()

  resize_tree(tree_window, left_diff, right_diff)
  vim.api.nvim_set_option_value("winfixwidth", true, { win = tree_window })

  return {
    tree = tree_window,
    left = left_diff,
    right = right_diff,
  }
end

function M.create_layout()
  local layout
  if config.ui.tree.use_float then
    layout = create_floating_window_layout()
  else
    layout = create_split_window_layout()
  end

  highlights.set_win_hl(layout.left, {
    "DiffAdd:HunkDiffAddAsDelete",
    "DiffDelete:HunkDiffDeleteDim",

    "HunkSignSelected:HunkSignDelete",
    "HunkSignDeselected:HunkSignDelete",
  })

  highlights.set_win_hl(layout.right, {
    "DiffDelete:HunkDiffDeleteDim",
    "HunkSignSelected:HunkSignAdd",
    "HunkSignDeselected:HunkSignAdd",
  })

  vim.api.nvim_set_current_win(layout.tree)

  return layout
end

return M

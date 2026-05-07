local M = {}

function M.create_layout()
  local left_win = vim.api.nvim_get_current_win()

  vim.api.nvim_command("rightbelow vsplit")
  local center_win = vim.api.nvim_get_current_win()

  vim.api.nvim_command("rightbelow vsplit")
  local right_win = vim.api.nvim_get_current_win()

  local total_width = vim.api.nvim_get_option_value("columns", {})
  local equal_width = math.floor(total_width / 3)
  vim.api.nvim_win_set_width(left_win, equal_width)
  vim.api.nvim_win_set_width(center_win, equal_width)
  vim.api.nvim_win_set_width(right_win, equal_width)

  vim.api.nvim_set_current_win(center_win)

  return {
    left = left_win,
    center = center_win,
    right = right_win,
  }
end

return M

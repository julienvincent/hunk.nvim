local M = {}

function M.set_win_hl(winid, highlights)
  vim.api.nvim_set_option_value("winhl", table.concat(highlights, ","), {
    win = winid,
  })
end

function M.define_highlights()
  local diff_delete_highlight = vim.api.nvim_get_hl(0, {
    name = "DiffDelete",
    link = true,
  })

  vim.api.nvim_set_hl(0, "HunkDiffAddAsDelete", {
    bg = string.format("#%06x", diff_delete_highlight.bg),
  })

  vim.api.nvim_set_hl(0, "HunkDiffDeleteDim", {
    default = true,
    link = "Comment",
  })

  vim.api.nvim_set_hl(0, "HunkDiffDelete", {
    link = "HunkDiffDeleteDim",
  })
end

return M

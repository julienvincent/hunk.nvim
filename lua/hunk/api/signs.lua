local config = require("hunk.config")

local M = {
  signs = {
    left_selected = {
      name = "HunkLineLeftSelected",
      hl = "HunkSignSelected",
    },
    left_deselected = {
      name = "HunkLineLeftDeselected",
      hl = "HunkSignDeselected",
    },
    right_selected = {
      name = "HunkLineRightSelected",
      hl = "HunkSignSelected",
    },
    right_deselected = {
      name = "HunkLineRightDeselected",
      hl = "HunkSignDeselected",
    },
    partially_selected = {
      name = "HunkLinePartiallySelected",
      hl = "HunkSignPartiallySelected",
    },
  },
}

function M.clear_signs(buf)
  vim.fn.sign_unplace("Hunk", {
    buffer = buf,
  })
end

function M.place_sign(buf, sign, linenr)
  vim.fn.sign_place(0, "Hunk", sign.name, buf, {
    lnum = linenr,
    priority = 100,
  })
end

function M.define_signs()
  vim.fn.sign_define({
    {
      name = M.signs.left_selected.name,
      text = config.icons.left.selected,
      texthl = M.signs.left_selected.hl,
    },
    {
      name = M.signs.left_deselected.name,
      text = config.icons.left.deselected,
      texthl = M.signs.left_deselected.hl,
    },
    {
      name = M.signs.right_selected.name,
      text = config.icons.right.selected,
      texthl = M.signs.right_selected.hl,
    },
    {
      name = M.signs.right_deselected.name,
      text = config.icons.right.deselected,
      texthl = M.signs.right_deselected.hl,
    },
    {
      name = M.signs.partially_selected.name,
      text = config.icons.partially_selected,
      texthl = M.signs.partially_selected.hl,
    },
  })
end

return M

local config = require("hunk.config")

local M = {
  signs = {
    selected = {
      name = "HunkLineSelected",
      hl = "HunkSignSelected",
    },
    deselected = {
      name = "HunkLineDeselected",
      hl = "HunkSignDeselected",
    },
  },
}

function M.place_sign(buf, sign, linenr)
  vim.fn.sign_place(0, "Hunk", sign.name, buf, {
    lnum = linenr,
    priority = 100,
  })
end

function M.define_signs()
  vim.fn.sign_define({
    {
      name = M.signs.selected.name,
      text = config.icons.selected,
      texthl = M.signs.selected.hl,
    },
    {
      name = M.signs.deselected.name,
      text = config.icons.deselected,
      texthl = M.signs.deselected.hl,
    },
  })
end

return M

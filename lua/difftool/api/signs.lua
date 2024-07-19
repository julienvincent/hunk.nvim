local config = require("difftool.config")

local M = {
  signs = {
    selected = {
      name = "DiffToolLineSelected",
      hl = "DiffToolSignSelected",
    },
    deselected = {
      name = "DiffToolLineDeselected",
      hl = "DiffToolSignDeselected",
    },
  },
}

function M.place_sign(buf, sign, linenr)
  vim.fn.sign_place(0, "DiffTool", sign.name, buf, {
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

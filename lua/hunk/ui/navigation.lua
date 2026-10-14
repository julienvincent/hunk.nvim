local config = require("hunk.config")
local utils = require("hunk.utils")

local M = {}

function M.bind(buf, tree)
  local function map(chords, callback, desc)
    for _, chord in ipairs(utils.into_table(chords)) do
      vim.keymap.set("n", chord, callback, { buffer = buf, desc = desc, nowait = true })
    end
  end

  map(config.keys.global.focus_tree, tree.toggle, "Focus or toggle (for float) hunk.nvim file-tree")

  -- Install close bindings after the controller's quit bindings so overlapping keys close the float.
  if config.ui.tree.use_float and buf == tree.buf then
    map(config.ui.tree.float.close, tree.close, "Close tree float")
  end
end

return M

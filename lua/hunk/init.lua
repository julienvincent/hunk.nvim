local config = require("hunk.config")
local diff_editor = require("hunk.diff_editor")

local M = {
  start = diff_editor.start,
}

--- Setup the plugin with user configuration.
---@param opts hunk.Config? User configuration overrides
function M.setup(opts)
  opts = opts or {}
  config.update_config(opts)
end

return M

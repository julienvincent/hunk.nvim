local config = require("hunk.config")

local M = {}

function M.start(left, right, output)
  vim.notify_once("hunk.start() is deprecated. Please use hunk.edit() instead", vim.log.levels.WARN)
  return require("hunk.diff_editor").start(left, right, output)
end

function M.edit(left, right, output)
  return require("hunk.diff_editor").start(left, right, output)
end

--- View a directory comparison without writing either side.
---@param left string
---@param right string
---@return boolean
function M.view(left, right)
  return require("hunk.diff_view").start(left, right)
end

--- Setup the plugin with user configuration.
---@param opts hunk.Config? User configuration overrides
function M.setup(opts)
  opts = opts or {}
  config.update_config(opts)
end

return M

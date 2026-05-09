local config = require("hunk.config")
local api = require("hunk.api")
local ui = require("hunk.ui")

local M = {}

local initialised = false

local function init()
  initialised = true
  api.signs.define_signs()
  api.highlights.define_highlights()
end

function M.start(left, right, output)
  if not initialised then
    init()
  end

  ---@class hunk.Session
  ---@field changeset table
  ---@field layout table
  ---@field components table
  ---@field left string
  ---@field right string
  ---@field output string
  local session = {
    changeset = api.changeset.load_changeset(left, right),
    layout = ui.layout.create_layout(),
    components = {},
    left = left,
    right = right,
    output = output,
  }

  local left_file, right_file
  local tree = ui.tree.create({
    winid = session.layout.tree,
    changeset = session.changeset,
    session = session,
    on_open = function(change, opts)
      left_file, right_file = api.actions.open_file(session, opts.tree, change)
      session.components.left_file = left_file
      session.components.right_file = right_file
      vim.api.nvim_set_current_win(session.layout.right)
    end,
    on_preview = function(change, opts)
      left_file, right_file = api.actions.open_file(session, opts.tree, change)
      session.components.left_file = left_file
      session.components.right_file = right_file
      vim.api.nvim_set_current_win(session.layout.tree)
    end,
    on_toggle = function(change, value, opts)
      api.actions.toggle_file(change, value)

      left_file.render()
      right_file.render()
      opts.tree.render()
    end,
  })

  session.components.tree = tree

  tree.render()

  api.actions.set_global_bindings(session, tree.buf)

  return session
end

--- Setup the plugin with user configuration.
---@param opts hunk.Config? User configuration overrides
function M.setup(opts)
  opts = opts or {}
  config.update_config(opts)
end

return M

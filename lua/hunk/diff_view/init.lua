local config = require("hunk.config")
local utils = require("hunk.utils")
local changeset_api = require("hunk.api.changeset")
local highlights = require("hunk.api.highlights")
local ui = require("hunk.ui")

local M = {}
local initialised = false

local function help_keys()
  local keys = config.keys
  return {
    global = { quit = keys.global.quit, focus_tree = keys.global.focus_tree },
    tree = {
      expand_node = keys.tree.expand_node,
      collapse_node = keys.tree.collapse_node,
      open_file = keys.tree.open_file,
    },
    diff = {
      prev_hunk = keys.diff.prev_hunk,
      next_hunk = keys.diff.next_hunk,
      toggle_focus = keys.diff.toggle_focus,
    },
  }
end

local function set_global_bindings(buf, tree)
  vim.keymap.set("n", "g?", function()
    ui.help.create(help_keys())
  end, { buffer = buf, desc = "Open hunk.nvim help", nowait = true })
  for _, chord in ipairs(utils.into_table(config.keys.global.quit)) do
    vim.keymap.set("n", chord, function()
      vim.cmd.qa()
    end, { buffer = buf, desc = "Close diff viewer", nowait = true })
  end
  ui.navigation.bind(buf, tree)
end

local function open_file(layout, tree, change, prefix)
  for _, side in ipairs({ "left", "right" }) do
    local buf = ui.buffer.create({ name = prefix .. side .. "/" .. change.filepath, file = change[side .. "_file"] })
    ui.file.create(layout[side], {
      buf = buf,
      side = side,
      change = change,
      on_focus = function(current_side)
        vim.api.nvim_set_current_win(current_side == "left" and layout.right or layout.left)
      end,
    })
    set_global_bindings(buf, tree)
  end
end

local function validate_directories(left, right)
  local dirs = { left, right }
  for index = 1, 2 do
    local dir = dirs[index]
    if type(dir) == "string" then
      dir = vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
    end
    if type(dir) ~= "string" or vim.fn.isdirectory(dir) ~= 1 or not vim.loop.fs_scandir(dir) then
      local side = index == 1 and "left" or "right"
      vim.notify(
        "Error: HunkDiffView expects readable directories (left, right); " .. side .. " = " .. vim.inspect(dir),
        vim.log.levels.ERROR
      )
      return
    end
    dirs[index] = dir
  end
  return dirs
end

function M.start(left, right)
  local dirs = validate_directories(left, right)
  if not dirs then
    return false
  end
  if not initialised then
    highlights.define_highlights()
    initialised = true
  end
  local changeset = changeset_api.load_changeset(dirs[1], dirs[2])
  local prefix = "hunk://view/" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. "/"
  local layout = ui.layout.create_layout()
  for _, side in ipairs({ "tree", "left", "right" }) do
    local buf
    if side == "tree" and layout.tree_popup then
      buf = layout.tree_popup.bufnr
      vim.api.nvim_buf_set_name(buf, prefix .. side)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      vim.api.nvim_set_option_value("readonly", true, { buf = buf })
      vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
    else
      buf = ui.buffer.create({ name = prefix .. side })
    end
    vim.api.nvim_win_set_buf(layout[side], buf)
  end

  local tree
  tree = ui.tree.create({
    winid = layout.tree,
    popup = layout.tree_popup,
    changeset = changeset,
    on_open = function(change, opts)
      open_file(layout, tree or opts.tree, change, prefix)
      vim.api.nvim_set_current_win(layout.right)
    end,
    on_preview = function(change, opts)
      local current_tree = tree or opts.tree
      open_file(layout, current_tree, change, prefix)
      current_tree.focus()
    end,
  })

  for _, side in ipairs({ "tree", "left", "right" }) do
    set_global_bindings(vim.api.nvim_win_get_buf(layout[side]), tree)
  end
  return true
end

return M

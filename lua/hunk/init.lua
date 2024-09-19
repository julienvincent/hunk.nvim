local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")
local ui = require("hunk.ui")

local M = {}

local CONTEXT

local function toggle_file(change)
  for _, hunk in ipairs(change.hunks) do
    for i in utils.hunk_lines(hunk.left) do
      change.selected_lines.left[i] = not change.selected
    end

    for i in utils.hunk_lines(hunk.right) do
      change.selected_lines.right[i] = not change.selected
    end
  end

  change.selected = not change.selected
end

local function toggle_lines(change, side, lines, value)
  for _, line in ipairs(lines) do
    if value ~= nil then
      change.selected_lines[side][line] = value
    else
      change.selected_lines[side][line] = not change.selected_lines[side][line]
    end
  end

  if utils.all_lines_selected(change) then
    change.selected = true
  else
    change.selected = false
  end
end

local function toggle_hunk(change, side, line)
  local hunk
  for _, current_hunk in ipairs(change.hunks) do
    local start_line = current_hunk[side][1]
    local end_line = start_line + current_hunk[side][2]
    if line <= end_line and line >= start_line then
      hunk = current_hunk
      break
    end
  end

  if not hunk then
    return
  end

  local left_lines = {}
  for i in utils.hunk_lines(hunk.left) do
    table.insert(left_lines, i)
  end

  local right_lines = {}
  for i in utils.hunk_lines(hunk.right) do
    table.insert(right_lines, i)
  end

  local any_selected = utils.all_lines_selected_in_hunk(change, hunk)

  toggle_lines(change, "left", left_lines, not any_selected)
  toggle_lines(change, "right", right_lines, not any_selected)
end

local function set_global_bindings(layout, buf)
  for _, chord in ipairs(utils.into_table(config.keys.global.accept)) do
    vim.keymap.set("n", chord, function()
      api.changeset.write_changeset(CONTEXT.changeset, CONTEXT.output or CONTEXT.right)
      vim.cmd("qa")
    end, {
      buffer = buf,
    })
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.quit)) do
    vim.keymap.set("n", chord, function()
      vim.cmd("cq")
    end, {
      buffer = buf,
    })
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.focus_tree)) do
    vim.keymap.set("n", chord, function()
      vim.api.nvim_set_current_win(layout.tree)
    end, {
      buffer = buf,
    })
  end
end

local function open_file(layout, tree, change)
  local left_file
  local right_file

  local function on_file_event(event)
    if event.type == "toggle-lines" then
      toggle_lines(change, event.file.side, event.lines)
      event.file.render()
      tree.render()
      return
    end

    if event.type == "toggle-hunk" then
      toggle_hunk(change, event.file.side, event.line)
      left_file.render()
      right_file.render()
      tree.render()
      return
    end
  end

  left_file = ui.file.create(layout.left, {
    side = "left",
    change = change,
    on_event = on_file_event,
  })

  right_file = ui.file.create(layout.right, {
    side = "right",
    change = change,
    on_event = on_file_event,
  })

  set_global_bindings(layout, left_file.buf)
  set_global_bindings(layout, right_file.buf)

  return left_file, right_file
end

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
  local changeset = api.changeset.load_changeset(left, right)
  local layout = ui.layout.create_layout()

  CONTEXT = {
    changeset = changeset,
    left = left,
    right = right,
    output = output,
  }

  local left_file, right_file
  local tree = ui.tree.create({
    winid = layout.tree,
    changeset = changeset,
    on_open = function(change, opts)
      left_file, right_file = open_file(layout, opts.tree, change)
      vim.api.nvim_set_current_win(layout.right)
    end,
    on_preview = function(change, opts)
      left_file, right_file = open_file(layout, opts.tree, change)
      vim.api.nvim_set_current_win(layout.tree)
    end,
    on_toggle = function(change, opts)
      toggle_file(change)

      left_file.render()
      right_file.render()
      opts.tree.render()
    end,
  })

  tree.render()

  set_global_bindings(layout, tree.buf)
end

function M.setup(opts)
  opts = opts or {}
  config.update_config(opts)
end

return M

local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")
local ui = require("hunk.ui")

local M = {}

---@type table?
local CONTEXT

local function value_or_default(value, default)
  if value ~= nil then
    return value
  end
  return default
end

local function toggle_file(change, value)
  for _, hunk in ipairs(change.hunks) do
    for i in utils.hunk_lines(hunk.left) do
      change.selected_lines.left[i] = value_or_default(value, not change.selected)
    end

    for i in utils.hunk_lines(hunk.right) do
      change.selected_lines.right[i] = value_or_default(value, not change.selected)
    end
  end

  change.selected = value_or_default(value, not change.selected)
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

local function line_is_within_hunk_bounds(hunk, side, line)
  local start_line = hunk[side][1]
  local end_line = start_line + hunk[side][2]
  return line <= end_line and line >= start_line
end

local function find_hunk_at_line(hunks, side, line)
  for _, current_hunk in ipairs(hunks) do
    if line_is_within_hunk_bounds(current_hunk, side, line) then
      return current_hunk
    end
  end
end

local function toggle_line_pairs(change, reference_side, lines, value)
  local hunk
  for _, line in ipairs(lines) do
    if not hunk or not line_is_within_hunk_bounds(hunk, reference_side, line) then
      hunk = find_hunk_at_line(change.hunks, reference_side, line)
    end

    if value ~= nil then
      value = change.selected_lines[reference_side][line]
    end

    if hunk then
      toggle_lines(change, reference_side, { line }, value)

      local opposite_side = "left"
      if reference_side == "left" then
        opposite_side = "right"
      end

      local offset = (hunk[reference_side][1] - line) * -1
      if hunk[opposite_side][2] >= offset then
        local other_line = hunk[opposite_side][1] + offset
        toggle_lines(change, opposite_side, { other_line }, value)
      end
    end
  end
end

local function toggle_hunk(change, side, line)
  local hunk = find_hunk_at_line(change.hunks, side, line)
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

local function set_global_bindings(layout, buf, tree)
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = buf,
      desc = desc,
      nowait = true,
    })
  end

  map("n", "g?", ui.help.create, "Open hunk.nvim help")

  for _, chord in ipairs(utils.into_table(config.keys.global.accept)) do
    map("n", chord, function()
      api.changeset.write_changeset(CONTEXT.changeset, CONTEXT.output or CONTEXT.right)
      vim.cmd.qa()
    end, "qa")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.quit)) do
    map("n", chord, function()
      if config.ui.confirm_before_quit then
        vim.ui.select({ "Yes", "No" }, { prompt = "Quit without saving?" }, function(choice)
          if choice == "Yes" then
            vim.cmd.cq()
          end
        end)
      else
        vim.cmd.cq()
      end
    end, "Cancel selection and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.focus_tree)) do
    map("n", chord, function()
      tree.toggle()
    end, "Focus or toggle (for float) hunk.nvim file-tree")
  end

  -- For the tree buffer in float mode, register close bindings after quit so
  -- they shadow any overlapping key (e.g. both quit and close bound to <Esc>).
  if config.ui.tree.use_float and buf == tree.buf then
    for _, chord in ipairs(utils.into_table(config.ui.tree.float.close)) do
      map("n", chord, function()
        tree.close()
      end, "Close tree float")
    end
  end
end

local function open_file(layout, tree, change)
  local left_file
  local right_file

  local function on_file_event(event)
    if event.type == "toggle-lines" then
      if event.both_sides then
        toggle_line_pairs(change, event.file.side, event.lines)
        left_file.render()
        right_file.render()
      else
        toggle_lines(change, event.file.side, event.lines)
        event.file.render()
      end
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

    if event.type == "toggle-focus" then
      local win = left_file.win
      if event.side == "left" then
        win = right_file.win
      end
      vim.api.nvim_set_current_win(win)
      return
    end

    if event.type == "nav-file" then
      tree.nav_to_file(event.direction)
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

  set_global_bindings(layout, left_file.buf, tree)
  set_global_bindings(layout, right_file.buf, tree)

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
    popup = layout.tree_popup,
    changeset = changeset,
    on_open = function(change, opts)
      left_file, right_file = open_file(layout, opts.tree, change)
      vim.api.nvim_set_current_win(layout.right)
    end,
    on_preview = function(change, opts)
      left_file, right_file = open_file(layout, opts.tree, change)
      opts.tree.focus()
    end,
    on_toggle = function(change, value, opts)
      toggle_file(change, value)

      left_file.render()
      right_file.render()
      opts.tree.render()
    end,
  })

  tree.render()

  set_global_bindings(layout, tree.buf, tree)
end

--- Setup the plugin with user configuration.
---@param opts hunk.Config? User configuration overrides
function M.setup(opts)
  opts = opts or {}
  config.update_config(opts)
end

return M

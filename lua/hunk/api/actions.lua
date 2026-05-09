local changeset = require("hunk.api.changeset")
local utils = require("hunk.utils")
local config = require("hunk.config")
local ui = require("hunk.ui")

local M = {}

local function value_or_default(value, default)
  if value ~= nil then
    return value
  end
  return default
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

function M.toggle_file(change, value)
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

function M.toggle_lines(change, side, lines, value)
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

function M.toggle_line_pairs(change, reference_side, lines, value)
  local hunk
  for _, line in ipairs(lines) do
    if not hunk or not line_is_within_hunk_bounds(hunk, reference_side, line) then
      hunk = find_hunk_at_line(change.hunks, reference_side, line)
    end

    if value ~= nil then
      value = change.selected_lines[reference_side][line]
    end

    if hunk then
      M.toggle_lines(change, reference_side, { line }, value)

      local opposite_side = "left"
      if reference_side == "left" then
        opposite_side = "right"
      end

      local offset = (hunk[reference_side][1] - line) * -1
      if hunk[opposite_side][2] >= offset then
        local other_line = hunk[opposite_side][1] + offset
        M.toggle_lines(change, opposite_side, { other_line }, value)
      end
    end
  end
end

function M.toggle_hunk(change, side, line)
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

  M.toggle_lines(change, "left", left_lines, not any_selected)
  M.toggle_lines(change, "right", right_lines, not any_selected)
end

function M.set_global_bindings(session, buf)
  local layout = session.layout
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
      config.hooks.on_before_accept({ session = session })
      changeset.write_changeset(session.changeset, session.output or session.right)
      vim.cmd.qa()
    end, "qa")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.quit)) do
    map("n", chord, function()
      if config.ui.confirm_before_quit then
        vim.ui.select({ "Yes", "No" }, { prompt = "Quit without saving?" }, function(choice)
          if choice == "Yes" then
            config.hooks.on_before_quit({ session = session })
            vim.cmd.cq()
          end
        end)
      else
        config.hooks.on_before_quit({ session = session })
        vim.cmd.cq()
      end
    end, "Cancel selection and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.focus_tree)) do
    map("n", chord, function()
      vim.api.nvim_set_current_win(layout.tree)
    end, "Focus hunk.nvim file-tree")
  end
end

function M.open_file(session, tree, change)
  local layout = session.layout
  local left_file
  local right_file

  local function on_file_event(event)
    if event.type == "toggle-lines" then
      if event.both_sides then
        M.toggle_line_pairs(change, event.file.side, event.lines)
        left_file.render()
        right_file.render()
      else
        M.toggle_lines(change, event.file.side, event.lines)
        event.file.render()
      end
      tree.render()
      config.hooks.on_line_toggled({ change = change, side = event.file.side, lines = event.lines })
      return
    end

    if event.type == "toggle-hunk" then
      M.toggle_hunk(change, event.file.side, event.line)
      left_file.render()
      right_file.render()
      tree.render()
      config.hooks.on_hunk_toggled({ change = change, side = event.file.side, line = event.line })
      return
    end

    if event.type == "toggle-focus" then
      local win = left_file.win
      if event.side == "left" then
        win = right_file.win
      end
      vim.api.nvim_set_current_win(win)
      config.hooks.on_focus_changed({ side = event.side })
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

  M.set_global_bindings(session, left_file.buf)
  M.set_global_bindings(session, right_file.buf)

  return left_file, right_file
end

return M

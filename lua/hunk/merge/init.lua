local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")
local merge_layout = require("hunk.ui.merge_layout")
local hunks_mod = require("hunk.merge.hunks")
local highlight = require("hunk.merge.highlight")
local accept_mod = require("hunk.merge.accept")

local M = {}

local function create_readonly_buffer(file_path, name)
  local buf = vim.api.nvim_create_buf(false, false)
  local lines = api.fs.read_file_as_lines(file_path)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, name)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })

  vim.api.nvim_buf_call(buf, function()
    vim.cmd("filetype detect")
  end)

  return buf
end

local function create_center_buffer(base_path, name)
  local buf = vim.api.nvim_create_buf(false, false)
  local lines = api.fs.read_file_as_lines(base_path)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, name)

  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })

  vim.api.nvim_buf_call(buf, function()
    vim.cmd("filetype detect")
  end)

  return buf
end

local function get_buffer_lines(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return lines
end

local function accept_side_entirely(ctx, side)
  local side_buf = side == "left" and ctx.left_buf or ctx.right_buf
  local lines = get_buffer_lines(side_buf)
  if ctx.on_accept then
    ctx.on_accept(lines)
  end
end

local function automerge(ctx)
  for _, hunk in ipairs(ctx.all_hunks) do
    if hunk.state == "pending" and not hunk.conflict_pair then
      local side_buf = hunk.side == "left" and ctx.left_buf or ctx.right_buf
      accept_mod.accept(ctx.center_buf, side_buf, hunk)
    end
  end
  highlight.refresh_side_signs(ctx.left_buf, ctx.left_hunks)
  highlight.refresh_side_signs(ctx.right_buf, ctx.right_hunks)
  highlight.refresh_center_highlights(ctx.center_buf, ctx.all_hunks, accept_mod.get_extmark_range)
end

local function set_side_keybindings(buf, ctx)
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = buf,
      desc = desc,
      nowait = true,
    })
  end

  local side = ctx.side
  local side_hunks = ctx.hunks
  local side_buf = buf

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept)) do
    map("n", chord, function()
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed
      local hunk = hunks_mod.find_hunk_at_side_line(side_hunks, cursor_line)
      if not hunk then
        return
      end
      accept_mod.accept(ctx.center_buf, side_buf, hunk)
      highlight.refresh_side_signs(side_buf, side_hunks)
      highlight.refresh_center_highlights(ctx.center_buf, ctx.all_hunks, accept_mod.get_extmark_range)
    end, "Accept hunk into center")
  end

  map("n", "u", function()
    vim.api.nvim_buf_call(ctx.center_buf, function()
      vim.cmd("undo")
    end)
  end, "Undo in center buffer")

  map("n", "<C-r>", function()
    vim.api.nvim_buf_call(ctx.center_buf, function()
      vim.cmd("redo")
    end)
  end, "Redo in center buffer")

  for _, chord in ipairs(utils.into_table(config.keys.merge.next_hunk)) do
    map("n", chord, function()
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
      for _, hunk in ipairs(side_hunks) do
        if hunk.state == "pending" and hunk.side_start > cursor_line then
          vim.api.nvim_win_set_cursor(0, { hunk.side_start + 1, 0 })
          return
        end
      end
    end, "Next pending hunk")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.prev_hunk)) do
    map("n", chord, function()
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
      for i = #side_hunks, 1, -1 do
        local hunk = side_hunks[i]
        if hunk.state == "pending" and hunk.side_start < cursor_line then
          vim.api.nvim_win_set_cursor(0, { hunk.side_start + 1, 0 })
          return
        end
      end
    end, "Previous pending hunk")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept_all_left)) do
    map("n", chord, function()
      accept_side_entirely(ctx, "left")
    end, "Accept left entirely and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept_all_right)) do
    map("n", chord, function()
      accept_side_entirely(ctx, "right")
    end, "Accept right entirely and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.automerge)) do
    map("n", chord, function()
      automerge(ctx)
    end, "Accept all non-conflicting hunks")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.accept)) do
    map("n", chord, function()
      if ctx.on_accept then
        ctx.on_accept(get_buffer_lines(ctx.center_buf))
      end
    end, "Accept merge and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.quit)) do
    map("n", chord, function()
      if ctx.on_cancel then
        ctx.on_cancel()
      end
    end, "Cancel merge and quit")
  end
end

local function set_center_keybindings(buf, ctx)
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = buf,
      desc = desc,
      nowait = true,
    })
  end

  local function find_hunk_at_cursor(side)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    for _, hunk in ipairs(ctx.all_hunks) do
      if hunk.state == "pending" and hunk.side == side then
        local start_row, end_row, invalid = accept_mod.get_extmark_range(ctx.center_buf, hunk)
        if start_row then
          local is_conflict_second = invalid and hunk.conflict_pair and hunk.conflict_pair.state == "accepted"

          if not invalid or is_conflict_second then
            if hunk.base_count == 0 then
              if cursor_line == start_row or cursor_line == start_row + 1 then
                return hunk
              end
            elseif is_conflict_second then
              if cursor_line == math.max(0, start_row - 1) then
                return hunk
              end
            else
              if cursor_line >= start_row and cursor_line < end_row then
                return hunk
              end
            end
          end
        end
      end
    end
    return nil
  end

  local function accept_side(side)
    local hunk = find_hunk_at_cursor(side)
    if not hunk then
      return
    end
    local side_buf = side == "left" and ctx.left_buf or ctx.right_buf
    local side_hunks = side == "left" and ctx.left_hunks or ctx.right_hunks
    accept_mod.accept(ctx.center_buf, side_buf, hunk)
    highlight.refresh_side_signs(side_buf, side_hunks)
    highlight.refresh_center_highlights(ctx.center_buf, ctx.all_hunks, accept_mod.get_extmark_range)
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept_left)) do
    map("n", chord, function()
      accept_side("left")
    end, "Accept left hunk at cursor")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept_right)) do
    map("n", chord, function()
      accept_side("right")
    end, "Accept right hunk at cursor")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept_all_left)) do
    map("n", chord, function()
      accept_side_entirely(ctx, "left")
    end, "Accept left entirely and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.accept_all_right)) do
    map("n", chord, function()
      accept_side_entirely(ctx, "right")
    end, "Accept right entirely and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.merge.automerge)) do
    map("n", chord, function()
      automerge(ctx)
    end, "Accept all non-conflicting hunks")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.accept)) do
    map("n", chord, function()
      if ctx.on_accept then
        ctx.on_accept(get_buffer_lines(ctx.center_buf))
      end
    end, "Accept merge and quit")
  end

  for _, chord in ipairs(utils.into_table(config.keys.global.quit)) do
    map("n", chord, function()
      if ctx.on_cancel then
        ctx.on_cancel()
      end
    end, "Cancel merge and quit")
  end
end

function M.start_session(opts)
  local base_lines = opts.base_lines
  local left_lines = opts.left_lines
  local right_lines = opts.right_lines
  local path = opts.path or "[merge]"
  local on_accept = opts.on_accept
  local on_cancel = opts.on_cancel

  highlight.define_highlights()

  local left_hunks = hunks_mod.compute_hunks(base_lines, left_lines, "left")
  local right_hunks = hunks_mod.compute_hunks(base_lines, right_lines, "right")
  hunks_mod.detect_conflicts(left_hunks, right_hunks)

  -- Assign per-side labels
  for i, h in ipairs(left_hunks) do
    h.label = "L" .. i
  end
  for i, h in ipairs(right_hunks) do
    h.label = "R" .. i
  end

  local all_hunks = {}
  for _, h in ipairs(left_hunks) do
    table.insert(all_hunks, h)
  end
  for _, h in ipairs(right_hunks) do
    table.insert(all_hunks, h)
  end

  local layout = merge_layout.create_layout()

  local left_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, left_lines)
  vim.api.nvim_buf_set_name(left_buf, "hunk:left://" .. path)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = left_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = left_buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = left_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = left_buf })
  vim.api.nvim_buf_call(left_buf, function()
    vim.cmd("filetype detect")
  end)

  local center_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(center_buf, 0, -1, false, base_lines)
  vim.api.nvim_buf_set_name(center_buf, path)
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = center_buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = center_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = center_buf })
  vim.api.nvim_buf_call(center_buf, function()
    vim.cmd("filetype detect")
  end)

  local right_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, right_lines)
  vim.api.nvim_buf_set_name(right_buf, "hunk:right://" .. path)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = right_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = right_buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = right_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = right_buf })
  vim.api.nvim_buf_call(right_buf, function()
    vim.cmd("filetype detect")
  end)

  vim.api.nvim_win_set_buf(layout.left, left_buf)
  vim.api.nvim_win_set_buf(layout.center, center_buf)
  vim.api.nvim_win_set_buf(layout.right, right_buf)

  -- Annotate deleted side buffers
  local ns_deleted = vim.api.nvim_create_namespace("hunk_merge_deleted")
  if #left_lines == 0 then
    vim.api.nvim_buf_set_extmark(left_buf, ns_deleted, 0, 0, {
      virt_text = { { "(file deleted)", "HunkMergeSignDeleted" } },
      virt_text_pos = "overlay",
    })
  end
  if #right_lines == 0 then
    vim.api.nvim_buf_set_extmark(right_buf, ns_deleted, 0, 0, {
      virt_text = { { "(file deleted)", "HunkMergeSignDeleted" } },
      virt_text_pos = "overlay",
    })
  end

  -- Force an undo break so the initial buffer population is the base undo state.
  -- Without this, the first accept would be joined with the initial set_lines
  -- and undo would revert all the way to an empty buffer.
  local ul = vim.api.nvim_get_option_value("undolevels", { buf = center_buf })
  vim.api.nvim_set_option_value("undolevels", ul, { buf = center_buf })

  -- Place tracking extmarks in center buffer
  for _, hunk in ipairs(all_hunks) do
    accept_mod.place_extmark(center_buf, hunk)
  end

  -- Apply highlighting
  highlight.apply_initial_highlights(left_buf, right_buf, left_hunks, right_hunks)
  highlight.refresh_center_highlights(center_buf, all_hunks, accept_mod.get_extmark_range)

  -- Enable diffthis for filler lines and scroll alignment, but suppress
  -- diff highlighting via winhl so our extmark-based highlights take over.
  -- We remap to an empty highlight group (not Normal, which has bg set).
  vim.api.nvim_set_hl(0, "HunkMergeNone", {})

  local diff_winhl = table.concat({
    "DiffAdd:HunkMergeNone",
    "DiffChange:HunkMergeNone",
    "DiffDelete:Comment", -- This makes the filler lines dimmer
    "DiffText:HunkMergeNone",
    "CursorLine:HunkCursorLine",
  }, ",")

  for _, win in ipairs({ layout.left, layout.center, layout.right }) do
    vim.api.nvim_set_current_win(win)
    vim.cmd("diffthis")
    vim.api.nvim_set_option_value("winhl", diff_winhl, { win = win })
  end

  -- Focus center
  vim.api.nvim_set_current_win(layout.center)

  -- Undo/redo reconciliation and highlight refresh on every buffer change
  local function get_center_seq()
    return vim.api.nvim_buf_call(center_buf, function()
      return vim.fn.changenr()
    end)
  end

  local last_seq = get_center_seq()

  local function on_center_change()
    local cur_seq = get_center_seq()
    if cur_seq < last_seq then
      -- Undo: restore hunks whose accept was reverted
      for _, hunk in ipairs(all_hunks) do
        if hunk.state == "accepted" and hunk.accepted_at_seq and cur_seq < hunk.accepted_at_seq then
          local side_buf = hunk.side == "left" and left_buf or right_buf
          accept_mod.restore(center_buf, side_buf, hunk)
        end
      end
      highlight.refresh_side_signs(left_buf, left_hunks)
      highlight.refresh_side_signs(right_buf, right_hunks)
    elseif cur_seq > last_seq and cur_seq - last_seq == 1 then
      -- Single step forward: likely a redo. Re-consume hunks whose
      -- accepted_at_seq was crossed over.
      for _, hunk in ipairs(all_hunks) do
        if hunk.state == "pending" and hunk.accepted_at_seq and hunk.accepted_at_seq <= cur_seq and hunk.accepted_at_seq > last_seq then
          local side_buf = hunk.side == "left" and left_buf or right_buf
          accept_mod.reconsume(center_buf, side_buf, hunk)
        end
      end
      highlight.refresh_side_signs(left_buf, left_hunks)
      highlight.refresh_side_signs(right_buf, right_hunks)
    end
    last_seq = cur_seq
    highlight.refresh_center_highlights(center_buf, all_hunks, accept_mod.get_extmark_range)
  end

  vim.api.nvim_buf_attach(center_buf, false, {
    on_lines = function()
      vim.schedule(on_center_change)
      return false
    end,
  })

  -- Set keybindings
  local left_ctx = {
    side = "left",
    hunks = left_hunks,
    all_hunks = all_hunks,
    center_buf = center_buf,
    left_buf = left_buf,
    right_buf = right_buf,
    left_hunks = left_hunks,
    right_hunks = right_hunks,
    on_accept = on_accept,
    on_cancel = on_cancel,
  }

  local right_ctx = {
    side = "right",
    hunks = right_hunks,
    all_hunks = all_hunks,
    center_buf = center_buf,
    left_buf = left_buf,
    right_buf = right_buf,
    left_hunks = left_hunks,
    right_hunks = right_hunks,
    on_accept = on_accept,
    on_cancel = on_cancel,
  }

  local center_ctx = {
    center_buf = center_buf,
    all_hunks = all_hunks,
    left_hunks = left_hunks,
    right_hunks = right_hunks,
    left_buf = left_buf,
    right_buf = right_buf,
    on_accept = on_accept,
    on_cancel = on_cancel,
  }

  set_side_keybindings(left_buf, left_ctx)
  set_side_keybindings(right_buf, right_ctx)
  set_center_keybindings(center_buf, center_ctx)
end

function M.start(base, left, right, output, path)
  local base_lines = api.fs.read_file_as_lines(base)
  local left_lines = api.fs.read_file_as_lines(left)
  local right_lines = api.fs.read_file_as_lines(right)

  M.start_session({
    base_lines = base_lines,
    left_lines = left_lines,
    right_lines = right_lines,
    path = path or output,
    on_accept = function(lines)
      api.fs.write_file(output, lines)
      vim.cmd.qa()
    end,
    on_cancel = function()
      vim.cmd.cq()
    end,
  })
end

return M

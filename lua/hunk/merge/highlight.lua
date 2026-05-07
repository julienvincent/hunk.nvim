local config = require("hunk.config")

local M = {}

local ns_left = vim.api.nvim_create_namespace("hunk_merge_left")
local ns_right = vim.api.nvim_create_namespace("hunk_merge_right")
local ns_center = vim.api.nvim_create_namespace("hunk_merge_center")

function M.get_ns_for_side(side)
  if side == "left" then
    return ns_left
  else
    return ns_right
  end
end

--- Define highlight groups used by the merge editor.
function M.define_highlights()
  local function resolve_hl(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    hl.default = nil
    return hl
  end

  local diff_add = resolve_hl("DiffAdd")
  local diff_change = resolve_hl("DiffChange")
  local diff_delete = resolve_hl("DiffDelete")
  local diff_text = resolve_hl("DiffText")
  local comment = resolve_hl("Comment")

  vim.api.nvim_set_hl(0, "HunkMergeAdd", diff_add)
  vim.api.nvim_set_hl(0, "HunkMergeChange", diff_change)
  vim.api.nvim_set_hl(0, "HunkMergeDelete", diff_delete)
  vim.api.nvim_set_hl(0, "HunkMergeText", diff_text)

  vim.api.nvim_set_hl(0, "HunkMergeSignAdded", { link = "Green" })
  vim.api.nvim_set_hl(0, "HunkMergeSignChanged", { link = "Blue" })
  vim.api.nvim_set_hl(0, "HunkMergeSignDeleted", { link = "Red" })
  vim.api.nvim_set_hl(0, "HunkMergeSignPending", { link = "Red" })
  vim.api.nvim_set_hl(0, "HunkMergeSignAccepted", { link = "Green" })

  vim.api.nvim_set_hl(0, "HunkMergeLabel", { fg = comment.fg })

  local normal_hl = vim.api.nvim_get_hl(0, { name = "Comment" })
  local cursor_bg = normal_hl.fg and string.format("#%06x", normal_hl.fg)
  vim.api.nvim_set_hl(0, "HunkCursorLine", { fg = "NONE", bg = "NONE", underline = true, sp = cursor_bg })

  -- Define signs for the merge editor
  vim.fn.sign_define({
    { name = "HunkMergePendingAdded", text = config.icons.deselected, texthl = "HunkMergeSignAdded" },
    { name = "HunkMergePendingChanged", text = config.icons.deselected, texthl = "HunkMergeSignChanged" },
    { name = "HunkMergePendingDeleted", text = config.icons.deselected, texthl = "HunkMergeSignDeleted" },
    { name = "HunkMergeAcceptedAdded", text = config.icons.selected, texthl = "HunkMergeSignAccepted" },
    { name = "HunkMergeAcceptedChanged", text = config.icons.selected, texthl = "HunkMergeSignAccepted" },
    { name = "HunkMergeAcceptedDeleted", text = config.icons.selected, texthl = "HunkMergeSignAccepted" },
  })
end

--- Get the line-level highlight group for a hunk type.
---@param hunk_type string "added"|"modified"|"deleted"
---@return string
local function line_hl_for_type(hunk_type)
  if hunk_type == "added" then
    return "HunkMergeAdd"
  elseif hunk_type == "modified" then
    return "HunkMergeChange"
  else
    return "HunkMergeDelete"
  end
end

--- Get the sign highlight group for a hunk type (pending state).
---@param hunk_type string
---@return string
local function sign_hl_for_type(hunk_type)
  if hunk_type == "added" then
    return "HunkMergeSignAdded"
  elseif hunk_type == "modified" then
    return "HunkMergeSignChanged"
  else
    return "HunkMergeSignDeleted"
  end
end

--- Get the sign name for a pending hunk.
---@param hunk_type string
---@return string
local function pending_sign_for_type(hunk_type)
  if hunk_type == "added" then
    return "HunkMergePendingAdded"
  elseif hunk_type == "modified" then
    return "HunkMergePendingChanged"
  else
    return "HunkMergePendingDeleted"
  end
end

--- Get the sign name for an accepted hunk.
---@param hunk_type string
---@return string
local function accepted_sign_for_type(hunk_type)
  if hunk_type == "added" then
    return "HunkMergeAcceptedAdded"
  elseif hunk_type == "modified" then
    return "HunkMergeAcceptedChanged"
  else
    return "HunkMergeAcceptedDeleted"
  end
end

local SIGN_GROUP = "HunkMerge"

--- Place signs for a hunk on a side buffer.
---@param buf number
---@param hunk table
---@param sign_name string
local function place_signs(buf, hunk, sign_name)
  for i = 0, hunk.side_count - 1 do
    local lnum = hunk.side_start + i + 1 -- sign_place uses 1-indexed
    vim.fn.sign_place(0, SIGN_GROUP, sign_name, buf, { lnum = lnum, priority = 100 })
  end
end

--- Clear signs for a hunk's lines on a side buffer.
---@param buf number
local function clear_all_signs(buf)
  vim.fn.sign_unplace(SIGN_GROUP, { buffer = buf })
end

--- Place all signs for a list of hunks on a side buffer based on their state.
---@param buf number
---@param hunks table[]
function M.refresh_side_signs(buf, hunks)
  clear_all_signs(buf)
  for _, hunk in ipairs(hunks) do
    if hunk.side_count > 0 then
      local sign_name
      if hunk.state == "accepted" then
        sign_name = accepted_sign_for_type(hunk.type)
      else
        sign_name = pending_sign_for_type(hunk.type)
      end
      place_signs(buf, hunk, sign_name)
    end
  end
end

--- Compute character-level diff between two lines.
--- Returns byte ranges of changed characters on each side.
---@param line_a string
---@param line_b string
---@return table[] a_ranges list of {start_byte, end_byte} (0-indexed, exclusive end)
---@return table[] b_ranges list of {start_byte, end_byte} (0-indexed, exclusive end)
function M.compute_inline_diff(line_a, line_b)
  if line_a == line_b then
    return {}, {}
  end

  local function to_char_lines(s)
    local chars = {}
    local byte_offsets = {}
    local i = 1
    while i <= #s do
      local byte = s:byte(i)
      local charlen = 1
      if byte >= 0xF0 then
        charlen = 4
      elseif byte >= 0xE0 then
        charlen = 3
      elseif byte >= 0xC0 then
        charlen = 2
      end
      table.insert(byte_offsets, i - 1)
      table.insert(chars, s:sub(i, i + charlen - 1))
      i = i + charlen
    end
    table.insert(byte_offsets, #s)
    return table.concat(chars, "\n") .. "\n", byte_offsets
  end

  local text_a, offsets_a = to_char_lines(line_a)
  local text_b, offsets_b = to_char_lines(line_b)

  local raw_hunks = vim.text.diff(text_a, text_b, {
    result_type = "indices",
    algorithm = "minimal",
  })

  if type(raw_hunks) ~= "table" then
    return {}, {}
  end

  local a_ranges = {}
  local b_ranges = {}

  for _, hunk in ipairs(raw_hunks) do
    local sa, ca, sb, cb = hunk[1], hunk[2], hunk[3], hunk[4]
    if ca > 0 then
      local start_byte = offsets_a[sa]
      local end_byte = offsets_a[sa + ca]
      table.insert(a_ranges, { start_byte, end_byte })
    end
    if cb > 0 then
      local start_byte = offsets_b[sb]
      local end_byte = offsets_b[sb + cb]
      table.insert(b_ranges, { start_byte, end_byte })
    end
  end

  return a_ranges, b_ranges
end

--- Apply inline diff extmarks for modified lines on a buffer.
---@param buf number buffer handle
---@param ns number namespace
---@param buf_line number 0-indexed line in buffer
---@param base_line string the base/reference line
---@param side_line string the side line (what's in the buffer)
local function apply_inline_highlights(buf, ns, buf_line, base_line, side_line)
  local _, b_ranges = M.compute_inline_diff(base_line, side_line)
  for _, range in ipairs(b_ranges) do
    vim.api.nvim_buf_set_extmark(buf, ns, buf_line, range[1], {
      end_col = range[2],
      hl_group = "HunkMergeText",
      priority = 101,
    })
  end
end

--- Compute similarity between two lines using character-level diff.
--- Returns a score between 0 and 1 (1 = identical).
---@param line_a string
---@param line_b string
---@return number
local function line_similarity(line_a, line_b)
  if line_a == line_b then
    return 1.0
  end
  if #line_a == 0 and #line_b == 0 then
    return 1.0
  end
  if #line_a == 0 or #line_b == 0 then
    return 0.0
  end

  local a_ranges, b_ranges = M.compute_inline_diff(line_a, line_b)

  local a_changed = 0
  for _, range in ipairs(a_ranges) do
    a_changed = a_changed + (range[2] - range[1])
  end

  local b_changed = 0
  for _, range in ipairs(b_ranges) do
    b_changed = b_changed + (range[2] - range[1])
  end

  local total_chars = #line_a + #line_b
  local total_changed = a_changed + b_changed
  return 1.0 - (total_changed / total_chars)
end

--- Match base lines to side lines by similarity.
--- Returns a table mapping side line index (0-based) to base line index (0-based),
--- or nil if the side line is unmatched (pure addition).
---@param base_lines string[]
---@param side_lines string[]
---@return table<number, number|nil> side_to_base mapping
function M.match_lines(base_lines, side_lines)
  local side_to_base = {}

  if #base_lines == 0 then
    return side_to_base
  end

  -- Compute similarity matrix
  local scores = {}
  for si = 1, #side_lines do
    scores[si] = {}
    for bi = 1, #base_lines do
      scores[si][bi] = line_similarity(base_lines[bi], side_lines[si])
    end
  end

  -- Greedy matching: repeatedly pick the highest-scoring pair
  local used_base = {}
  local used_side = {}

  for _ = 1, math.min(#base_lines, #side_lines) do
    local best_score = -1
    local best_si, best_bi

    for si = 1, #side_lines do
      if not used_side[si] then
        for bi = 1, #base_lines do
          if not used_base[bi] and scores[si][bi] > best_score then
            best_score = scores[si][bi]
            best_si = si
            best_bi = bi
          end
        end
      end
    end

    if not best_si or best_score < 0.1 then
      break
    end

    side_to_base[best_si - 1] = best_bi - 1
    used_base[best_bi] = true
    used_side[best_si] = true
  end

  return side_to_base
end

--- Clear all extmarks for a hunk on a side buffer.
---@param buf number buffer handle
---@param hunk table hunk descriptor
local function clear_side_extmarks(buf, hunk)
  local ns = M.get_ns_for_side(hunk.side)

  if hunk.side_count == 0 then
    return
  end

  for i = 0, hunk.side_count - 1 do
    local line = hunk.side_start + i
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { line, 0 }, { line, -1 }, {})
    for _, mark in ipairs(marks) do
      vim.api.nvim_buf_del_extmark(buf, ns, mark[1])
    end
  end
end

--- Apply pending state highlighting to a side buffer for a hunk.
---@param buf number buffer handle
---@param hunk table hunk descriptor
function M.highlight_side_hunk(buf, hunk)
  local ns = M.get_ns_for_side(hunk.side)

  if hunk.side_count == 0 then
    return
  end

  clear_side_extmarks(buf, hunk)

  local line_hl = line_hl_for_type(hunk.type)

  -- Compute line matching for modified hunks
  local side_to_base
  if hunk.type == "modified" then
    side_to_base = M.match_lines(hunk.base_lines, hunk.side_lines)
  end

  for i = 0, hunk.side_count - 1 do
    local line = hunk.side_start + i

    -- Unmatched lines in a modified hunk are pure additions
    local this_line_hl = line_hl
    if hunk.type == "modified" and side_to_base and not side_to_base[i] then
      this_line_hl = "HunkMergeAdd"
    end

    local opts = {
      hl_group = this_line_hl,
      end_row = line + 1,
      end_col = 0,
      hl_eol = true,
      priority = 100,
    }

    if i == 0 then
      opts.virt_text = { { " " .. hunk.label, "HunkMergeLabel" } }
      opts.virt_text_pos = "eol"
    end

    vim.api.nvim_buf_set_extmark(buf, ns, line, 0, opts)

    -- Word-level highlighting for matched modified lines
    if hunk.type == "modified" and side_to_base and side_to_base[i] then
      local base_line = hunk.base_lines[side_to_base[i] + 1]
      local side_line = hunk.side_lines[i + 1]
      if base_line and side_line then
        apply_inline_highlights(buf, ns, line, base_line, side_line)
      end
    end
  end
end

--- Apply accepted state to a side buffer for a hunk.
---@param buf number buffer handle
---@param hunk table hunk descriptor
function M.mark_side_hunk_accepted(buf, hunk)
  local ns = M.get_ns_for_side(hunk.side)

  if hunk.side_count == 0 then
    return
  end

  clear_side_extmarks(buf, hunk)

  for i = 0, hunk.side_count - 1 do
    local line = hunk.side_start + i
    local opts = {}

    if i == 0 then
      opts.virt_text = { { " " .. hunk.label, "HunkMergeLabel" } }
      opts.virt_text_pos = "eol"
    end

    vim.api.nvim_buf_set_extmark(buf, ns, line, 0, opts)
  end
end

--- Refresh center buffer highlights by reading live tracking extmark positions.
---@param buf number center buffer handle
---@param hunks table[] all hunks
---@param get_extmark_range function(buf, hunk) -> start_row, end_row, invalid
function M.refresh_center_highlights(buf, hunks, get_extmark_range)
  vim.api.nvim_buf_clear_namespace(buf, ns_center, 0, -1)

  local line_labels = {}

  for _, hunk in ipairs(hunks) do
    if hunk.state == "pending" and hunk.extmark_id then
      local start_row, end_row, invalid = get_extmark_range(buf, hunk)
      if start_row then
        local is_conflict_second = invalid and hunk.conflict_pair and hunk.conflict_pair.state == "accepted"

        if not invalid then
          local line_hl = line_hl_for_type(hunk.type)

          if hunk.base_count == 0 then
            -- Pure insertion: show label on the anchor line
            if not line_labels[start_row] then
              line_labels[start_row] = {}
            end
            table.insert(line_labels[start_row], hunk.label)
          else
            -- Range: highlight lines and apply word-level diff
            local center_lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, false)

            -- Compute line matching for modified hunks
            local center_to_side
            if hunk.type == "modified" then
              center_to_side = M.match_lines(hunk.side_lines, center_lines)
            end

            for line = start_row, end_row - 1 do
              local line_idx = line - start_row
              local line_text = center_lines[line_idx + 1] or ""

              vim.api.nvim_buf_set_extmark(buf, ns_center, line, 0, {
                hl_group = line_hl,
                end_row = line + 1,
                end_col = 0,
                hl_eol = true,
                priority = 100,
              })

              -- Word-level diff for matched modified lines
              if hunk.type == "modified" and center_to_side and center_to_side[line_idx] then
                local side_line = hunk.side_lines[center_to_side[line_idx] + 1]
                local center_line = line_text
                if center_line and side_line and center_line ~= side_line then
                  local a_ranges, _ = M.compute_inline_diff(center_line, side_line)
                  for _, range in ipairs(a_ranges) do
                    if range[1] < #center_line and range[2] <= #center_line then
                      vim.api.nvim_buf_set_extmark(buf, ns_center, line, range[1], {
                        end_col = range[2],
                        hl_group = "HunkMergeText",
                        priority = 101,
                      })
                    end
                  end
                end
              end
            end

            if not line_labels[start_row] then
              line_labels[start_row] = {}
            end
            table.insert(line_labels[start_row], hunk.label)
          end
        elseif is_conflict_second then
          local label_line = math.max(0, start_row - 1)
          if not line_labels[label_line] then
            line_labels[label_line] = {}
          end
          table.insert(line_labels[label_line], hunk.label)
        end
      end
    end
  end

  -- Place virtual text labels
  for line, labels in pairs(line_labels) do
    local text = " " .. table.concat(labels, " ")
    vim.api.nvim_buf_set_extmark(buf, ns_center, line, 0, {
      virt_text = { { text, "HunkMergeLabel" } },
      virt_text_pos = "eol",
    })
  end
end

--- Apply all initial highlights for side buffers.
---@param left_buf number
---@param right_buf number
---@param left_hunks table[]
---@param right_hunks table[]
function M.apply_initial_highlights(left_buf, right_buf, left_hunks, right_hunks)
  for _, hunk in ipairs(left_hunks) do
    M.highlight_side_hunk(left_buf, hunk)
  end
  for _, hunk in ipairs(right_hunks) do
    M.highlight_side_hunk(right_buf, hunk)
  end
  M.refresh_side_signs(left_buf, left_hunks)
  M.refresh_side_signs(right_buf, right_hunks)
end

return M

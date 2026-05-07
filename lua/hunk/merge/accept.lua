local highlight = require("hunk.merge.highlight")

local M = {}

local ns_tracking = vim.api.nvim_create_namespace("hunk_merge_tracking")

function M.get_ns_tracking()
  return ns_tracking
end

--- Place a tracking extmark in the center buffer for a hunk.
---@param center_buf number
---@param hunk table
function M.place_extmark(center_buf, hunk)
  if hunk.base_count == 0 then
    local line_count = vim.api.nvim_buf_line_count(center_buf)
    local mark_row = math.max(0, math.min(hunk.base_start, line_count - 1))
    hunk.extmark_id = vim.api.nvim_buf_set_extmark(center_buf, ns_tracking, mark_row, 0, {
      right_gravity = true,
    })
    hunk._insert_after = true
  else
    local line_count = vim.api.nvim_buf_line_count(center_buf)
    local start_row = math.max(0, math.min(hunk.base_start, line_count - 1))
    local end_row = math.min(hunk.base_start + hunk.base_count, line_count)
    hunk.extmark_id = vim.api.nvim_buf_set_extmark(center_buf, ns_tracking, start_row, 0, {
      end_row = end_row,
      end_col = 0,
      right_gravity = true,
      end_right_gravity = false,
      invalidate = true,
    })
    hunk._insert_after = false
  end
end

--- Get the current tracked position of a hunk's extmark.
---@param center_buf number
---@param hunk table
---@return number|nil start_row
---@return number|nil end_row
---@return boolean invalid
function M.get_extmark_range(center_buf, hunk)
  if not hunk.extmark_id then
    return nil, nil, true
  end

  local mark = vim.api.nvim_buf_get_extmark_by_id(
    center_buf,
    ns_tracking,
    hunk.extmark_id,
    { details = true }
  )

  if not mark or #mark == 0 then
    return nil, nil, true
  end

  local start_row = mark[1]
  local details = mark[3]
  local invalid = details and details.invalid or false

  local end_row = start_row
  if details and details.end_row then
    end_row = details.end_row
  end

  return start_row, end_row, invalid
end

--- Accept a hunk: apply its content to the center buffer.
---@param center_buf number
---@param side_buf number
---@param hunk table
function M.accept(center_buf, side_buf, hunk)
  if hunk.state ~= "pending" then
    return
  end

  local start_row, end_row, invalid = M.get_extmark_range(center_buf, hunk)

  if start_row == nil then
    return
  end

  -- Force an undo break so each accept is its own undo entry
  local ul = vim.api.nvim_get_option_value("undolevels", { buf = center_buf })
  vim.api.nvim_set_option_value("undolevels", ul, { buf = center_buf })

  local is_conflict_second = hunk.conflict_pair and hunk.conflict_pair.state == "accepted"

  if hunk._insert_after then
    -- Pure insertion: insert after the tracked line, or at line 0 for prepend
    local insert_at = hunk._prepend and start_row or (start_row + 1)
    vim.api.nvim_buf_set_lines(center_buf, insert_at, insert_at, false, hunk.side_lines)
  elseif is_conflict_second then
    -- Second accept of a conflict pair.
    -- With right_gravity=true, the extmark has been pushed past the first
    -- accept's content. Just insert at start_row.
    vim.api.nvim_buf_set_lines(center_buf, start_row, start_row, false, hunk.side_lines)
  elseif invalid or (start_row == end_row and hunk.base_count > 0) then
    -- Range collapsed (user deleted it): insert at point
    if hunk.side_count > 0 then
      vim.api.nvim_buf_set_lines(center_buf, start_row, start_row, false, hunk.side_lines)
    end
  else
    -- Normal case: replace the tracked range
    if hunk.side_count == 0 then
      vim.api.nvim_buf_set_lines(center_buf, start_row, end_row, false, {})
    else
      vim.api.nvim_buf_set_lines(center_buf, start_row, end_row, false, hunk.side_lines)
    end
  end

  hunk.state = "accepted"
  hunk.accepted_at_seq = vim.api.nvim_buf_call(center_buf, function()
    return vim.fn.changenr()
  end)

  -- Mark side hunk as accepted (selected icons, no background)
  highlight.mark_side_hunk_accepted(side_buf, hunk)
end

--- Restore a hunk to pending state (used after undo).
--- The extmark is still alive and Neovim restored its position via undo,
--- so we just flip the state and re-apply side highlighting.
---@param center_buf number
---@param side_buf number
---@param hunk table
function M.restore(center_buf, side_buf, hunk)
  hunk.state = "pending"
  highlight.highlight_side_hunk(side_buf, hunk)
end

--- Re-consume a hunk after redo re-applies its accept.
--- The buffer change was already re-applied by redo, so we just
--- flip the state and mark side as accepted.
---@param center_buf number
---@param side_buf number
---@param hunk table
function M.reconsume(center_buf, side_buf, hunk)
  hunk.state = "accepted"
  highlight.mark_side_hunk_accepted(side_buf, hunk)
end

--- Restore a hunk to pending state (used after undo).
--- The extmark is still alive and Neovim restored its position via undo,
--- so we just flip the state and re-apply side highlighting.
--- We keep accepted_at_seq so redo can re-consume.
---@param center_buf number
---@param side_buf number
---@param hunk table
function M.restore(center_buf, side_buf, hunk)
  hunk.state = "pending"
  highlight.highlight_side_hunk(side_buf, hunk)
end

--- Re-consume a hunk after redo re-applies its accept.
--- The buffer change was already re-applied by redo, so we just
--- flip the state and clear side highlighting.
---@param center_buf number
---@param side_buf number
---@param hunk table
function M.reconsume(center_buf, side_buf, hunk)
  hunk.state = "accepted"
  highlight.mark_side_hunk_accepted(side_buf, hunk)
end

return M

local api = require("hunk.api")

local M = {}

--- Compute hunks between base and a side.
--- Returns a list of hunk descriptors for one side.
---@param base_lines string[]
---@param side_lines string[]
---@param side "left"|"right"
---@return table[] hunks
function M.compute_hunks(base_lines, side_lines, side)
  local base_text = table.concat(base_lines, "\n") .. "\n"
  local side_text = table.concat(side_lines, "\n") .. "\n"

  if #base_lines == 0 then
    base_text = ""
  end
  if #side_lines == 0 then
    side_text = ""
  end

  local raw_hunks = vim.diff(base_text, side_text, { result_type = "indices" })
  if type(raw_hunks) ~= "table" then
    return {}
  end

  local hunks = {}
  for _, raw in ipairs(raw_hunks) do
    local base_start = raw[1] -- 1-indexed
    local base_count = raw[2]
    local side_start = raw[3] -- 1-indexed
    local side_count = raw[4]

    local lines = {}
    for i = side_start, side_start + side_count - 1 do
      table.insert(lines, side_lines[i])
    end

    local bl = {}
    for i = base_start, base_start + base_count - 1 do
      table.insert(bl, base_lines[i])
    end

    local hunk_type
    if base_count == 0 then
      hunk_type = "added"
    elseif side_count == 0 then
      hunk_type = "deleted"
    else
      hunk_type = "modified"
    end

    table.insert(hunks, {
      side = side,
      type = hunk_type,

      -- 0-indexed for extmark/buffer API compatibility.
      -- vim.diff returns 0 for base_start when inserting before the first line.
      base_start = math.max(base_start - 1, 0),
      base_count = base_count,
      base_lines = bl,
      _prepend = base_count == 0 and base_start == 0,

      -- 0-indexed
      side_start = side_start - 1,
      side_count = side_count,

      side_lines = lines,

      extmark_id = nil,
      conflict_pair = nil,
      state = "pending",
    })
  end

  return hunks
end

--- Detect conflicts between left and right hunks.
--- Two hunks conflict if their base ranges overlap.
--- Links them via conflict_pair.
---@param left_hunks table[]
---@param right_hunks table[]
function M.detect_conflicts(left_hunks, right_hunks)
  for _, lh in ipairs(left_hunks) do
    for _, rh in ipairs(right_hunks) do
      if M.ranges_overlap(lh.base_start, lh.base_count, rh.base_start, rh.base_count) then
        lh.conflict_pair = rh
        rh.conflict_pair = lh
      end
    end
  end
end

--- Check if two base ranges overlap.
---@param a_start number 0-indexed start
---@param a_count number line count
---@param b_start number 0-indexed start
---@param b_count number line count
---@return boolean
function M.ranges_overlap(a_start, a_count, b_start, b_count)
  if a_count == 0 and b_count == 0 then
    return a_start == b_start
  end
  if a_count == 0 then
    return a_start >= b_start and a_start < b_start + b_count
  end
  if b_count == 0 then
    return b_start >= a_start and b_start < a_start + a_count
  end
  local a_end = a_start + a_count
  local b_end = b_start + b_count
  return a_start < b_end and b_start < a_end
end

--- Find the hunk at a given line (0-indexed) in a side buffer.
---@param hunks table[]
---@param line number 0-indexed line
---@return table|nil
function M.find_hunk_at_side_line(hunks, line)
  for _, hunk in ipairs(hunks) do
    if hunk.state == "pending" then
      if hunk.side_count == 0 then
        -- Pure deletion: the hunk is anchored at side_start
        if line == hunk.side_start then
          return hunk
        end
      else
        if line >= hunk.side_start and line < hunk.side_start + hunk.side_count then
          return hunk
        end
      end
    end
  end
  return nil
end

return M

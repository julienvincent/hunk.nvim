local fs = require("difftool.api.fs")

local M = {}

function M.diff_file(left, right)
  local left_content = fs.read_file(left) or ""
  local right_content = fs.read_file(right) or ""
  local hunks = vim.diff(left_content, right_content, {
    result_type = "indices",
  })

  if type(hunks) ~= "table" then
    return {}
  end

  return vim.tbl_map(function(hunk)
    return {
      left = { hunk[1], hunk[2] },
      right = { hunk[3], hunk[4] },
    }
  end, hunks)
end

function M.apply_diff(left, right, change)
  local hunks = change.hunks
  local selected_lines = change.selected_lines

  local result = {}

  local left_index = 1
  local hunk_index = 1
  local hunk = hunks[hunk_index]

  if change.type == "added" then
    for i = hunk.right[1], hunk.right[1] + hunk.right[2] - 1 do
      if selected_lines.right[i] then
        table.insert(result, right[i])
      end
    end
    return result
  end

  while left_index <= #left do
    if hunk and left_index == hunk.left[1] then
      for i = left_index, left_index + hunk.left[2] - 1 do
        left_index = i
        if not selected_lines.left[i] then
          table.insert(result, left[i])
        end
      end

      if hunk.left[2] == 0 then
        table.insert(result, left[left_index])
      end

      for i = hunk.right[1], hunk.right[1] + hunk.right[2] - 1 do
        if selected_lines.right[i] then
          table.insert(result, right[i])
        end
      end

      hunk_index = hunk_index + 1
      hunk = hunks[hunk_index]
    else
      table.insert(result, left[left_index])
    end

    left_index = left_index + 1
  end

  return result
end

-- local hunks = {
--   {
--     left = { 1, 4 },
--     right = { 1, 1 },
--   },
--   {
--     left = { 6, 0 },
--     right = { 4, 3 },
--   },
-- }
--
-- M.apply_diff({ "a", "b", "c", "f", "e", "f" }, { "a1", "e", "f", "g", "h", "i" }, hunks, {
--   left = { [1] = true, [2] = true, [3] = true, [4] = true },
--   right = { [1] = true, [4] = true, [5] = true, [6] = true },
-- })
--
-- vim.diff("a\nb\nc\nf\ne\nf\n", "a1\ne\nf\ng\nh\ni\n", {
--   result_type = "indices",
-- })

return M

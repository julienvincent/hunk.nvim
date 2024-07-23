local utils = require("hunk.utils")
local fs = require("hunk.api.fs")

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

  if change.type == "added" or hunk.left[1] == 0 then
    for i in utils.hunk_lines(hunk.right) do
      if selected_lines.right[i] then
        table.insert(result, right[i])
      end
    end

    if change.type == "added" then
      return result
    end

    hunk_index = hunk_index + 1
    hunk = hunks[hunk_index]
  end

  while left_index <= #left do
    if hunk and left_index == hunk.left[1] then
      for i in utils.hunk_lines(hunk.left) do
        left_index = i
        if not selected_lines.left[i] then
          table.insert(result, left[i])
        end
      end

      if hunk.left[2] == 0 then
        table.insert(result, left[left_index])
      end

      for i in utils.hunk_lines(hunk.right) do
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

return M

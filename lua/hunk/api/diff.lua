local utils = require("hunk.utils")

local M = {}

-- Nil content means no bytes were captured (a symlink or an unreadable file).
function M.diff_file(left_content, right_content)
  if not left_content or not right_content then
    return {}
  end

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

local function alternating_hunk_lines(hunk)
  local left_i = hunk.left[1] - 1
  local right_i = hunk.right[1] - 1

  return function()
    left_i = left_i + 1
    right_i = right_i + 1

    local left_line = left_i
    local right_line = right_i
    if left_line >= hunk.left[1] + hunk.left[2] then
      left_line = nil
    end

    if right_line >= hunk.right[1] + hunk.right[2] then
      right_line = nil
    end

    if not left_line and not right_line then
      return
    end

    return { left_line, right_line }
  end
end

function M.apply_diff(left, right, change)
  local hunks = change.hunks
  local selected_lines = change.selected_lines

  local result = {}

  local left_index = 1
  local hunk_index = 1
  local hunk = hunks[hunk_index]

  if change.type == "added" then
    for i in utils.hunk_lines(hunk.right) do
      if selected_lines.right[i] then
        table.insert(result, right[i])
      end
    end

    return result
  end

  if hunk.left[1] == 0 then
    for i in utils.hunk_lines(hunk.right) do
      if selected_lines.right[i] then
        table.insert(result, right[i])
      end
    end

    hunk_index = hunk_index + 1
    hunk = hunks[hunk_index]
  end

  while left_index <= #left do
    if hunk and left_index == hunk.left[1] then
      if hunk.left[2] == 0 then
        table.insert(result, left[left_index])
      end

      for lines in alternating_hunk_lines(hunk) do
        local left_line = lines[1]
        local right_line = lines[2]

        if left_line then
          left_index = left_line
        end

        if left_line and not selected_lines.left[left_line] then
          table.insert(result, left[left_line])
        end

        if right_line and selected_lines.right[right_line] then
          table.insert(result, right[right_line])
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

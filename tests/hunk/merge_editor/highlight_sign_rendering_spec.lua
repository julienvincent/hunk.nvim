local merge_editor = require("tests.utils.merge_editor")

local function line_hl_groups(buf, ns_name, line_1idx)
  local marks = merge_editor.get_extmarks(buf, ns_name)
  local groups = {}
  for _, mark in ipairs(marks) do
    local row = mark[2]
    local details = mark[4]
    if row == line_1idx - 1 and details and details.hl_group then
      groups[details.hl_group] = true
    end
  end
  return groups
end

local function word_ranges(buf, ns_name)
  local marks = merge_editor.get_extmarks(buf, ns_name)
  local ranges = {}
  for _, mark in ipairs(marks) do
    local row = mark[2]
    local col = mark[3]
    local details = mark[4]
    if details and details.hl_group == "HunkMergeText" and details.end_col then
      table.insert(ranges, { row = row, col = col, end_col = details.end_col })
    end
  end
  return ranges
end

local function center_labels(buf)
  local marks = merge_editor.get_extmarks(buf, "hunk_merge_center")
  local labels = {}
  for _, mark in ipairs(marks) do
    local details = mark[4]
    if details and details.virt_text and details.virt_text[1] and details.virt_text[1][1] then
      table.insert(labels, details.virt_text[1][1])
    end
  end
  return table.concat(labels, " ")
end

local function wait_for_updates()
  vim.wait(20)
end

describe("merge editor: highlight/sign rendering", function()
  it("updates side signs from pending to accepted", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "one", "two" },
      left_lines = { "one", "changed" },
      right_lines = { "one", "two" },
    })

    local placed_before = vim.fn.sign_getplaced(session.left_buf, { group = "HunkMerge" })
    local sign_before = placed_before[1].signs[1]
    assert.is_true(sign_before.name:match("Pending") ~= nil)

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")

    local placed_after = vim.fn.sign_getplaced(session.left_buf, { group = "HunkMerge" })
    local sign_after = placed_after[1].signs[1]
    assert.is_true(sign_after.name:match("Accepted") ~= nil)
  end)

  it("renders expected line-level highlights on left, right, and center panes", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "zero", "cat dog", "keep", "gone", "tail" },
      left_lines = { "zero", "cat fox", "keep", "gone", "tail", "add" },
      right_lines = { "zero", "cat dog", "keep", "tail" },
    })

    local left_line2 = line_hl_groups(session.left_buf, "hunk_merge_left", 2)
    local left_line6 = line_hl_groups(session.left_buf, "hunk_merge_left", 6)
    local center_line2 = line_hl_groups(session.center_buf, "hunk_merge_center", 2)
    local center_line4 = line_hl_groups(session.center_buf, "hunk_merge_center", 4)

    assert.is_true(left_line2.HunkMergeChange == true)
    assert.is_true(left_line6.HunkMergeAdd == true)
    assert.is_true(center_line2.HunkMergeChange == true)
    assert.is_true(center_line4.HunkMergeDelete == true)
  end)

  it("renders correct word-level highlight ranges in side and center panes", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "same", "cat dog", "tail" },
      left_lines = { "same", "cat fox", "tail" },
      right_lines = { "same", "cat dog", "tail" },
    })

    local side_ranges = word_ranges(session.left_buf, "hunk_merge_left")
    local center_ranges = word_ranges(session.center_buf, "hunk_merge_center")

    assert.is_true(#side_ranges > 0)
    assert.is_true(#center_ranges > 0)
    assert.are.equal(1, side_ranges[1].row)
    assert.are.equal(1, center_ranges[1].row)
    assert.are.equal(4, side_ranges[1].col)
    assert.is_true(side_ranges[1].end_col > side_ranges[1].col)
    assert.are.equal(side_ranges[1].col, center_ranges[1].col)
    assert.are.equal(side_ranges[1].end_col, center_ranges[1].end_col)
  end)

  it("shows and clears center labels across accept, undo, and redo", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "line 1", "line 2", "line 3" },
      left_lines = { "line 1", "CHANGED", "line 3" },
      right_lines = { "line 1", "line 2", "line 3" },
    })

    wait_for_updates()
    assert.is_true(center_labels(session.center_buf):match("L1") ~= nil)

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")
    wait_for_updates()
    assert.is_nil(center_labels(session.center_buf):match("L1"))

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("u")
    wait_for_updates()
    assert.is_true(center_labels(session.center_buf):match("L1") ~= nil)

    merge_editor.press("<C-r>")
    wait_for_updates()
    assert.is_nil(center_labels(session.center_buf):match("L1"))
  end)
end)

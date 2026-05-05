local merge_editor = require("tests.utils.merge_editor")

describe("merge editor: automerge behavior", function()
  it("accepts only non-conflicting hunks", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "same", "conflict", "same", "tail" },
      left_lines = { "same", "LEFT", "same", "left-tail" },
      right_lines = { "same", "RIGHT", "same", "tail" },
    })

    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("gA")

    merge_editor.assert_content(session.center_buf, { "same", "conflict", "same", "left-tail" })
  end)

  it("is idempotent when run twice", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "same", "conflict", "same", "tail" },
      left_lines = { "same", "LEFT", "same", "left-tail" },
      right_lines = { "same", "RIGHT", "same", "tail" },
    })

    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("gA")
    local once = vim.api.nvim_buf_get_lines(session.center_buf, 0, -1, false)

    merge_editor.press("gA")
    local twice = vim.api.nvim_buf_get_lines(session.center_buf, 0, -1, false)

    assert.are.same(once, twice)
  end)
end)

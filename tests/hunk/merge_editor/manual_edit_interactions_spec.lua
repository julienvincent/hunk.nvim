local merge_editor = require("tests.utils.merge_editor")

describe("merge editor: manual edit interactions", function()
  before_each(function()
    merge_editor.reset_ui()
  end)

  it("accepts after manual center edits", function()
    local session = merge_editor.open_session({
      base_lines = { "a", "b", "c" },
      left_lines = { "a", "B", "c" },
      right_lines = { "a", "b", "c" },
    })

    vim.api.nvim_buf_set_lines(session.center_buf, 1, 2, false, {})
    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")

    merge_editor.assert_content(session.center_buf, { "a", "B", "c" })
  end)

  it("keeps pending hunk navigation working after non-hunk center edits", function()
    local session = merge_editor.open_session({
      base_lines = { "x", "a", "y", "b", "z" },
      left_lines = { "x", "A", "y", "B", "z" },
      right_lines = { "x", "a", "y", "b", "z" },
    })

    vim.api.nvim_buf_set_lines(session.center_buf, 0, 1, false, { "x edited" })
    merge_editor.set_cursor(session.left_win, 1, 0)
    merge_editor.press("]h")
    assert.are.same({ 2, 0 }, merge_editor.get_cursor(session.left_win))

    merge_editor.press("]h")
    assert.are.same({ 4, 0 }, merge_editor.get_cursor(session.left_win))

    merge_editor.press("[h")
    assert.are.same({ 2, 0 }, merge_editor.get_cursor(session.left_win))
  end)

  it("accepts with gl and gr after non-hunk center edits", function()
    local session = merge_editor.open_session({
      base_lines = { "top", "line", "bottom" },
      left_lines = { "top", "LEFT", "bottom" },
      right_lines = { "top", "RIGHT", "bottom" },
    })

    vim.api.nvim_buf_set_lines(session.center_buf, 0, 1, false, { "top edited" })
    merge_editor.set_cursor(session.center_win, 2, 0)
    merge_editor.press("gl")
    merge_editor.assert_content(session.center_buf, { "top edited", "LEFT", "bottom" })

    merge_editor.reset_ui()
    local right_session = merge_editor.open_session({
      base_lines = { "top", "line", "bottom" },
      left_lines = { "top", "LEFT", "bottom" },
      right_lines = { "top", "RIGHT", "bottom" },
    })
    vim.api.nvim_buf_set_lines(right_session.center_buf, 0, 1, false, { "top edited" })
    merge_editor.set_cursor(right_session.center_win, 2, 0)
    merge_editor.press("gr")
    merge_editor.assert_content(right_session.center_buf, { "top edited", "RIGHT", "bottom" })
  end)

  it("automerge still only accepts non-conflicting hunks after non-hunk edits", function()
    local session = merge_editor.open_session({
      base_lines = { "head", "conflict", "mid", "tail" },
      left_lines = { "head", "LEFT", "mid", "left-tail" },
      right_lines = { "head", "RIGHT", "mid", "tail" },
    })

    vim.api.nvim_buf_set_lines(session.center_buf, 0, 1, false, { "head edited" })
    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("gA")

    merge_editor.assert_content(session.center_buf, { "head edited", "conflict", "mid", "left-tail" })
  end)
end)

local merge_editor = require("tests.utils.merge_editor")

describe("merge editor: conflict ux", function()
  it("stacks second accepted side below the first in conflict pairs", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "A", "B" },
      left_lines = { "A", "LEFT" },
      right_lines = { "A", "RIGHT" },
    })

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")
    merge_editor.set_cursor(session.right_win, 2, 0)
    merge_editor.press("a")

    merge_editor.assert_content(session.center_buf, { "A", "LEFT", "RIGHT" })
  end)

  it("inverts stack order when accepted in opposite order", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "A", "B" },
      left_lines = { "A", "LEFT" },
      right_lines = { "A", "RIGHT" },
    })

    merge_editor.set_cursor(session.right_win, 2, 0)
    merge_editor.press("a")
    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")

    merge_editor.assert_content(session.center_buf, { "A", "RIGHT", "LEFT" })
  end)

  it("handles delete-vs-modify conflicts through key-driven accepts", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "line 1", "line 2" },
      left_lines = {},
      right_lines = { "line 1", "changed" },
    })

    merge_editor.set_cursor(session.right_win, 2, 0)
    merge_editor.press("a")
    merge_editor.assert_content(session.center_buf, { "line 1", "changed" })

    merge_editor.set_cursor(session.left_win, 1, 0)
    merge_editor.press("a")
    merge_editor.assert_content(session.center_buf, { "line 1", "changed" })
  end)
end)

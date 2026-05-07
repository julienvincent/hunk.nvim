local merge_editor = require("tests.utils.merge_editor")

describe("merge editor: undo/redo integration", function()
  it("restores and reapplies accepted hunks via mapped undo/redo", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "line 1", "line 2", "line 3" },
      left_lines = { "line 1", "CHANGED", "line 3" },
      right_lines = { "line 1", "line 2", "line 3" },
    })

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")
    merge_editor.assert_content(session.center_buf, { "line 1", "CHANGED", "line 3" })

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("u")
    merge_editor.assert_content(session.center_buf, { "line 1", "line 2", "line 3" })

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("<C-r>")
    merge_editor.assert_content(session.center_buf, { "line 1", "CHANGED", "line 3" })
  end)
end)

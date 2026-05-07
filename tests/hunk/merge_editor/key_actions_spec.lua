local merge_editor = require("tests.utils.merge_editor")

describe("merge editor: key actions", function()
  before_each(function()
    merge_editor.reset_ui()
  end)

  it("accepts side and center actions through keybindings", function()
    local side_session = merge_editor.open_session({
      base_lines = { "line 1", "line 2", "line 3" },
      left_lines = { "line 1", "LEFT", "line 3" },
      right_lines = { "line 1", "RIGHT", "line 3" },
    })

    merge_editor.set_cursor(side_session.left_win, 2, 0)
    merge_editor.press("a")
    merge_editor.assert_content(side_session.center_buf, { "line 1", "LEFT", "line 3" })

    merge_editor.reset_ui()
    local center_session = merge_editor.open_session({
      base_lines = { "line 1", "line 2", "line 3" },
      left_lines = { "line 1", "LEFT", "line 3" },
      right_lines = { "line 1", "RIGHT", "line 3" },
    })

    merge_editor.set_cursor(center_session.center_win, 2, 0)
    merge_editor.press("gr")
    merge_editor.assert_content(center_session.center_buf, { "line 1", "RIGHT", "line 3" })
  end)

  it("accepts prepend insertions from an empty base", function()
    local session = merge_editor.open_session({
      base_lines = {},
      left_lines = { "prepended" },
      right_lines = {},
    })

    merge_editor.set_cursor(session.left_win, 1, 0)
    merge_editor.press("a")

    merge_editor.assert_content(session.center_buf, { "prepended", "" })
  end)

  it("accepts append insertions at end of file", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "existing" },
      left_lines = { "existing", "appended" },
      right_lines = { "existing" },
    })

    merge_editor.set_cursor(session.left_win, 2, 0)
    merge_editor.press("a")

    merge_editor.assert_content(session.center_buf, { "existing", "appended" })
  end)

  it("navigates pending hunks with ]h and [h", function()
    merge_editor.reset_ui()
    local session = merge_editor.open_session({
      base_lines = { "a", "b", "c", "d", "e" },
      left_lines = { "A", "b", "c", "D", "e" },
      right_lines = { "a", "b", "c", "d", "e" },
    })

    merge_editor.set_cursor(session.left_win, 1, 0)
    merge_editor.press("]h")
    assert.are.same({ 4, 0 }, merge_editor.get_cursor(session.left_win))

    merge_editor.press("[h")
    assert.are.same({ 1, 0 }, merge_editor.get_cursor(session.left_win))
  end)
end)

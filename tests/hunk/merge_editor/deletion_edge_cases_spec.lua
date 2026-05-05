local merge_editor = require("tests.utils.merge_editor")

describe("merge editor: deletion edge cases", function()
  before_each(function()
    merge_editor.reset_ui()
  end)

  it("annotates deleted side buffer", function()
    local session = merge_editor.open_session({
      base_lines = { "one" },
      left_lines = {},
      right_lines = { "one" },
    })

    local found = false
    local ns_deleted = vim.api.nvim_create_namespace("hunk_merge_deleted")
    for _, side_buf in ipairs({ session.left_buf, session.right_buf }) do
      local marks = vim.api.nvim_buf_get_extmarks(side_buf, ns_deleted, 0, -1, { details = true })
      for _, mark in ipairs(marks) do
        local details = mark[4]
        if details and details.virt_text and details.virt_text[1] and details.virt_text[1][1] == "(file deleted)" then
          found = true
        end
      end
    end

    assert.is_true(found)
  end)

  it("accepts a deletion hunk by removing base lines", function()
    local session = merge_editor.open_session({
      base_lines = { "line 1", "line 2" },
      left_lines = {},
      right_lines = { "line 1", "line 2" },
    })

    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("gl")

    merge_editor.assert_content(session.center_buf, { "" })
  end)
end)

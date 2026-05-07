local merge_editor = require("tests.utils.merge_editor")
local merge = require("hunk.merge")

describe("merge editor: window/buffer invariants", function()
  before_each(function()
    merge_editor.reset_ui()
  end)

  it("creates three panes with readonly sides and editable center", function()
    local session = merge_editor.open_session({
      base_lines = { "one", "two" },
      left_lines = { "one", "left" },
      right_lines = { "one", "right" },
    })

    assert.are.equal(3, #session.wins)
    assert.is_not_nil(session.left_buf)
    assert.is_not_nil(session.right_buf)
    assert.is_not_nil(session.center_buf)

    assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = session.left_buf }))
    assert.is_true(vim.api.nvim_get_option_value("readonly", { buf = session.left_buf }))
    assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = session.right_buf }))
    assert.is_true(vim.api.nvim_get_option_value("readonly", { buf = session.right_buf }))
    assert.is_true(vim.api.nvim_get_option_value("modifiable", { buf = session.center_buf }))

    local center_lines = vim.api.nvim_buf_get_lines(session.center_buf, 0, -1, false)
    assert.are.same({ "one", "two" }, center_lines)
  end)

  it("uses path to name center and side buffers", function()
    merge.start_session({
      base_lines = { "one" },
      left_lines = { "one" },
      right_lines = { "one" },
      path = "custom/path/file.lua",
      on_accept = function() end,
      on_cancel = function() end,
    })

    local wins = vim.api.nvim_tabpage_list_wins(0)
    local ordered = {}
    for _, win in ipairs(wins) do
      local pos = vim.api.nvim_win_get_position(win)
      table.insert(ordered, { win = win, col = pos[2] })
    end
    table.sort(ordered, function(a, b)
      return a.col < b.col
    end)

    local names = {}
    for _, entry in ipairs(ordered) do
      table.insert(names, vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(entry.win)))
    end

    local center_ok = false
    local left_ok = false
    local right_ok = false
    for _, name in ipairs(names) do
      if name:match("hunk:left://") and name:match("custom/path/file%.lua") then
        left_ok = true
      elseif name:match("hunk:right://") and name:match("custom/path/file%.lua") then
        right_ok = true
      elseif name:match("custom/path/file%.lua") then
        center_ok = true
      end
    end

    assert.is_true(center_ok)
    assert.is_true(left_ok)
    assert.is_true(right_ok)
  end)
end)

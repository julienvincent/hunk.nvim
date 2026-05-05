local merge_editor = require("tests.utils.merge_editor")
local fs = require("hunk.api.fs")

local function write_tmp(lines)
  local path = vim.fn.tempname()
  fs.write_file(path, lines)
  return path
end

local function capture_current_session()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local ordered = {}
  for _, win in ipairs(wins) do
    local pos = vim.api.nvim_win_get_position(win)
    table.insert(ordered, { win = win, col = pos[2] })
  end
  table.sort(ordered, function(a, b)
    return a.col < b.col
  end)

  local center_win = ordered[2].win
  local center_buf = vim.api.nvim_win_get_buf(center_win)
  return {
    center_win = center_win,
    center_buf = center_buf,
  }
end

describe("merge editor: exit semantics", function()
  before_each(function()
    merge_editor.reset_ui()
  end)

  it("invokes accept callback on accept mapping", function()
    local session = merge_editor.open_session({
      base_lines = { "base" },
      left_lines = { "left" },
      right_lines = { "right" },
    })

    vim.api.nvim_buf_set_lines(session.center_buf, 0, -1, false, { "resolved" })
    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("<leader><Cr>")

    assert.are.same({ "resolved" }, session.accepted_lines())
  end)

  it("invokes cancel callback on cancel mapping", function()
    local session = merge_editor.open_session({
      base_lines = { "base" },
      left_lines = { "left" },
      right_lines = { "right" },
    })

    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("q")

    assert.is_true(session.cancelled())
    assert.is_nil(session.accepted_lines())
  end)

  it("accepts left or right entirely via gL/gR", function()
    local left_session = merge_editor.open_session({
      base_lines = { "base" },
      left_lines = { "left" },
      right_lines = { "right" },
    })

    merge_editor.set_cursor(left_session.center_win, 1, 0)
    merge_editor.press("gL")
    assert.are.same({ "left" }, left_session.accepted_lines())

    merge_editor.reset_ui()
    local right_session = merge_editor.open_session({
      base_lines = { "base" },
      left_lines = { "left" },
      right_lines = { "right" },
    })

    merge_editor.set_cursor(right_session.center_win, 1, 0)
    merge_editor.press("gR")
    assert.are.same({ "right" }, right_session.accepted_lines())
  end)

  it("writes output on accept and preserves output on cancel in command flow", function()
    local base = write_tmp({ "base" })
    local left = write_tmp({ "left" })
    local right = write_tmp({ "right" })
    local output = write_tmp({ "seed" })
    vim.cmd("MergeEditor " .. base .. " " .. left .. " " .. right .. " " .. output .. " cmd-exit.lua")
    local session = capture_current_session()

    local original_qa = vim.cmd.qa
    vim.cmd.qa = function() end

    vim.api.nvim_buf_set_lines(session.center_buf, 0, -1, false, { "resolved" })
    merge_editor.set_cursor(session.center_win, 1, 0)
    merge_editor.press("<leader><Cr>")

    vim.cmd.qa = original_qa
    assert.are.same({ "resolved" }, fs.read_file_as_lines(output))

    merge_editor.reset_ui()
    local base2 = write_tmp({ "base" })
    local left2 = write_tmp({ "left" })
    local right2 = write_tmp({ "right" })
    local output2 = write_tmp({ "keep-me" })
    vim.cmd("MergeEditor " .. base2 .. " " .. left2 .. " " .. right2 .. " " .. output2 .. " cmd-cancel.lua")
    local cancel_session = capture_current_session()

    local original_cq = vim.cmd.cq
    vim.cmd.cq = function() end

    vim.api.nvim_buf_set_lines(cancel_session.center_buf, 0, -1, false, { "should-not-write" })
    merge_editor.set_cursor(cancel_session.center_win, 1, 0)
    merge_editor.press("q")

    vim.cmd.cq = original_cq
    assert.are.same({ "keep-me" }, fs.read_file_as_lines(output2))
  end)
end)

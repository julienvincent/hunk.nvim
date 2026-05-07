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

  local left_win = ordered[1].win
  local center_win = ordered[2].win
  local right_win = ordered[3].win

  return {
    wins = wins,
    left_buf = vim.api.nvim_win_get_buf(left_win),
    center_buf = vim.api.nvim_win_get_buf(center_win),
    right_buf = vim.api.nvim_win_get_buf(right_win),
  }
end

describe("merge editor: command contract", function()
  before_each(function()
    merge_editor.reset_ui()
  end)

  it("shows an error when called with too few args", function()
    local original_notify = vim.notify
    local calls = {}

    vim.notify = function(msg, level)
      table.insert(calls, { msg = msg, level = level })
    end

    vim.cmd("MergeEditor")

    vim.notify = original_notify

    assert.are.equal(1, #calls)
    assert.is_true(calls[1].msg:match("MergeEditor expects arguments") ~= nil)
    assert.are.equal(vim.log.levels.ERROR, calls[1].level)
  end)

  it("opens a full three-pane session with valid args", function()
    local base = write_tmp({ "a", "b" })
    local left = write_tmp({ "a", "left" })
    local right = write_tmp({ "a", "right" })
    local output = write_tmp({})

    vim.cmd("MergeEditor " .. base .. " " .. left .. " " .. right .. " " .. output .. " happy.lua")

    local session = capture_current_session()

    assert.are.equal(3, #session.wins)
    assert.is_true(vim.api.nvim_get_option_value("modifiable", { buf = session.center_buf }))
    assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = session.left_buf }))
    assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = session.right_buf }))
  end)
end)

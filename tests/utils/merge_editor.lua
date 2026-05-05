local merge = require("hunk.merge")

local M = {}

function M.reset_ui()
  vim.cmd("silent! only")
  vim.cmd("enew")
end

function M.open_session(opts)
  local accepted_lines = nil
  local cancelled = false

  local unique_name = (opts.path or "test.lua") .. ":" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")

  merge.start_session({
    base_lines = opts.base_lines,
    left_lines = opts.left_lines,
    right_lines = opts.right_lines,
    path = unique_name,
    on_accept = function(lines)
      accepted_lines = vim.deepcopy(lines)
    end,
    on_cancel = function()
      cancelled = true
    end,
  })

  local wins = vim.api.nvim_tabpage_list_wins(0)
  local session = {
    wins = wins,
    accepted_lines = function()
      return accepted_lines
    end,
    cancelled = function()
      return cancelled
    end,
  }

  local ordered = {}
  for _, win in ipairs(wins) do
    local pos = vim.api.nvim_win_get_position(win)
    table.insert(ordered, { win = win, col = pos[2] })
  end
  table.sort(ordered, function(a, b)
    return a.col < b.col
  end)

  session.left_win = ordered[1].win
  session.center_win = ordered[2].win
  session.right_win = ordered[3].win
  session.left_buf = vim.api.nvim_win_get_buf(session.left_win)
  session.center_buf = vim.api.nvim_win_get_buf(session.center_win)
  session.right_buf = vim.api.nvim_win_get_buf(session.right_win)

  for _, buf in ipairs({ session.left_buf, session.center_buf, session.right_buf }) do
    if vim.api.nvim_buf_get_name(buf) == "" then
      vim.api.nvim_buf_set_name(buf, "scratch:" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t"))
    end
  end

  return session
end

function M.set_cursor(win, row, col)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { row, col or 0 })
end

local function replace_termcodes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

function M.press(keys)
  vim.api.nvim_feedkeys(replace_termcodes(keys), "xt", false)
end

function M.assert_content(buf, expected_lines)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert.are.same(expected_lines, lines)
end

function M.get_cursor(win)
  return vim.api.nvim_win_get_cursor(win)
end

function M.get_extmarks(buf, namespace_name)
  local ns = vim.api.nvim_create_namespace(namespace_name)
  return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end

return M

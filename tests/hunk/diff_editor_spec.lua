local hunk = require("hunk")
local config = require("hunk.config")
local fs = require("hunk.api.fs")

local function invoke(win, key, row)
  vim.api.nvim_set_current_win(win)
  if row then
    vim.api.nvim_win_set_cursor(win, { row, 0 })
  end
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert.is_function(mapping.callback)
  mapping.callback()
end

describe("diff editor", function()
  local original_config
  local original_cwd
  local original_qa
  local original_cq
  local original_select
  local existing_bufs
  local workspace
  local tree_context
  local panes
  local left_lines = { "old first", "context 1", "context 2", "context 3", "context 4", "old last" }
  local right_lines = { "new first", "context 1", "context 2", "context 3", "context 4", "new last" }

  local function open()
    hunk.start(workspace.left, workspace.right, workspace.output)
    return panes[1], panes[2]
  end

  local function selected_signs(pane)
    return vim.tbl_map(function(sign)
      return { sign.lnum, sign.name }
    end, vim.fn.sign_getplaced(pane.buf, { group = "Hunk" })[1].signs)
  end

  local function accept()
    vim.cmd.qa = function() end
    invoke(tree_context.win, "<leader><Cr>")
    return fs.read_file_as_lines(workspace.output .. "/example.txt")
  end

  before_each(function()
    vim.cmd("silent! only!")
    vim.cmd("enew!")
    original_config = vim.deepcopy(config)
    original_cwd = vim.fn.getcwd()
    original_qa = vim.cmd.qa
    original_cq = vim.cmd.cq
    original_select = vim.ui.select
    existing_bufs = vim.api.nvim_list_bufs()
    local root = vim.fn.tempname()
    workspace = { root = root, left = root .. "/left", right = root .. "/right", output = root .. "/output" }
    fs.write_file(workspace.left .. "/example.txt", left_lines)
    fs.write_file(workspace.right .. "/example.txt", right_lines)
    vim.fn.mkdir(workspace.output, "p")
    vim.api.nvim_set_current_dir(workspace.output)
    panes = {}
    hunk.setup({
      hooks = {
        on_tree_mount = function(context)
          tree_context = context
        end,
        on_diff_mount = function(context)
          table.insert(panes, context)
        end,
      },
    })
  end)

  after_each(function()
    vim.cmd.qa = original_qa
    vim.cmd.cq = original_cq
    vim.ui.select = original_select
    hunk.setup(original_config)
    vim.api.nvim_set_current_dir(original_cwd)
    vim.cmd("silent! only!")
    vim.cmd("enew!")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if not vim.tbl_contains(existing_bufs, buf) and buf ~= vim.api.nvim_get_current_buf() then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.fn.delete(workspace.root, "rf")
  end)

  it("mounts editor buffers, selection state, controls, help, and signs", function()
    local left, right = open()
    assert.is_nil(package.loaded["hunk.diff_view"])
    local change = tree_context.opts.changeset["example.txt"]
    assert.is_false(change.selected)
    assert.are.same({ left = {}, right = {} }, change.selected_lines)
    assert.are.equal("hunk://" .. workspace.output .. "/example.txt", vim.api.nvim_buf_get_name(left.buf))
    assert.are.equal(workspace.output .. "/example.txt", vim.api.nvim_buf_get_name(right.buf))
    for _, pane in ipairs({ left, right }) do
      assert.are.same({ { 1, "HunkLineDeselected" }, { 6, "HunkLineDeselected" } }, selected_signs(pane))
      vim.api.nvim_set_current_win(pane.win)
      for _, key in ipairs({ "a", "s", "A", "<leader><Cr>" }) do
        assert.is_function(vim.fn.maparg(key, "n", false, true).callback)
      end
    end
    assert.is_truthy(vim.api.nvim_get_option_value("winhl", { win = left.win }):match("HunkSignDelete"))
    assert.is_truthy(vim.api.nvim_get_option_value("winhl", { win = right.win }):match("HunkSignAdd"))
    invoke(tree_context.win, "g?")
    local help = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_truthy(help:match("accept"))
    assert.is_truthy(help:match("toggle_line"))
  end)

  it("selects line pairs on both sides and writes a partial diff", function()
    local left, right = open()
    invoke(right.win, "s", 1)
    local change = tree_context.opts.changeset["example.txt"]
    assert.is_true(change.selected_lines.left[1])
    assert.is_true(change.selected_lines.right[1])
    assert.is_false(change.selected)
    for _, pane in ipairs({ left, right }) do
      assert.are.same({ { 1, "HunkLineSelected" }, { 6, "HunkLineDeselected" } }, selected_signs(pane))
    end
    assert.are.same({ "new first", "context 1", "context 2", "context 3", "context 4", "old last" }, accept())
  end)

  it("selects individual lines independently of the opposite side", function()
    local left = open()
    invoke(left.win, "a", 1)
    local change = tree_context.opts.changeset["example.txt"]
    assert.is_true(change.selected_lines.left[1])
    assert.is_nil(change.selected_lines.right[1])
    assert.are.same({ "context 1", "context 2", "context 3", "context 4", "old last" }, accept())
  end)

  it("toggles an entire hunk on both sides without selecting the other hunk", function()
    local left, right = open()
    invoke(right.win, "A", 6)
    local change = tree_context.opts.changeset["example.txt"]
    assert.is_true(change.selected_lines.left[6])
    assert.is_true(change.selected_lines.right[6])
    assert.is_nil(change.selected_lines.left[1])
    invoke(left.win, "A", 6)
    assert.is_false(change.selected_lines.left[6])
    assert.is_false(change.selected_lines.right[6])
    assert.are.same(left_lines, accept())
  end)

  it("selects a visual range on both sides through the scheduled selection callback", function()
    local _, right = open()
    vim.api.nvim_set_current_win(right.win)
    vim.api.nvim_win_set_cursor(right.win, { 1, 0 })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(right.win, { 6, 0 })
    local callback = vim.fn.maparg("s", "v", false, true).callback
    assert.is_function(callback)
    callback()
    local change = tree_context.opts.changeset["example.txt"]
    assert.is_true(vim.wait(1000, function()
      return change.selected
    end))
    assert.is_true(change.selected_lines.left[1])
    assert.is_true(change.selected_lines.left[6])
    assert.is_true(change.selected_lines.right[1])
    assert.is_true(change.selected_lines.right[6])
    assert.are.same(right_lines, accept())
  end)

  it("cancels with a nonzero exit and leaves the output untouched", function()
    local _, right = open()
    invoke(right.win, "A", 1)
    local cancelled = 0
    vim.cmd.cq = function()
      cancelled = cancelled + 1
    end
    vim.cmd.qa = function()
      error("Editor cancellation must use cq")
    end
    invoke(right.win, "q")
    assert.are.equal(1, cancelled)
    assert.is_nil(fs.read_file(workspace.output .. "/example.txt"))
    assert.are.same(left_lines, fs.read_file_as_lines(workspace.left .. "/example.txt"))
    assert.are.same(right_lines, fs.read_file_as_lines(workspace.right .. "/example.txt"))
  end)

  it("honors the editor's confirmation before cancellation", function()
    hunk.setup({ ui = { confirm_before_quit = true } })
    open()
    local callback
    local cancelled = 0
    vim.ui.select = function(items, opts, on_choice)
      assert.are.same({ "Yes", "No" }, items)
      assert.are.equal("Quit without saving?", opts.prompt)
      callback = on_choice
    end
    vim.cmd.cq = function()
      cancelled = cancelled + 1
    end
    invoke(tree_context.win, "q")
    callback("No")
    assert.are.equal(0, cancelled)
    invoke(tree_context.win, "q")
    callback("Yes")
    assert.are.equal(1, cancelled)
    assert.is_nil(fs.read_file(workspace.output .. "/example.txt"))
  end)
end)

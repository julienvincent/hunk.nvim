local hunk = require("hunk")
local config = require("hunk.config")
local fs = require("hunk.api.fs")

local function reset_ui()
  vim.cmd("silent! only!")
  vim.cmd("enew!")
end

local function write_file(dir, path, lines)
  fs.make_parents(dir .. "/" .. path)
  fs.write_file(dir .. "/" .. path, lines)
end

local function invoke(win, key)
  vim.api.nvim_set_current_win(win)
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert.is_function(mapping.callback)
  mapping.callback()
end

local function content(pane)
  return vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
end

describe("diff view", function()
  local workspace
  local original_config
  local original_notify
  local original_qa
  local original_cq
  local existing_bufs
  local tree_context
  local file_mounts

  local function panes()
    return file_mounts[#file_mounts - 1], file_mounts[#file_mounts]
  end

  local function open()
    vim.cmd("HunkDiffView " .. vim.fn.fnameescape(workspace.left) .. " " .. vim.fn.fnameescape(workspace.right))
    return panes()
  end

  before_each(function()
    reset_ui()
    original_config = vim.deepcopy(config)
    original_notify = vim.notify
    original_qa = vim.cmd.qa
    original_cq = vim.cmd.cq
    existing_bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      existing_bufs[buf] = true
    end
    local root = vim.fn.tempname() .. " diff view"
    workspace = { root = root, left = root .. "/left side", right = root .. "/right side" }
    vim.fn.mkdir(workspace.left, "p")
    vim.fn.mkdir(workspace.right, "p")
    file_mounts = {}
    tree_context = nil
    hunk.setup({
      hooks = {
        on_tree_mount = function(context)
          tree_context = context
        end,
        on_diff_mount = function(context)
          table.insert(file_mounts, context)
        end,
      },
    })
  end)

  after_each(function()
    vim.notify = original_notify
    vim.cmd.qa = original_qa
    vim.cmd.cq = original_cq
    hunk.setup(original_config)
    reset_ui()
    vim.cmd("silent! argdelete *")
    local current_buf = vim.api.nvim_get_current_buf()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if not existing_bufs[buf] and buf ~= current_buf then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.fn.delete(workspace.root, "rf")
  end)

  it("opens paths containing spaces as read-only, filetyped diff buffers", function()
    write_file(workspace.left, "src/example.lua", { "local value = 1" })
    write_file(workspace.right, "src/example.lua", { "local value = 2" })
    local left, right = open()

    assert.are.equal(3, #vim.api.nvim_tabpage_list_wins(0))
    assert.are.same({ "local value = 1" }, content(left))
    assert.are.same({ "local value = 2" }, content(right))
    for _, pane in ipairs({ left, right }) do
      assert.is_true(vim.api.nvim_get_option_value("diff", { win = pane.win }))
      assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = pane.buf }))
      assert.is_true(vim.api.nvim_get_option_value("readonly", { buf = pane.buf }))
      assert.are.equal("lua", vim.api.nvim_get_option_value("filetype", { buf = pane.buf }))
      assert.has_error(function()
        vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, { "changed" })
      end)
    end
  end)

  it("accepts directory paths from the startup argument list", function()
    write_file(workspace.left, "example", { "left" })
    write_file(workspace.right, "example", { "right" })
    vim.cmd("args " .. vim.fn.fnameescape(workspace.left) .. " " .. vim.fn.fnameescape(workspace.right))
    vim.cmd("HunkDiffView")
    local left, right = panes()
    assert.are.same({ "left" }, content(left))
    assert.are.same({ "right" }, content(right))
  end)

  it("uses explicit paths after startup arguments and the working directory change", function()
    write_file(workspace.left, "example", { "left" })
    write_file(workspace.right, "example", { "right" })
    local cwd = vim.fn.getcwd()
    vim.cmd("args NvimTree_1")
    vim.api.nvim_set_current_dir(workspace.left)
    local ok, err = pcall(open)
    vim.api.nvim_set_current_dir(cwd)
    assert.is_true(ok, err)
    local left, right = panes()
    assert.are.same({ "left" }, content(left))
    assert.are.same({ "right" }, content(right))
  end)

  it("rejects invalid arguments before creating a layout", function()
    local notifications = {}
    vim.notify = function(message, level)
      table.insert(notifications, { message = message, level = level })
    end
    vim.cmd("HunkDiffView " .. vim.fn.fnameescape(workspace.left))
    vim.cmd("HunkDiffView left right extra")
    vim.cmd("HunkDiffView missing missing")
    assert.is_false(hunk.view(nil, workspace.right))
    assert.are.equal(4, #notifications)
    assert.is_truthy(notifications[3].message:match("left = .*missing"))
    assert.is_truthy(notifications[4].message:match("left = nil"))
    assert.are.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    for _, notification in ipairs(notifications) do
      assert.are.equal(vim.log.levels.ERROR, notification.level)
      assert.is_truthy(notification.message:match("HunkDiffView expects"))
    end
  end)

  it("keeps an existing working-file buffer separate from the comparison", function()
    local filename = "working-buffer-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".lua"
    local original_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(original_buf, vim.fn.getcwd() .. "/" .. filename)
    vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, { "unsaved working copy" })
    vim.api.nvim_win_set_buf(0, original_buf)
    write_file(workspace.left, filename, { "old revision" })
    write_file(workspace.right, filename, { "new revision" })

    local left, right = open()
    assert.are.same({ "old revision" }, content(left))
    assert.are.same({ "new revision" }, content(right))
    assert.are.same({ "unsaved working copy" }, vim.api.nvim_buf_get_lines(original_buf, 0, -1, false))
    assert.is_true(vim.api.nvim_get_option_value("modifiable", { buf = original_buf }))
    assert.are_not.equal(original_buf, right.buf)
  end)

  it("uses fresh buffers when another comparison has the same filenames", function()
    write_file(workspace.left, "example", { "first left" })
    write_file(workspace.right, "example", { "first right" })
    local first_left, first_right = open()
    reset_ui()
    write_file(workspace.left, "example", { "second left" })
    write_file(workspace.right, "example", { "second right" })
    local left, right = open()
    assert.are_not.equal(first_left.buf, left.buf)
    assert.are_not.equal(first_right.buf, right.buf)
    assert.are.same({ "second left" }, content(left))
    assert.are.same({ "second right" }, content(right))
  end)

  it("opens added, deleted, empty, and symlink entries from the tree", function()
    write_file(workspace.right, "added", { "new" })
    write_file(workspace.left, "deleted", { "old" })
    write_file(workspace.right, "empty", {})
    assert(vim.loop.fs_symlink("old target", workspace.left .. "/link"))
    assert(vim.loop.fs_symlink("new target", workspace.right .. "/link"))
    open()
    local expected = {
      added = { { "" }, { "new" } },
      deleted = { { "old" }, { "" } },
      empty = { { "" }, { "" } },
      link = { { "old target" }, { "new target" } },
    }
    for path, lines in pairs(expected) do
      tree_context.opts.on_open(tree_context.opts.changeset[path], { tree = tree_context.tree })
      local left, right = panes()
      assert.are.same(lines[1], content(left))
      assert.are.same(lines[2], content(right))
    end
  end)

  for _, side in ipairs({ "left", "right" }) do
    it("displays materialized conflicts on the " .. side .. " side", function()
      local conflict = {
        "<<<<<<< conflict 1 of 1",
        "+++++++ side 1",
        "first",
        "------- base",
        "original",
        "+++++++ side 2",
        "second",
        ">>>>>>> conflict 1 of 1 ends",
      }
      write_file(workspace.left, "example", { "resolved" })
      write_file(workspace.right, "example", { "resolved" })
      write_file(workspace[side], "example", conflict)
      local left, right = open()
      assert.are.same(conflict, content(side == "left" and left or right))
    end)
  end

  it("keeps navigation but omits selection controls and selection help", function()
    write_file(workspace.left, "example", { "left" })
    write_file(workspace.right, "example", { "right" })
    local left, right = open()
    for _, pane in ipairs({ left, right }) do
      vim.api.nvim_set_current_win(pane.win)
      for _, key in ipairs({ "a", "s", "A", "<leader><Cr>" }) do
        assert.are.same({}, vim.fn.maparg(key, "n", false, true))
      end
    end
    invoke(left.win, "<Tab>")
    assert.are.equal(right.win, vim.api.nvim_get_current_win())
    invoke(right.win, "<leader>e")
    assert.are.equal(tree_context.win, vim.api.nvim_get_current_win())
    assert.are.same({}, vim.fn.maparg("a", "n", false, true))
    invoke(tree_context.win, "g?")
    local help = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_nil(help:match("accept"))
    assert.is_nil(help:match("toggle_line"))
    assert.is_truthy(help:match("next_hunk"))
  end)

  it("leaves changeset selection state untouched while navigating and omits selection signs", function()
    write_file(workspace.left, "example", { "left" })
    write_file(workspace.right, "example", { "right" })
    local left, right = open()
    local change = tree_context.opts.changeset.example
    assert.is_false(change.selected)
    assert.are.same({ left = {}, right = {} }, change.selected_lines)
    assert.is_nil(tree_context.opts.on_toggle)
    for _, pane in ipairs({ left, right }) do
      assert.are.same({}, vim.fn.sign_getplaced(pane.buf, { group = "Hunk" })[1].signs)
      local winhl = vim.api.nvim_get_option_value("winhl", { win = pane.win })
      assert.is_nil(winhl:match("HunkSign"))
    end
    invoke(left.win, "[h")
    invoke(right.win, "]h")
    invoke(tree_context.win, "l")
    assert.is_false(change.selected)
    assert.are.same({ left = {}, right = {} }, change.selected_lines)
  end)

  it("can navigate hunks on an absent side without using an invalid cursor row", function()
    write_file(workspace.right, "added", { "new" })
    local left = open()
    invoke(left.win, "[h")
    assert.are.equal(1, vim.api.nvim_win_get_cursor(left.win)[1])
  end)

  it("quits successfully from every pane without changing either directory", function()
    write_file(workspace.left, "example", { "left" })
    write_file(workspace.right, "example", { "right" })
    hunk.setup({ ui = { confirm_before_quit = true } })
    local left, right = open()
    local quit_count = 0
    vim.cmd.qa = function()
      quit_count = quit_count + 1
    end
    vim.cmd.cq = function()
      error("Viewer must exit successfully")
    end
    for _, win in ipairs({ tree_context.win, left.win, right.win }) do
      invoke(win, "q")
    end
    assert.are.equal(3, quit_count)
    assert.are.equal("left\n", fs.read_file(workspace.left .. "/example"))
    assert.are.equal("right\n", fs.read_file(workspace.right .. "/example"))
  end)

  it("provides quit bindings for an empty comparison", function()
    open()
    local quit_count = 0
    vim.cmd.qa = function()
      quit_count = quit_count + 1
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      invoke(win, "q")
    end
    assert.are.equal(3, quit_count)
  end)

  it("keeps a viewer's quit and help callbacks independent after starting an editor", function()
    write_file(workspace.left, "example", { "left" })
    write_file(workspace.right, "example", { "right" })
    local _, right = open()
    local viewer_buf = right.buf
    vim.api.nvim_set_current_win(right.win)
    local quit = vim.fn.maparg("q", "n", false, true).callback
    local help = vim.fn.maparg("g?", "n", false, true).callback
    local viewer_change = tree_context.opts.changeset.example
    reset_ui()
    hunk.start(workspace.left, workspace.right, workspace.root .. "/output")
    local quit_count = 0
    vim.cmd.qa = function()
      quit_count = quit_count + 1
    end
    vim.cmd.cq = function()
      error("Viewer must still exit successfully")
    end
    quit()
    assert.are.equal(1, quit_count)
    help()
    local help_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_nil(help_text:match("accept"))
    assert.is_nil(help_text:match("toggle_line"))
    assert.is_false(viewer_change.selected)
    assert.are.same({ left = {}, right = {} }, viewer_change.selected_lines)
    assert.are.same({}, vim.fn.sign_getplaced(viewer_buf, { group = "Hunk" })[1].signs)
  end)

  it("supports a horizontal layout and flat tree", function()
    hunk.setup({ ui = { layout = "horizontal", tree = { mode = "flat" } } })
    write_file(workspace.left, "src/example", { "left" })
    write_file(workspace.right, "src/example", { "right" })
    local left, right = open()
    local left_pos = vim.api.nvim_win_get_position(left.win)
    local right_pos = vim.api.nvim_win_get_position(right.win)
    assert.are.equal(left_pos[2], right_pos[2])
    assert.is_true(right_pos[1] > left_pos[1])
    assert.are.equal("src/example", tree_context.tree:get_nodes()[1].change.filepath)
  end)

  it("keeps floating-tree navigation working after closing and reopening", function()
    hunk.setup({ ui = { tree = { use_float = true, float = { border = "single" } } } })
    write_file(workspace.left, "src/first", { "old first" })
    write_file(workspace.right, "src/first", { "new first" })
    write_file(workspace.left, "src/second", { "old second" })
    write_file(workspace.right, "src/second", { "new second" })
    local _, right = open()
    local tree_buf = tree_context.buf
    local tree_win = tree_context.win
    vim.api.nvim_win_set_cursor(tree_win, { 3, 0 })
    invoke(tree_win, "<Cr>")
    local left
    left, right = panes()
    assert.is_false(vim.api.nvim_win_is_valid(tree_win))
    assert.are.same({ "new second" }, content(right))

    invoke(right.win, "<leader>e")
    tree_win = vim.api.nvim_get_current_win()
    assert.are.equal(tree_buf, vim.api.nvim_win_get_buf(tree_win))
    assert.are.equal(3, vim.api.nvim_win_get_cursor(tree_win)[1])
    vim.api.nvim_win_set_cursor(tree_win, { 2, 0 })
    invoke(tree_win, "l")
    left, right = panes()
    assert.are.same({ "old first" }, content(left))
    assert.are.equal(tree_win, vim.api.nvim_get_current_win())

    invoke(tree_win, "<Esc>")
    assert.is_false(vim.api.nvim_win_is_valid(tree_win))
    invoke(right.win, "<leader>e")
    assert.are.equal(tree_buf, vim.api.nvim_get_current_buf())
    assert.are.same({}, vim.fn.maparg("a", "n", false, true))
  end)

  it("still selects and writes changes in DiffEditor after viewing", function()
    local filename = "editor-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
    write_file(workspace.left, filename, { "old" })
    write_file(workspace.right, filename, { "new" })
    open()
    reset_ui()
    local output = workspace.root .. "/output"
    vim.cmd(
      "DiffEditor "
        .. vim.fn.fnameescape(workspace.left)
        .. " "
        .. vim.fn.fnameescape(workspace.right)
        .. " "
        .. vim.fn.fnameescape(output)
    )
    local _, right = panes()
    vim.cmd.qa = function() end
    invoke(tree_context.win, "a")
    invoke(right.win, "<leader><Cr>")
    assert.are.equal("new\n", fs.read_file(output .. "/" .. filename))
  end)

  it("keeps an editor's accept callback bound to its own comparison", function()
    local filename = "editor-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
    write_file(workspace.left, filename, { "old" })
    write_file(workspace.right, filename, { "new" })
    local output = workspace.root .. "/output"
    hunk.start(workspace.left, workspace.right, output)
    invoke(tree_context.win, "a")
    local _, right = panes()
    vim.api.nvim_set_current_win(right.win)
    local accept = vim.fn.maparg("<leader><Cr>", "n", false, true).callback
    reset_ui()

    local view_left = workspace.root .. "/view-left"
    local view_right = workspace.root .. "/view-right"
    write_file(view_left, filename, { "viewer left" })
    write_file(view_right, filename, { "viewer right" })
    hunk.view(view_left, view_right)
    vim.cmd.qa = function() end
    accept()
    assert.are.equal("new\n", fs.read_file(output .. "/" .. filename))
    assert.are.equal("viewer right\n", fs.read_file(view_right .. "/" .. filename))
  end)
end)

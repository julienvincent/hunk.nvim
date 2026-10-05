local fixtures = require("tests.utils.fixtures")
local api = require("hunk.api")
local hunk = require("hunk")
local config = require("hunk.config")

describe("native filesystem operations", function()
  local original_path

  before_each(function()
    original_path = vim.env.PATH
    vim.env.PATH = ""
  end)

  after_each(function()
    vim.env.PATH = original_path
  end)

  it("writes a selected changeset without Unix utilities", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)
      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
      changeset.modified.selected = true
      changeset.deleted.selected = true

      api.changeset.write_changeset(changeset, workspace.output)

      assert.are.same({ modified = { "a1", "c", "d", "e" } }, fixtures.read_dir(workspace.output))
    end)
  end)

  it("accepts selected files when the right directory is also the output", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)
      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
      changeset.modified.selected = true
      changeset.added.selected = true
      changeset.deleted.selected = true

      api.changeset.write_changeset(changeset, workspace.right)

      assert.are.same({
        modified = { "a1", "c", "d", "e" },
        added = { "a", "b", "c" },
      }, fixtures.read_dir(workspace.right))
    end)
  end)

  it("creates output parents for selected files with spaces", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_workspace(workspace, {}, { ["nested folder/new file.txt"] = { "new" } })
      vim.fn.delete(workspace.output, "rf")
      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
      changeset["nested folder/new file.txt"].selected = true

      api.changeset.write_changeset(changeset, workspace.output)

      assert.are.same({ ["nested folder/new file.txt"] = { "new" } }, fixtures.read_dir(workspace.output))
    end)
  end)

  it("allows removing a file that is already absent", function()
    fixtures.with_workspace(function(workspace)
      api.fs.rm_file(workspace.output .. "/absent file.txt")
    end)
  end)

  it("moves and removes symlinks without changing their targets", function()
    fixtures.with_workspace(function(workspace)
      api.fs.write_file(workspace.output .. "/target.txt", { "target content" })
      assert(vim.loop.fs_symlink("target.txt", workspace.right .. "/link.txt"))
      assert(vim.loop.fs_symlink("target.txt", workspace.output .. "/link.txt"))

      api.fs.move_file(workspace.right .. "/link.txt", workspace.output .. "/link.txt")
      assert.are.equal("link", vim.loop.fs_lstat(workspace.output .. "/link.txt").type)
      assert.are.equal("target.txt", vim.loop.fs_readlink(workspace.output .. "/link.txt"))
      api.fs.rm_file(workspace.output .. "/link.txt")

      assert.are.same({ "target content" }, api.fs.read_file_as_lines(workspace.output .. "/target.txt"))
      assert.is_nil(vim.loop.fs_lstat(workspace.output .. "/link.txt"))
    end)
  end)

  it("reports failed moves instead of accepting an incomplete output", function()
    fixtures.with_workspace(function(workspace)
      assert.has_error(function()
        api.fs.move_file(workspace.left .. "/missing.txt", workspace.output .. "/missing.txt")
      end)
    end)
  end)
end)

describe("file navigation", function()
  local original_cwd
  local original_buffers
  local original_hooks

  before_each(function()
    original_cwd = vim.fn.getcwd()
    original_buffers = vim.api.nvim_list_bufs()
    original_hooks = config.hooks
  end)

  after_each(function()
    vim.fn.chdir(original_cwd)
    config.hooks = original_hooks
    vim.cmd("only!")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if not vim.tbl_contains(original_buffers, buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end)

  it("reuses buffers after revisiting files and can still toggle hunks", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_workspace(workspace, {
        ["first file.txt"] = { "old first" },
        ["second file.txt"] = { "old second" },
      }, {
        ["first file.txt"] = { "new first" },
        ["second file.txt"] = { "new second" },
      })
      vim.fn.chdir(workspace.output)
      local tree_window
      local tree
      local mounted_buffers = {}
      hunk.setup({
        icons = { enable_file_icons = false },
        hooks = {
          on_tree_mount = function(ctx)
            tree_window = ctx.opts.winid
            tree = ctx.tree
          end,
          on_diff_mount = function(ctx)
            table.insert(mounted_buffers, ctx.buf)
          end,
        },
      })
      hunk.start(workspace.left, workspace.right, workspace.output)
      local open_file = vim.fn.maparg("<CR>", "n", false, true).callback

      for _, line in ipairs({ 1, 2, 1 }) do
        vim.api.nvim_set_current_win(tree_window)
        vim.api.nvim_win_set_cursor(tree_window, { line, 0 })
        open_file()
      end

      assert.are.equal(mounted_buffers[1], mounted_buffers[7])
      assert.are.equal(mounted_buffers[2], mounted_buffers[8])
      local change = tree:get_node(1).change
      local toggle_hunk = vim.fn.maparg("A", "n", false, true).callback
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      toggle_hunk()
      assert.is_true(change.selected)
      toggle_hunk()
      assert.is_false(change.selected)
    end)
  end)
end)

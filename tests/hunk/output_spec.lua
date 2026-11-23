local fixtures = require("tests.utils.fixtures")
local api = require("hunk.api")

describe("output", function()
  it("should apply only the selected files", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)

      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

      changeset.modified.selected = true
      changeset.deleted.selected = true
      api.changeset.write_changeset(changeset, workspace.output)

      local files = fixtures.read_dir(workspace.output)

      assert.are.same({
        modified = {
          "a1",
          "c",
          "d",
          "e",
        },
      }, files)
    end)
  end)

  it("should not delete files that aren't selected", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)

      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

      api.changeset.write_changeset(changeset, workspace.output)

      local files = fixtures.read_dir(workspace.output)

      assert.are.same({
        modified = {
          "a",
          "b",
          "c",
        },
        deleted = {
          "a",
          "b",
          "c",
        },
      }, files)
    end)
  end)

  it("should not delete files that aren't selected", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_workspace(workspace, {
        ["nested/deleted/file"] = { "a", "b", "c" },
      }, {
        ["nested/added/file"] = { "a", "b", "c" },
      })

      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

      changeset["nested/added/file"].selected = true
      api.changeset.write_changeset(changeset, workspace.output)

      local files = fixtures.read_dir(workspace.output)

      assert.are.same({
        ["nested/added/file"] = {
          "a",
          "b",
          "c",
        },
        ["nested/deleted/file"] = {
          "a",
          "b",
          "c",
        },
      }, files)
    end)
  end)

  it("should apply only selected lines", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)

      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

      changeset.modified.selected_lines = {
        left = {
          [2] = true,
        },
        right = {
          [1] = true,
        },
      }
      changeset.deleted.selected_lines = {
        left = {
          [1] = true,
        },
      }
      api.changeset.write_changeset(changeset, workspace.output)

      local files = fixtures.read_dir(workspace.output)

      assert.are.same({
        deleted = {
          "b",
          "c",
        },
        modified = {
          "a",
          "a1",
          "c",
        },
      }, files)
    end)
  end)

  it("should copy a selected added file", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)

      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

      changeset.deleted.selected = true
      changeset.added.selected = true
      api.changeset.write_changeset(changeset, workspace.output)

      local files = fixtures.read_dir(workspace.output)

      assert.are.same({
        modified = {
          "a",
          "b",
          "c",
        },
        added = {
          "a",
          "b",
          "c",
        },
      }, files)
    end)
  end)

  it("should copy some lines from an added file", function()
    fixtures.with_workspace(function(workspace)
      fixtures.prepare_simple_workspace(workspace)

      local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

      changeset.deleted.selected = true
      changeset.added.selected_lines = {
        right = {
          [1] = true,
        },
      }
      api.changeset.write_changeset(changeset, workspace.output)

      local files = fixtures.read_dir(workspace.output)

      assert.are.same({
        modified = {
          "a",
          "b",
          "c",
        },
        added = {
          "a",
        },
      }, files)
    end)
  end)

  describe("when the disk changes after loading", function()
    it("applies partial selections to the snapshot that produced the hunks", function()
      fixtures.with_workspace(function(workspace)
        fixtures.prepare_workspace(workspace, {
          ["right-changed.txt"] = { "a", "b", "c" },
          ["left-changed.txt"] = { "a", "b", "c" },
        }, {
          ["right-changed.txt"] = { "a", "B", "c" },
          ["left-changed.txt"] = { "a", "B", "c" },
        })

        local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
        changeset["right-changed.txt"].selected_lines.right[2] = true
        changeset["left-changed.txt"].selected_lines.right[2] = true

        api.fs.write_file(workspace.right .. "/right-changed.txt", { "NEW", "a", "B", "c" })
        api.fs.write_file(workspace.left .. "/left-changed.txt", { "EXT", "a", "b", "c" })

        api.changeset.write_changeset(changeset, workspace.output)

        assert.are.same({
          ["left-changed.txt"] = { "a", "b", "B", "c" },
          ["right-changed.txt"] = { "a", "b", "B", "c" },
        }, fixtures.read_dir(workspace.output))
      end)
    end)

    it("writes the snapshot of files selected as a whole", function()
      fixtures.with_workspace(function(workspace)
        fixtures.prepare_workspace(workspace, {
          ["modified.txt"] = { "a", "b", "c" },
        }, {
          ["modified.txt"] = { "a", "B", "c" },
          ["added.txt"] = { "n1", "n2" },
        })

        local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
        changeset["modified.txt"].selected = true
        changeset["added.txt"].selected = true

        api.fs.write_file(workspace.right .. "/modified.txt", { "reviewed", "away" })
        api.fs.write_file(workspace.right .. "/added.txt", { "also", "gone" })

        api.changeset.write_changeset(changeset, workspace.output)

        assert.are.same({
          ["added.txt"] = { "n1", "n2" },
          ["modified.txt"] = { "a", "B", "c" },
        }, fixtures.read_dir(workspace.output))
      end)
    end)

    it("writes the snapshot of files left unselected", function()
      fixtures.with_workspace(function(workspace)
        fixtures.prepare_workspace(workspace, {
          ["modified.txt"] = { "a", "b", "c" },
          ["deleted.txt"] = { "x", "y" },
        }, {
          ["modified.txt"] = { "a", "B", "c" },
        })

        local changeset = api.changeset.load_changeset(workspace.left, workspace.right)

        api.fs.write_file(workspace.left .. "/modified.txt", { "EXT", "a", "b", "c" })
        api.fs.write_file(workspace.left .. "/deleted.txt", { "changed" })

        api.changeset.write_changeset(changeset, workspace.output)

        assert.are.same({
          ["deleted.txt"] = { "x", "y" },
          ["modified.txt"] = { "a", "b", "c" },
        }, fixtures.read_dir(workspace.output))
      end)
    end)

    it("leaves a whole-file selection already in place", function()
      fixtures.with_workspace(function(workspace)
        fixtures.prepare_workspace(workspace, {
          ["modified.txt"] = { "a", "b", "c" },
        }, {
          ["modified.txt"] = { "a", "B", "c" },
          ["added.txt"] = { "n1", "n2" },
        })

        local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
        changeset["modified.txt"].selected = true
        changeset["added.txt"].selected = true

        api.fs.write_file(workspace.right .. "/modified.txt", { "saved", "after", "load" })
        api.fs.write_file(workspace.right .. "/added.txt", { "also", "saved" })

        api.changeset.write_changeset(changeset, workspace.right)

        assert.are.same({
          ["added.txt"] = { "also", "saved" },
          ["modified.txt"] = { "saved", "after", "load" },
        }, fixtures.read_dir(workspace.right))
      end)
    end)

    it("preserves a selected file that could not be read at load", function()
      fixtures.with_workspace(function(workspace)
        fixtures.prepare_workspace(workspace, {
          ["unreadable.txt"] = { "contents" },
        }, {
          ["unreadable.txt"] = { "contents" },
        })

        assert(vim.loop.fs_chmod(workspace.right .. "/unreadable.txt", 0))
        local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
        changeset["unreadable.txt"].selected = true
        assert(vim.loop.fs_chmod(workspace.right .. "/unreadable.txt", 420))

        api.changeset.write_changeset(changeset, workspace.output)

        assert.are.same({ ["unreadable.txt"] = { "contents" } }, fixtures.read_dir(workspace.output))
      end)
    end)

    it("writes the snapshot when a side no longer exists on disk", function()
      fixtures.with_workspace(function(workspace)
        fixtures.prepare_workspace(workspace, {
          ["whole.txt"] = { "a", "b", "c" },
          ["partial.txt"] = { "a", "b", "c" },
        }, {
          ["whole.txt"] = { "a", "B", "c" },
          ["partial.txt"] = { "a", "B", "c" },
        })

        local changeset = api.changeset.load_changeset(workspace.left, workspace.right)
        changeset["whole.txt"].selected = true
        changeset["partial.txt"].selected_lines.right[2] = true

        vim.fn.delete(workspace.right .. "/whole.txt")
        vim.fn.delete(workspace.right .. "/partial.txt")

        api.changeset.write_changeset(changeset, workspace.output)

        assert.are.same({
          ["partial.txt"] = { "a", "b", "B", "c" },
          ["whole.txt"] = { "a", "B", "c" },
        }, fixtures.read_dir(workspace.output))
      end)
    end)
  end)
end)

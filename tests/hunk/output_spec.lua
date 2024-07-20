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
        added = {
          "a",
        },
      }, files)
    end)
  end)
end)

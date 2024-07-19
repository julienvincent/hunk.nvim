local fixtures = require("tests.utils.fixtures")
local api = require("difftool.api")
local utils = require("difftool.utils")

describe("changesets", function()
  fixtures.with_workspace(function(workspace)
    fixtures.prepare_simple_workspace(workspace)

    local changeset, paths = api.changeset.load_changeset(workspace.left, workspace.right)

    it("contains all files from both sides of diff", function()
      assert.is_true(utils.included_in_table(paths, "added"))
      assert.is_true(utils.included_in_table(paths, "modified"))
      assert.is_true(utils.included_in_table(paths, "deleted"))
      assert.are.equal(#paths, 3)
    end)

    it("creates a correct modified change", function()
      local change = changeset["modified"]
      assert.are.equal(change.filepath, "modified")
      assert.are.equal(change.type, "modified")
      assert.are.same(change.hunks, {
        { left = { 1, 2 }, right = { 1, 1 } },
        { left = { 3, 0 }, right = { 3, 2 } },
      })
    end)

    it("creates a correct added change", function()
      local change = changeset["added"]
      assert.are.equal(change.filepath, "added")
      assert.are.equal(change.type, "added")
      assert.are.same(change.hunks, {
        { left = { 0, 0 }, right = { 1, 3 } },
      })
    end)

    it("creates a correct deleted change", function()
      local change = changeset["deleted"]
      assert.are.equal(change.filepath, "deleted")
      assert.are.equal(change.type, "deleted")
      assert.are.same(change.hunks, {
        { left = { 1, 3 }, right = { 0, 0 } },
      })
    end)
  end)
end)

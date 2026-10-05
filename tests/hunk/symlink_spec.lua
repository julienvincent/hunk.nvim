local fixtures = require("tests.utils.fixtures")
local utils = require("hunk.utils")
local fs = require("hunk.api.fs")
local api = require("hunk.api")

local function create_symlink(dst, source)
  assert(vim.loop.fs_symlink(source, dst))
end

local function prepare_symlinks(workspace)
  fs.write_file(workspace.left .. "/had-content", { "1", "2", "3" })
  create_symlink(workspace.left .. "/was-symlink1", "some-target")
  create_symlink(workspace.left .. "/was-symlink2", "some-target")

  create_symlink(workspace.right .. "/had-content", "some-target")
  fs.write_file(workspace.right .. "/was-symlink1", { "1", "2", "3" })
  create_symlink(workspace.right .. "/new-symlink", "some-target2")

  create_symlink(workspace.output .. "/had-content", "some-target")
  fs.write_file(workspace.output .. "/was-symlink1", { "1", "2", "3" })
  create_symlink(workspace.output .. "/new-symlink", "some-target2")
end

describe("symlinks", function()
  it("should correctly load a changeset with symlinks", function()
    fixtures.with_workspace(function(workspace)
      prepare_symlinks(workspace)

      local changeset, files = api.changeset.load_changeset(workspace.left, workspace.right)

      it("contains all files from both sides of diff", function()
        assert.is_true(utils.included_in_table(files, "had-content"), "missing had-content")
        assert.is_true(utils.included_in_table(files, "was-symlink1"), "missing was-symlink1")
        assert.is_true(utils.included_in_table(files, "was-symlink2"), "missing was-symlink2")
        assert.is_true(utils.included_in_table(files, "new-symlink"), "missing new-symlink")
        assert.are.equal(#files, 4)
      end)

      it("creates a correct had-content change", function()
        local change = changeset["had-content"]
        assert.are.equal(nil, change.left_file.symlink)
        assert.are.equal("some-target", change.right_file.symlink)
        assert.are.equal("modified", change.type)
        assert.are.same({}, change.hunks)
      end)

      it("creates a correct was-symlink change", function()
        local change = changeset["was-symlink1"]
        assert.are.equal("some-target", change.left_file.symlink)
        assert.are.equal(nil, change.right_file.symlink)
        assert.are.equal("modified", change.type)
        assert.are.same({}, change.hunks)
      end)

      it("creates a correct was-symlink change", function()
        local change = changeset["was-symlink2"]
        assert.are.equal("some-target", change.left_file.symlink)
        assert.are.equal(nil, change.right_file.symlink)
        assert.are.equal("deleted", change.type)
        assert.are.same({}, change.hunks)
      end)

      it("creates a correct was-symlink change", function()
        local change = changeset["new-symlink"]
        assert.are.equal(nil, change.left_file.symlink)
        assert.are.equal("some-target2", change.right_file.symlink)
        assert.are.equal("added", change.type)
        assert.are.same({}, change.hunks)
      end)
    end)
  end)
end)

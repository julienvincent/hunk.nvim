local file_tree = require("hunk.api.file_tree")

local function changeset_for(paths)
  local changeset = {}
  for _, path in ipairs(paths) do
    changeset[path] = { filepath = path, type = "modified" }
  end
  return changeset
end

local function describe_nodes(nodes)
  return vim.tbl_map(function(node)
    return { node.type, node.name, describe_nodes(node.children) }
  end, nodes)
end

describe("compact file tree", function()
  it("compacts long directory chains while preserving file change references", function()
    local changeset = changeset_for({ "lua/hunk/api/fs.lua" })
    local nodes = file_tree.build_compact_file_tree(changeset)
    assert.are.same({
      { "dir", "lua/hunk/api", { { "file", "fs.lua", {} } } },
    }, describe_nodes(nodes))
    assert.are.equal(changeset["lua/hunk/api/fs.lua"], nodes[1].children[1].change)
    assert.are.equal("lua/hunk/api/fs.lua", nodes[1].children[1].change.filepath)
    assert.are.equal(nodes[1].children[1], file_tree.find_first_file_in_tree(nodes))
  end)

  it("stops at branching directories and compacts each branch independently", function()
    local nodes = file_tree.build_compact_file_tree(changeset_for({
      "lua/hunk/ui/panels/tree.lua",
      "lua/hunk/api/internal/fs.lua",
    }))
    assert.are.same({
      {
        "dir",
        "lua/hunk",
        {
          { "dir", "api/internal", { { "file", "fs.lua", {} } } },
          { "dir", "ui/panels", { { "file", "tree.lua", {} } } },
        },
      },
    }, describe_nodes(nodes))
  end)

  it("keeps files beside subdirectories and sorts directories before files", function()
    local nodes = file_tree.build_compact_file_tree(changeset_for({
      "README.md",
      "src/z.lua",
      "src/api/internal/b.lua",
      "src/a.lua",
      "src/api/internal/a.lua",
    }))
    assert.are.same({
      {
        "dir",
        "src",
        {
          { "dir", "api/internal", { { "file", "a.lua", {} }, { "file", "b.lua", {} } } },
          { "file", "a.lua", {} },
          { "file", "z.lua", {} },
        },
      },
      { "file", "README.md", {} },
    }, describe_nodes(nodes))
  end)

  it("keeps root files as individual rows", function()
    local nodes = file_tree.build_compact_file_tree(changeset_for({ "z.lua", "a.lua" }))
    assert.are.same({ { "file", "a.lua", {} }, { "file", "z.lua", {} } }, describe_nodes(nodes))
  end)

  it("handles an empty changeset", function()
    local nodes = file_tree.build_compact_file_tree({})
    assert.are.same({}, nodes)
    assert.is_nil(file_tree.find_first_file_in_tree(nodes))
  end)

  it("leaves nested and flat trees and the input changeset unchanged", function()
    local changeset = changeset_for({ "src/api/fs.lua" })
    local original = vim.deepcopy(changeset)
    local nested = file_tree.build_file_tree(changeset)
    file_tree.build_compact_file_tree(changeset)
    assert.are.same({
      { "dir", "src", { { "dir", "api", { { "file", "fs.lua", {} } } } } },
    }, describe_nodes(nested))
    assert.are.same(describe_nodes(nested), describe_nodes(file_tree.build_file_tree(changeset)))
    assert.are.same({ { "file", "src/api/fs.lua", {} } }, describe_nodes(file_tree.build_flat_file_tree(changeset)))
    assert.are.same(original, changeset)
  end)
end)

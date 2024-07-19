local fs = require("difftool.api.fs")

local M = {}

local function create_temp_dir()
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir)
  return temp_dir
end

function M.with_workspace(cb)
  local workspace = {
    left = create_temp_dir(),
    right = create_temp_dir(),
    output = create_temp_dir(),
  }

  cb(workspace)

  vim.fn.system("rm -r " .. workspace.left)
  vim.fn.system("rm -r " .. workspace.right)
  vim.fn.system("rm -r " .. workspace.output)
end

M.with_workspace(function(workspace)
  print(workspace.left)
end)

function M.prepare_workspace(workspace, left, right)
  for path, content in pairs(left) do
    fs.write_file(workspace.left .. "/" .. path, content)
  end

  for path, content in pairs(right) do
    fs.write_file(workspace.right .. "/" .. path, content)
    fs.write_file(workspace.output .. "/" .. path, content)
  end
end

function M.prepare_simple_workspace(workspace)
  M.prepare_workspace(workspace, {
    ["modified"] = { "a", "b", "c" },
    ["deleted"] = { "a", "b", "c" },
  }, {
    ["modified"] = { "a1", "c", "d", "e" },
    ["added"] = { "a", "b", "c" },
  })
end

return M

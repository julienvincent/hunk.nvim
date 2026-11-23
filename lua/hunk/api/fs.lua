local M = {}

local uv = vim.loop

function M.scan_dir(dir)
  dir = (dir:gsub("/+$", ""))
  local out = {}

  local function relative_path(full)
    return full:sub(#dir + 2)
  end

  local function walk(path)
    local fd = uv.fs_scandir(path)
    if not fd then
      return
    end

    while true do
      local name, ftype = uv.fs_scandir_next(fd)
      if not name then
        break
      end

      local full = path .. "/" .. name

      if ftype == "directory" then
        walk(full)
      elseif ftype == "file" then
        local file_path = relative_path(full)
        out[file_path] = { path = file_path }
      elseif ftype == "link" then
        local file_path = relative_path(full)
        out[file_path] = {
          path = file_path,
          symlink = uv.fs_readlink(full),
        }
      end
    end
  end

  walk(dir)

  return out
end

function M.read_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

function M.read_link(file_path)
  return uv.fs_readlink(file_path)
end

function M.split_lines(content)
  local lines = vim.split(content, "\n")
  if lines[#lines] == "" then
    table.remove(lines, #lines)
  end
  return lines
end

function M.read_file_as_lines(file_path)
  return M.split_lines(M.read_file(file_path) or "")
end

function M.make_parents(file_path)
  local parent_dir = file_path:match("(.*/)")
  vim.fn.mkdir(parent_dir, "p")
end

function M.move_file(src, dst)
  M.make_parents(dst)
  local ok, err, code = uv.fs_rename(src, dst)
  if code == "EXDEV" then
    -- rename() supports cross-filesystem moves, but cannot move dangling symlinks.
    assert(vim.fn.rename(src, dst) == 0, "Failed to move " .. src .. " to " .. dst)
  else
    assert(ok, err)
  end
end

function M.rm_file(file)
  local ok, err, code = uv.fs_unlink(file)
  assert(ok or code == "ENOENT", err)
end

function M.write_symlink(file_path, target)
  M.make_parents(file_path)
  M.rm_file(file_path)

  local ok, err = uv.fs_symlink(target, file_path)
  assert(ok, err)
end

function M.write_file(file_path, content)
  M.make_parents(file_path)

  local file = io.open(file_path, "w")
  if not file then
    return
  end

  for _, line in ipairs(content) do
    file:write(line .. "\n")
  end

  file:close()
end

function M.write_bytes(file_path, content)
  M.make_parents(file_path)

  local file = assert(io.open(file_path, "w"), "Failed to write " .. file_path)
  file:write(content)
  file:close()
end

return M

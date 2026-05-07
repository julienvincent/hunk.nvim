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

function M.read_file_as_lines(file_path)
  local content = vim.split(M.read_file(file_path) or "", "\n")
  if content[#content] == "" then
    table.remove(content, #content)
  end
  return content
end

function M.make_parents(file_path)
  local parent_dir = vim.fs.dirname(file_path)
  if parent_dir == "." or parent_dir == "" then
    return
  end

  vim.fn.mkdir(parent_dir, "p")
end

function M.move_file(src, dst)
  M.make_parents(dst)
  vim.fn.system({ "mv", src, dst })
end

function M.rm_file(file)
  vim.fn.system({ "rm", file })
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

return M

local M = {}

function M.list_files_recursively(dir)
  local files = {}
  local p = io.popen('find "' .. dir .. '" -type f')
  if not p then
    return {}
  end
  for file in p:lines() do
    table.insert(files, file)
  end
  p:close()
  return vim.tbl_map(function(file)
    return string.sub(file, #dir + 2)
  end, files)
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
  local parent_dir = file_path:match("(.*/)")
  vim.fn.mkdir(parent_dir, "p")
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

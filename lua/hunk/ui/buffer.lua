local fs = require("hunk.api.fs")

local M = {}

function M.create(opts)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == opts.name then
      return buf
    end
  end

  local buf = vim.api.nvim_create_buf(false, false)
  local lines = {}
  if opts.file then
    if opts.file.symlink then
      lines = { opts.file.symlink }
    else
      lines = fs.read_file_as_lines(opts.file.path)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for key, value in pairs({
    buftype = opts.buftype or "nofile",
    modifiable = false,
    modified = false,
    readonly = true,
    swapfile = false,
  }) do
    vim.api.nvim_set_option_value(key, value, { buf = buf })
  end
  vim.api.nvim_buf_set_name(buf, opts.name)
  return buf
end

return M

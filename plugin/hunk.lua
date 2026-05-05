if vim.g.loaded_hunk_nvim then
  return
end
vim.g.loaded_hunk_nvim = true

vim.api.nvim_create_user_command("DiffEditor", function(params)
  local args = params.fargs
  if #args < 2 then
    vim.notify("Error: DiffEditor expects three arguments (left, right[, output])", vim.log.levels.ERROR)
    return
  end
  require("hunk").start(args[1], args[2], args[3] or args[2])
end, {
  nargs = "*",
})

vim.api.nvim_create_user_command("MergeEditor", function(params)
  local args = params.fargs
  if #args < 4 then
    vim.notify("Error: MergeEditor expects arguments (base, left, right, output[, path])", vim.log.levels.ERROR)
    return
  end
  require("hunk.merge").start(args[1], args[2], args[3], args[4], args[5])
end, {
  nargs = "*",
})

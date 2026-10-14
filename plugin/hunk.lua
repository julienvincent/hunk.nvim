if vim.g.loaded_hunk_nvim then
  return
end
vim.g.loaded_hunk_nvim = true

vim.api.nvim_create_user_command("HunkDiffView", function(params)
  local args = params.fargs
  if #args == 0 then
    args = vim.fn.argv()
  end
  if #args ~= 2 then
    vim.notify("Error: HunkDiffView expects two directories (left, right)", vim.log.levels.ERROR)
    return
  end
  require("hunk.diff_view").start(args[1], args[2])
end, {
  nargs = "*",
  -- Custom completion avoids filename expansion when lazy.nvim replays the command.
  complete = function(arg_lead)
    return vim.fn.getcompletion(arg_lead, "dir")
  end,
})

vim.api.nvim_create_user_command("DiffEditor", function(params)
  local args = params.fargs
  if #args < 2 then
    vim.notify("Error: DiffEditor expects three arguments (left, right[, output])", vim.log.levels.ERROR)
    return
  end
  require("hunk.diff_editor").start(args[1], args[2], args[3] or args[2])
end, {
  nargs = "*",
})

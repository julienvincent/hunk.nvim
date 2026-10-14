local root = vim.env.HUNK_TEST_ROOT
vim.opt.runtimepath:append(root .. "/.build/dependencies/nui.nvim")
vim.opt.runtimepath:append(root)
vim.o.loadplugins = false
vim.cmd("filetype on")

local panes = {}
local dirs
require("hunk").setup({
  hooks = {
    on_tree_mount = function(context)
      local _, change = next(context.opts.changeset)
      dirs = { vim.fs.dirname(change.left_file.path), vim.fs.dirname(change.right_file.path) }
    end,
    on_diff_mount = function(context)
      table.insert(panes, context)
    end,
  },
})

require("hunk.api.changeset").write_changeset = function()
  error("Viewer must not write changesets")
end

-- Match lazy.nvim's command replay before loading the real command.
vim.api.nvim_create_user_command("HunkDiffView", function(params)
  vim.api.nvim_del_user_command("HunkDiffView")
  vim.cmd.runtime({ "plugin/hunk.lua", bang = true })
  vim.cmd({ cmd = "HunkDiffView", args = params.fargs, nargs = "*" })
end, {
  nargs = "*",
  complete = function()
    return {}
  end,
})

vim.cmd("args NvimTree_1")
vim.api.nvim_set_current_dir(vim.env.HUNK_TEST_CWD)

local function check()
  for _, module in ipairs({
    "hunk.diff_editor",
    "hunk.diff_editor.file",
    "hunk.diff_editor.tree",
    "hunk.api.signs",
  }) do
    assert(not package.loaded[module], "Viewer loaded editor module: " .. module)
  end
  assert(#panes == 2, "Expected two diff panes")
  assert(vim.fn.fnamemodify(vim.fn.argv(0), ":t") == "NvimTree_1", "Expected a mutated argument list")
  for index, side in ipairs({ "LEFT", "RIGHT" }) do
    local pane = panes[index]
    local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
    local expected = vim.env["HUNK_EXPECT_" .. side]
    if expected and expected ~= "" then
      assert(vim.deep_equal(vim.json.decode(expected), lines), side .. " contents do not match")
    end
    if vim.env.HUNK_CONFLICT_SIDE == side then
      local text = table.concat(lines, "\n")
      assert(text:find("<<<<<<<", 1, true), "Expected conflict start marker")
      assert(text:find("-------", 1, true), "Expected snapshot base marker")
      assert(text:find("+++++++", 1, true), "Expected snapshot side marker")
    end
    assert(not vim.api.nvim_get_option_value("modifiable", { buf = pane.buf }))
    assert(vim.api.nvim_get_option_value("diff", { win = pane.win }))
  end

  assert(vim.fn.isdirectory(dirs[1]) == 1 and vim.fn.isdirectory(dirs[2]) == 1)
  vim.fn.writefile(dirs, vim.env.HUNK_TEST_MANIFEST)
  vim.api.nvim_set_current_win(panes[2].win)
  vim.fn.maparg("q", "n", false, true).callback()
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local ok, err = pcall(check)
    if not ok then
      io.stderr:write(tostring(err) .. "\n")
      vim.cmd.cquit()
    end
  end,
})

local hunk = require("hunk")
local config = require("hunk.config")
local fs = require("hunk.api.fs")

local function invoke(win, key, row)
  vim.api.nvim_set_current_win(win)
  if row then
    vim.api.nvim_win_set_cursor(win, { row, 0 })
  end
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert.is_function(mapping.callback)
  mapping.callback()
end

describe("compact tree interactions", function()
  local original_config
  local original_qa
  local existing_bufs
  local workspace
  local tree_context
  local panes

  local function tree_lines()
    return vim.api.nvim_buf_get_lines(tree_context.buf, 0, -1, false)
  end

  before_each(function()
    vim.cmd("silent! only!")
    vim.cmd("enew!")
    original_config = vim.deepcopy(config)
    original_qa = vim.cmd.qa
    existing_bufs = vim.api.nvim_list_bufs()
    local root = vim.fn.tempname()
    workspace = { root = root, left = root .. "/left", right = root .. "/right", output = root .. "/output" }
    panes = {}
    for _, path in ipairs({ "lua/hunk/api/core/a.lua", "lua/hunk/api/core/b.lua", "lua/hunk/ui/c.lua", "README.md" }) do
      for _, side in ipairs({ "left", "right" }) do
        fs.make_parents(workspace[side] .. "/" .. path)
        fs.write_file(workspace[side] .. "/" .. path, { side .. " " .. path })
      end
    end
    hunk.setup({
      ui = { tree = { mode = "compact" } },
      icons = { enable_file_icons = false },
      hooks = {
        on_tree_mount = function(context)
          tree_context = context
        end,
        on_diff_mount = function(context)
          panes[context.win] = context
        end,
      },
    })
  end)

  after_each(function()
    vim.cmd.qa = original_qa
    hunk.setup(original_config)
    vim.cmd("silent! only!")
    vim.cmd("enew!")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if not vim.tbl_contains(existing_bufs, buf) and buf ~= vim.api.nvim_get_current_buf() then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.fn.delete(workspace.root, "rf")
  end)

  for _, mode in ipairs({ "view", "edit" }) do
    for _, use_float in ipairs({ false, true }) do
      local layout_name = use_float and "floating" or "split"
      it("navigates compacted paths in " .. mode .. " mode with a " .. layout_name .. " tree", function()
        hunk.setup({ ui = { tree = { use_float = use_float, float = { border = "single" } } } })
        if mode == "view" then
          assert.is_true(hunk.view(workspace.left, workspace.right))
        else
          hunk.start(workspace.left, workspace.right, workspace.output)
        end
        local tree_win = tree_context.win
        assert.are.equal(7, #tree_lines())
        assert.is_truthy(tree_lines()[1]:find("lua/hunk", 1, true))
        assert.is_truthy(tree_lines()[2]:find("api/core", 1, true))
        assert.are.equal(3, vim.api.nvim_win_get_cursor(tree_win)[1])
        assert.are.equal("lua/hunk/api/core/a.lua", tree_context.tree:get_node(3).change.filepath)

        invoke(tree_win, "h", 1)
        assert.are.equal(2, #tree_lines())
        invoke(tree_win, "l")
        assert.are.equal(7, #tree_lines())
        invoke(tree_win, "l", 4)
        assert.are.equal(tree_win, vim.api.nvim_get_current_win())
        invoke(tree_win, "<Cr>")
        local right_win = vim.api.nvim_get_current_win()
        local right_buf = panes[right_win].buf
        assert.are.same({ "right lua/hunk/api/core/b.lua" }, vim.api.nvim_buf_get_lines(right_buf, 0, -1, false))
        invoke(right_win, "<leader>e")
        tree_win = vim.api.nvim_get_current_win()
        assert.are.equal(tree_context.buf, vim.api.nvim_win_get_buf(tree_win))
        assert.are.equal(4, vim.api.nvim_win_get_cursor(tree_win)[1])
      end)
    end
  end

  it("selects all descendants of a collapsed compacted directory and writes only those changes", function()
    hunk.start(workspace.left, workspace.right, workspace.output)
    local tree_win = tree_context.win
    local changeset = tree_context.opts.changeset
    invoke(tree_win, "a", 3)
    assert.is_truthy(tree_lines()[1]:find(config.icons.partially_selected, 1, true))
    invoke(tree_win, "h", 1)
    invoke(tree_win, "a")
    assert.is_truthy(tree_lines()[1]:find(config.icons.selected, 1, true))
    for path, change in pairs(changeset) do
      assert.are.equal(path ~= "README.md", change.selected)
    end
    invoke(tree_win, "a")
    assert.is_truthy(tree_lines()[1]:find(config.icons.deselected, 1, true))
    for _, change in pairs(changeset) do
      assert.is_false(change.selected)
    end
    invoke(tree_win, "a")
    vim.cmd.qa = function() end
    invoke(tree_win, "<leader><Cr>")
    assert.are.equal("right lua/hunk/api/core/b.lua\n", fs.read_file(workspace.output .. "/lua/hunk/api/core/b.lua"))
    assert.are.equal("right lua/hunk/ui/c.lua\n", fs.read_file(workspace.output .. "/lua/hunk/ui/c.lua"))
    assert.are.equal("left README.md\n", fs.read_file(workspace.output .. "/README.md"))
  end)
end)

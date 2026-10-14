local config = require("hunk.config")
local utils = require("hunk.utils")
local tree_ui = require("hunk.ui.tree")

local function get_changeset_recursive(node, changeset)
  changeset = changeset or {}

  for _, child in ipairs(node.children) do
    if child.type == "file" then
      table.insert(changeset, child.change)
    else
      get_changeset_recursive(child, changeset)
    end
  end

  return changeset
end

local function get_dir_selection_state(node)
  local all_selected = true
  local at_least_one_selected = false

  local changeset = get_changeset_recursive(node)

  for _, change in ipairs(changeset) do
    if not change.selected then
      all_selected = false
    end
    if change.selected then
      at_least_one_selected = true
    elseif utils.any_lines_selected(change) then
      at_least_one_selected = true
    end
  end

  if all_selected then
    return "all"
  end

  if at_least_one_selected then
    return "partial"
  end

  return "none"
end

local function get_dir_icon(node)
  local state = get_dir_selection_state(node)
  if state == "all" then
    return config.icons.selected
  end

  if state == "partial" then
    return config.icons.partially_selected
  end

  return config.icons.deselected
end

local function get_file_icon(change)
  if change.selected then
    return config.icons.selected
  end

  if utils.any_lines_selected(change) then
    return config.icons.partially_selected
  end

  return config.icons.deselected
end

local M = {}

function M.create(opts)
  return tree_ui.create(vim.tbl_extend("force", opts, {
    render_prefix = function(line, node)
      local selection_icon
      if node.type == "dir" then
        selection_icon = get_dir_icon(node)
      else
        selection_icon = get_file_icon(node.change)
      end

      line:append(selection_icon .. " ", "HunkTreeSelectionIcon")
    end,
    on_mount = function(tree)
      local callback_opts = { tree = tree }

      for _, chord in ipairs(utils.into_table(config.keys.tree.toggle_file)) do
        vim.keymap.set("n", chord, function()
          local node = tree.get_node()
          if node and node.type == "file" then
            opts.on_toggle(node.change, nil, callback_opts)
            return
          end

          local changeset = get_changeset_recursive(node)
          local state = get_dir_selection_state(node)
          for _, change in ipairs(changeset) do
            opts.on_toggle(change, state ~= "all", callback_opts)
          end
        end, {
          buffer = tree.buf,
          desc = "Toggle all hunks in file under cursor",
          nowait = true,
        })
      end
    end,
  }))
end

return M

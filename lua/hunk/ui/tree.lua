local file_tree_api = require("hunk.api.file_tree")
local config = require("hunk.config")
local utils = require("hunk.utils")

local NuiTree = require("nui.tree")
local Text = require("nui.text")
local Line = require("nui.line")

local function get_file_extension(path)
  local extension = path:match("^.+(%..+)$")
  if not extension then
    return ""
  end
  return string.sub(extension, 2) or ""
end

local function get_icon(path)
  if not config.icons.enable_file_icons then
    return nil
  end

  local has_mini_icons, mini_icons = pcall(require, "mini.icons")

  if has_mini_icons then
    return mini_icons.get("file", path)
  end

  local has_web_devicons, web_devicons = pcall(require, "nvim-web-devicons")
  if has_web_devicons then
    return web_devicons.get_icon(path, get_file_extension(path), {})
  end
end

local function get_change_color(prefix, change)
  if change.type == "added" then
    return prefix .. "Added"
  end
  if change.type == "deleted" then
    return prefix .. "Deleted"
  end
  return prefix .. "Modified"
end

local function file_tree_to_nodes(file_tree)
  return vim.tbl_map(function(node)
    local line = {}

    if node.type == "file" then
      local icon, color = get_icon(node.change.filepath)
      if icon then
        table.insert(line, Text(icon .. " ", color))
      end
    end

    local highlight
    if node.type == "dir" then
      highlight = "Green"
    elseif node.type == "file" then
      highlight = get_change_color("HunkTreeFile", node.change)
    else
      error("Unknown node type '" .. node.type .. "'")
    end
    table.insert(line, Text(node.name, highlight))

    local children = file_tree_to_nodes(node.children)

    local ui_node = NuiTree.Node({
      line = line,
      change = node.change,
      children = node.children,
      type = node.type,
    }, children)
    ui_node:expand()
    return ui_node
  end, file_tree)
end

local function find_node_by_filepath(tree, path, nodes)
  nodes = nodes or tree:get_nodes()
  for _, node in pairs(nodes) do
    local children = vim.tbl_map(function(id)
      return tree:get_node(id)
    end, node:get_child_ids())

    local match, match_linenr = find_node_by_filepath(tree, path, children)
    if match then
      return match, match_linenr
    end

    if node.type == "file" then
      local _, linenr = tree:get_node(node:get_id())
      if linenr and node.change.filepath == path then
        return node, linenr
      end
    end
  end
end

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
  local tree = NuiTree({
    winid = opts.winid,
    bufnr = vim.api.nvim_win_get_buf(opts.winid),
    nodes = {},

    prepare_node = function(node)
      local line = Line()

      line:append(string.rep("  ", node:get_depth() - 1))

      if node:has_children() then
        if node:is_expanded() then
          local icon = config.icons.expanded or ""
          line:append(icon .. " ", "Comment")
        else
          local icon = config.icons.collapsed or ""
          line:append(icon .. " ", "Comment")
        end
      else
        line:append("  ")
      end

      local selection_icon
      if node.type == "dir" then
        selection_icon = get_dir_icon(node)
      else
        selection_icon = get_file_icon(node.change)
      end

      line:append(selection_icon .. " ", "HunkTreeSelectionIcon")

      if node.type == "dir" then
        local icon = config.icons.folder_closed
        if node:is_expanded() then
          icon = config.icons.folder_open
        end
        line:append(icon .. " ", "HunkTreeDirIcon")
      end

      for _, text in ipairs(node.line) do
        line:append(text)
      end

      return line
    end,
  })

  local buf = vim.api.nvim_win_get_buf(opts.winid)

  local Component = {
    buf = buf,
  }

  function Component.render()
    tree:render()
  end

  local callback_opts = { tree = Component }

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = buf,
      desc = desc,
      nowait = true,
    })
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.open_file)) do
    map("n", chord, function()
      local node = tree:get_node()
      if node and node.type == "file" then
        opts.on_open(node.change, callback_opts)
      end
    end, "Open file under cursor")
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.expand_node)) do
    map("n", chord, function()
      local node = tree:get_node()
      if not node then
        return
      end
      if node.type == "file" then
        opts.on_preview(node.change, callback_opts)
      end
      if node.type == "dir" and not node:is_expanded() then
        node:expand()
        Component.render()
      end
    end, "Expand or preview node under cursor")
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.collapse_node)) do
    map("n", chord, function()
      local node = tree:get_node()
      if node and node.type == "dir" and node:is_expanded() then
        node:collapse()
        Component.render()
      end
    end, "Collapse node under cursor")
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.toggle_file)) do
    map("n", chord, function()
      local node = tree:get_node()
      if node and node.type == "file" then
        opts.on_toggle(node.change, nil, callback_opts)
        return
      end

      local changeset = get_changeset_recursive(node)
      local state = get_dir_selection_state(node)
      for _, change in ipairs(changeset) do
        opts.on_toggle(change, state ~= "all", callback_opts)
      end
    end, "Toggle all hunks in file under cursor")
  end

  local all_files = {}
  ---@type table<string, integer>
  local filepath_to_idx = {}

  local function collect_files_from_tree(nodes)
    for _, node in ipairs(nodes) do
      if node.type == "file" then
        table.insert(all_files, node.change)
        filepath_to_idx[node.change.filepath] = #all_files
      end
      if node.children and #node.children > 0 then
        collect_files_from_tree(node.children)
      end
    end
  end

  local function get_current_file()
    local current = tree:get_node()
    if current and current.type == "file" then
      return current.change
    end
    local cursor_line = vim.api.nvim_win_get_cursor(opts.winid)[1]
    for _, change in ipairs(all_files) do
      local _, linenr = find_node_by_filepath(tree, change.filepath)
      if linenr and linenr >= cursor_line then
        return change
      end
    end
    return all_files[1]
  end

  ---@param direction "prev" | "next"
  function Component.nav_to_file(direction)
    local current = get_current_file()
    if not current then
      return
    end

    local current_idx = filepath_to_idx[current.filepath]
    local target_idx = utils.calculate_navigation_idx(current_idx, direction, #all_files)
    if not target_idx then
      return
    end

    local target_change = all_files[target_idx]
    local _, linenr = find_node_by_filepath(tree, target_change.filepath)
    if linenr then
      vim.api.nvim_win_set_cursor(opts.winid, { linenr, 0 })
    end

    local _callback_opts = vim.tbl_extend("force", callback_opts, {
      win = vim.api.nvim_get_current_win(),
    })

    opts.on_preview(target_change, _callback_opts)
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.prev_file)) do
    map("n", chord, function()
      Component.nav_to_file("prev")
    end, "Go to prev file")
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.next_file)) do
    map("n", chord, function()
      Component.nav_to_file("next")
    end, "Go to next file")
  end

  local file_tree
  if config.ui.tree.mode == "nested" then
    file_tree = file_tree_api.build_file_tree(opts.changeset)
  elseif config.ui.tree.mode == "flat" then
    file_tree = file_tree_api.build_flat_file_tree(opts.changeset)
  else
    error("Unknown value '" .. config.ui.tree("' for config entry `ui.tree.mode`"))
  end

  tree:set_nodes(file_tree_to_nodes(file_tree))
  Component.render()

  collect_files_from_tree(file_tree)

  local selected_file = file_tree_api.find_first_file_in_tree(file_tree)
  if selected_file then
    local _, selected_linenr = find_node_by_filepath(tree, selected_file.change.filepath)
    if selected_linenr then
      vim.api.nvim_win_set_cursor(opts.winid, { selected_linenr, 0 })
    end

    opts.on_preview(selected_file.change, callback_opts)
  end

  ---@param filepath string
  function Component.nav_to_filepath(filepath)
    local _, linenr = find_node_by_filepath(tree, filepath)
    if linenr then
      vim.api.nvim_win_set_cursor(opts.winid, { linenr, 0 })
    end
  end

  config.hooks.on_tree_mount({ buf = buf, tree = tree, opts = opts })

  return Component
end

return M

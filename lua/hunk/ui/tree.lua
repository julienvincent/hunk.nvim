local signs = require("hunk.api.signs")
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

local function split_path(path)
  local parts = {}
  for part in string.gmatch(path, "([^/]+)") do
    table.insert(parts, part)
  end
  return parts
end

local function insert_path(tree, change)
  local parts = split_path(change.filepath)
  local node = tree
  for i, part in ipairs(parts) do
    local is_last = i == #parts
    local found = false

    for _, child in ipairs(node.children) do
      if child.name == part and child.type == "dir" then
        node = child
        found = true
        break
      end
    end

    if not found then
      local new_node = {
        name = part,
        type = is_last and "file" or "dir",
        change = change,
        children = {},
      }
      table.insert(node.children, new_node)
      node = new_node
    end
  end
end

local function sort_tree(tree)
  table.sort(tree, function(a, b)
    if a.type == b.type then
      return a.name < b.name
    else
      return a.type == "dir" and b.type ~= "dir"
    end
  end)

  for _, child in ipairs(tree) do
    if child.children then
      sort_tree(child.children)
    end
  end
end

local function build_file_tree(changeset)
  local tree = { children = {} }
  for _, change in pairs(changeset) do
    insert_path(tree, change)
  end

  sort_tree(tree.children)

  return tree.children
end

local function build_flat_file_tree(changeset)
  local nodes = {}
  for _, change in pairs(changeset) do
    table.insert(nodes, {
      name = change.filepath,
      type = "file",
      change = change,
      children = {},
    })
  end

  sort_tree(nodes)
  return nodes
end

local function get_icon(path)
  local has_mini_icons, mini_icons = pcall(require, "mini.icons")

  if has_mini_icons then
    return mini_icons.get("file", path)
  end

  local has_web_devicons, web_devicons = pcall(require, "nvim-web-devicons")
  if has_web_devicons then
    return web_devicons.get_icon(path, get_file_extension(path), {})
  end
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
      if node.change.type == "added" then
        highlight = "Green"
      elseif node.change.type == "deleted" then
        highlight = "Red"
      else
        highlight = "Blue"
      end
    else
      error("Unknown node type '" .. node.type .. "'")
    end
    table.insert(line, Text(node.name, highlight))

    local children = file_tree_to_nodes(node.children)

    local ui_node = NuiTree.Node({
      line = line,
      change = node.change,
      type = node.type,
    }, children)
    ui_node:expand()
    return ui_node
  end, file_tree)
end

local function apply_signs(tree, buf, nodes)
  nodes = nodes or tree:get_nodes()
  for _, node in pairs(nodes) do
    if node.type == "file" then
      local _, linenr = tree:get_node(node:get_id())
      if linenr then
        local sign
        if node.change.selected then
          sign = signs.signs.selected
        elseif utils.any_lines_selected(node.change) then
          sign = signs.signs.partially_selected
        else
          sign = signs.signs.deselected
        end
        signs.place_sign(buf, sign, linenr)
      end
    else
      apply_signs(
        tree,
        buf,
        vim.tbl_map(function(id)
          return tree:get_node(id)
        end, node:get_child_ids())
      )
    end
  end
end

local M = {}

function M.create(opts)
  local tree = NuiTree({
    winid = opts.winid,
    nodes = {},

    prepare_node = function(node)
      local line = Line()

      line:append(string.rep("  ", node:get_depth() - 1))

      if node:has_children() then
        if node:is_expanded() then
          line:append(" ", "Comment")
        else
          line:append(" ", "Comment")
        end
      else
        line:append("  ")
      end

      if node.type == "dir" then
        local icon = config.icons.folder_closed
        if node:is_expanded() then
          icon = config.icons.folder_open
        end
        line:append(icon .. " ", "Yellow")
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
    signs.clear_signs(buf)
    apply_signs(tree, buf)
  end

  vim.keymap.set("n", "<Plug>(hunk.tree.open_file)", function()
    local node = tree:get_node()
    if node.type == "file" then
      opts.on_open(node.change)
    end
  end, { buffer = buf, desc = "Open File" })

  vim.keymap.set("n", "<Plug>(hunk.tree.expand_node)", function()
      local node = tree:get_node()
      if node.type == "file" then
        opts.on_preview(node.change)
      end
      if node.type == "dir" and not node:is_expanded() then
        node:expand()
        Component.render()
      end
    end, { buffer = buf, desc = "Expand Folder" })

  vim.keymap.set("n", "<Plug>(hunk.tree.collapse_node)", function()
      local node = tree:get_node()
      if node.type == "dir" and node:is_expanded() then
        node:collapse()
        Component.render()
      end
    end, { buffer = buf, desc = "Collapse Folder" })

  vim.keymap.set("n", "<Plug>(hunk.tree.toggle_file)", function()
      local node = tree:get_node()
      if node.type == "file" then
        opts.on_toggle(node.change)
      end
    end, { buffer = buf, desc = "Toggle File" })

  local context = {
    opts = opts,
    tree = tree,
  }

  utils.set_keys(config.keys.tree, context, buf)

  local file_tree
  if config.ui.tree.mode == "nested" then
    file_tree = build_file_tree(opts.changeset)
  elseif config.ui.tree.mode == "flat" then
    file_tree = build_flat_file_tree(opts.changeset)
  else
    error("Unknown value '" .. config.ui.tree("' for config entry `ui.tree.mode`"))
  end

  tree:set_nodes(file_tree_to_nodes(file_tree))

  return Component
end

return M

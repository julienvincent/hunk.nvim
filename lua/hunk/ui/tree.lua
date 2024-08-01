local file_tree_api = require("hunk.api.file_tree")
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

  for _, chord in ipairs(utils.into_table(config.keys.tree.open_file)) do
    vim.keymap.set("n", chord, function()
      local node = tree:get_node()
      if node.type == "file" then
        opts.on_open(node.change)
      end
    end, { buffer = buf })
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.expand_node)) do
    vim.keymap.set("n", chord, function()
      local node = tree:get_node()
      if node.type == "file" then
        opts.on_preview(node.change)
      end
      if node.type == "dir" and not node:is_expanded() then
        node:expand()
        Component.render()
      end
    end, { buffer = buf })
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.collapse_node)) do
    vim.keymap.set("n", chord, function()
      local node = tree:get_node()
      if node.type == "dir" and node:is_expanded() then
        node:collapse()
        Component.render()
      end
    end, { buffer = buf })
  end

  for _, chord in ipairs(utils.into_table(config.keys.tree.toggle_file)) do
    vim.keymap.set("n", chord, function()
      local node = tree:get_node()
      if node.type == "file" then
        opts.on_toggle(node.change)
      end
    end, { buffer = buf })
  end

  config.hooks.on_tree_mount({ buf = buf, tree = tree, opts = opts })

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

  local selected_file = file_tree_api.find_first_file_in_tree(file_tree)
  if selected_file then
    local _, selected_linenr = find_node_by_filepath(tree, selected_file.change.filepath)
    if selected_linenr then
      vim.api.nvim_win_set_cursor(opts.winid, { selected_linenr, 0 })
    end

    opts.on_preview(selected_file.change)
  end

  return Component
end

return M

local M = {}

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

function M.build_file_tree(changeset)
  local tree = { children = {} }
  for _, change in pairs(changeset) do
    insert_path(tree, change)
  end

  sort_tree(tree.children)

  return tree.children
end

function M.build_flat_file_tree(changeset)
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

function M.find_first_file_in_tree(tree)
  local child = tree[1]
  if not child then
    return
  end

  if child.children and #child.children > 0 then
    return M.find_first_file_in_tree(child.children)
  end

  return child
end

return M

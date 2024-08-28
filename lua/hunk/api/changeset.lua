local diff = require("hunk.api.diff")
local utils = require("hunk.utils")
local fs = require("hunk.api.fs")

local M = {}

local function merge_lists(a, b)
  local seen = {}

  local function add_unique(list)
    for _, item in ipairs(list) do
      if not seen[item] then
        seen[item] = true
      end
    end
  end

  add_unique(a)
  add_unique(b)

  return utils.get_keys(seen)
end

function M.load_changeset(left, right)
  local left_files = fs.list_files_recursively(left)
  local right_files = fs.list_files_recursively(right)
  local files = merge_lists(left_files, right_files)

  local changeset = {}

  for _, file in ipairs(files) do
    local has_left = utils.included_in_table(left_files, file)
    local has_right = utils.included_in_table(right_files, file)

    local type = "modified"
    if not has_left then
      type = "added"
    end
    if not has_right then
      type = "deleted"
    end

    local left_filepath = left .. "/" .. file
    local right_filepath = right .. "/" .. file

    changeset[file] = {
      type = type,

      left_filepath = left_filepath,
      right_filepath = right_filepath,
      filepath = file,

      selected = false,
      selected_lines = {
        left = {},
        right = {},
      },
      hunks = diff.diff_file(left_filepath, right_filepath),
    }
  end

  return changeset, files
end

local function write_change(change, output_dir)
  local any_selected = utils.any_lines_selected(change)
  local output_file = output_dir .. "/" .. change.filepath

  if change.type == "deleted" and not change.selected and not any_selected then
    fs.copy_file(change.left_filepath, output_file)
    return
  end

  if change.type == "deleted" and change.selected then
    fs.rm_file(output_file)
    return
  end

  if change.type == "added" and not change.selected and not any_selected then
    fs.rm_file(output_file)
    return
  end

  if change.selected and change.type ~= "deleted" then
    fs.copy_file(change.right_filepath, output_file)
    return
  end

  if any_selected then
    local left_file_content = fs.read_file_as_lines(change.left_filepath)
    local right_file_content = fs.read_file_as_lines(change.right_filepath)
    local result = diff.apply_diff(left_file_content, right_file_content, change)
    fs.write_file(output_dir .. "/" .. change.filepath, result)
    return
  end

  fs.copy_file(change.left_filepath, output_file)
end

function M.write_changeset(changeset, output_dir)
  vim.fn.mkdir(output_dir, "p")

  for _, change in pairs(changeset) do
    write_change(change, output_dir)
  end
end

return M

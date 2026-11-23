local diff = require("hunk.api.diff")
local utils = require("hunk.utils")
local fs = require("hunk.api.fs")

local M = {}

local function merge_lists(a, b)
  local seen = {}

  local function add_unique(list)
    for path in pairs(list) do
      if not seen[path] then
        seen[path] = true
      end
    end
  end

  add_unique(a)
  add_unique(b)

  return utils.get_keys(seen)
end

-- Absent sides are empty content so added and deleted files still diff. Nil
-- means no bytes were captured: the side is a symlink or could not be read.
local function read_contents(file, absent)
  if absent then
    return ""
  end

  if file.symlink then
    return nil
  end

  return fs.read_file(file.path)
end

function M.load_changeset(left, right)
  local left_files = fs.scan_dir(left)
  local right_files = fs.scan_dir(right)
  local files = merge_lists(left_files, right_files)

  local changeset = {}

  for _, file in ipairs(files) do
    local left_file = left_files[file]
    local right_file = right_files[file]

    local type = "modified"
    if not left_file then
      left_file = {}
      type = "added"
    end
    if not right_file then
      right_file = {}
      type = "deleted"
    end

    left_file.path = left .. "/" .. file
    right_file.path = right .. "/" .. file

    -- The bytes `hunks` and `selected_lines` are computed from. Accept reuses
    -- them instead of reading the paths again: the files may have changed
    -- since load, and rebuilding from newer bytes with older line numbers
    -- silently corrupts the output.
    local contents = {
      left = read_contents(left_file, type == "added"),
      right = read_contents(right_file, type == "deleted"),
    }

    changeset[file] = {
      type = type,

      left_file = left_file,
      right_file = right_file,
      filepath = file,

      contents = contents,

      selected = false,
      selected_lines = {
        left = {},
        right = {},
      },
      hunks = diff.diff_file(contents.left, contents.right),
    }
  end

  return changeset, files
end

-- Move the source when the disk still holds the snapshot, keeping file modes
-- and symlinks intact; otherwise write the snapshot. A source that is already
-- the destination is left alone so accept does not overwrite newer edits with
-- the load-time snapshot.
local function place_file(source_file, destination_path, content)
  local source_path = source_file.path

  if vim.fs.normalize(source_path) == vim.fs.normalize(destination_path) then
    return
  end

  if source_file.symlink then
    if fs.read_link(source_path) == source_file.symlink then
      fs.move_file(source_path, destination_path)
    else
      fs.write_symlink(destination_path, source_file.symlink)
    end
    return
  end

  if content == nil then
    -- The source could not be read at load time. Moving preserves its bytes
    -- instead of replacing it with an empty file.
    fs.move_file(source_path, destination_path)
    return
  end

  if fs.read_file(source_path) == content then
    fs.move_file(source_path, destination_path)
  else
    fs.write_bytes(destination_path, content)
  end
end

local function write_change(change, output_dir)
  local output_file = output_dir .. "/" .. change.filepath
  local any_selected = utils.any_lines_selected(change)

  if change.type == "deleted" and change.selected then
    fs.rm_file(output_file)
    return
  end

  if change.type == "added" and not change.selected and not any_selected then
    fs.rm_file(output_file)
    return
  end

  if change.selected then
    place_file(change.right_file, output_file, change.contents.right)
    return
  end

  if any_selected then
    local result = diff.apply_diff(fs.split_lines(change.contents.left), fs.split_lines(change.contents.right), change)
    fs.write_file(output_file, result)
    return
  end

  place_file(change.left_file, output_file, change.contents.left)
end

function M.write_changeset(changeset, output_dir)
  vim.fn.mkdir(output_dir, "p")

  for _, change in pairs(changeset) do
    write_change(change, output_dir)
  end
end

return M

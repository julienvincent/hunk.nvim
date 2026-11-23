local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")
local fs = require("hunk.api.fs")
local buffer = require("hunk.ui.buffer")
local file_ui = require("hunk.ui.file")

local M = {}

local pane_buffers = setmetatable({}, { __mode = "k" })

local function find_buffer_by_name(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == name then
      return buf
    end
  end
end

-- Right panes prefer the working-file name so LSP can attach. If that name is
-- already in use, both sides fall back to a hunk:// pane name so the comparison
-- never reuses someone else's buffer.
local function buffer_name(side, path)
  local preferred = side == "left" and "hunk://" .. path or path
  if not find_buffer_by_name(preferred) then
    return preferred
  end

  local index = 0
  local name
  repeat
    index = index + 1
    name = string.format("hunk://pane/%d/%s/%s", index, side, path)
  until not find_buffer_by_name(name)
  return name
end

local function snapshot_lines(change, side)
  local file = change[side .. "_file"]
  if file.symlink then
    return { file.symlink }
  end

  local content = change.contents[side]
  if content == nil then
    return {}
  end

  return fs.split_lines(content)
end

-- Unloaded buffers keep their handle but lose their text. Repopulate from the
-- snapshot before handing the pane back.
local function restore_buffer(buf, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("modified", false, { buf = buf })
end

local function create_buffer(params)
  local change = params.change
  local side = params.side
  local buffers = pane_buffers[change]
  if not buffers then
    buffers = {}
    pane_buffers[change] = buffers
  end

  local existing = buffers[side]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    if vim.api.nvim_buf_is_loaded(existing) then
      return existing
    end

    restore_buffer(existing, snapshot_lines(change, side))
    return existing
  end

  local path = vim.fs.normalize(vim.fn.getcwd() .. "/" .. change.filepath)
  local buf = buffer.create({
    name = buffer_name(side, path),
    lines = snapshot_lines(change, side),
    buftype = side == "left" and "nofile" or "nowrite",
  })
  buffers[side] = buf
  return buf
end

local function get_selected_lines()
  local start_line = vim.fn.getpos(".")[2]
  local end_line = vim.fn.getpos("v")[2]

  -- escape out of visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "m", false)

  local lines = {}
  for i = math.min(start_line, end_line), math.max(start_line, end_line) do
    table.insert(lines, i)
  end
  return lines
end

function M.set_window_highlights(win, side)
  local sign_highlight = side == "left" and "HunkSignDelete" or "HunkSignAdd"
  api.highlights.set_win_hl(win, {
    vim.api.nvim_get_option_value("winhl", { win = win }),
    "HunkSignSelected:" .. sign_highlight,
    "HunkSignDeselected:" .. sign_highlight,
  })
end

function M.create(window, params)
  local buf = create_buffer(params)
  local File = file_ui.create(window, {
    buf = buf,
    side = params.side,
    change = params.change,
    on_focus = params.on_focus,
    on_mount = function(File)
      local function map_opts(desc)
        return {
          buffer = buf,
          nowait = true,
          desc = desc,
        }
      end

      for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_line)) do
        vim.keymap.set("n", chord, function()
          local line = vim.api.nvim_win_get_cursor(window)[1]
          params.on_event({
            type = "toggle-lines",
            lines = { line },
            file = File,
          })
        end, map_opts("Toggle line under cursor"))

        vim.keymap.set("v", chord, function()
          local lines = get_selected_lines()
          vim.schedule(function()
            params.on_event({
              type = "toggle-lines",
              lines = lines,
              file = File,
            })
          end)
        end, map_opts("Toggle selected line(s)"))
      end

      for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_line_pair)) do
        vim.keymap.set("n", chord, function()
          local line = vim.api.nvim_win_get_cursor(window)[1]
          params.on_event({
            type = "toggle-lines",
            lines = { line },
            file = File,
            both_sides = true,
          })
        end, map_opts("Toggle line pair under cursor (left + right)"))

        vim.keymap.set("v", chord, function()
          local lines = get_selected_lines()
          vim.schedule(function()
            params.on_event({
              type = "toggle-lines",
              lines = lines,
              file = File,
              both_sides = true,
            })
          end)
        end, map_opts("Toggle selected line pair(s) (left + right)"))
      end

      for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_hunk)) do
        vim.keymap.set("n", chord, function()
          params.on_event({
            type = "toggle-hunk",
            line = vim.api.nvim_win_get_cursor(window)[1],
            file = File,
          })
        end, map_opts("Toggle entire hunk under cursor"))
      end
    end,
  })

  local function apply_signs()
    api.signs.clear_signs(buf)

    for _, hunk in ipairs(params.change.hunks) do
      for i in utils.hunk_lines(hunk[params.side]) do
        local is_selected = params.change.selected_lines[params.side][i]
        local sign
        if is_selected then
          sign = api.signs.signs.selected
        else
          sign = api.signs.signs.deselected
        end
        api.signs.place_sign(buf, sign, i)
      end
    end
  end

  function File.render()
    apply_signs()
  end

  apply_signs()

  return File
end

return M

local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")
local buffer = require("hunk.ui.buffer")
local file_ui = require("hunk.ui.file")

local M = {}

-- Editor buffers use working-file names for LSP integration and hunk:// names on the left.
local function create_buffer(params)
  local name = vim.fs.normalize(vim.fn.getcwd() .. "/" .. params.change.filepath)
  local buftype = "nowrite"
  if params.side == "left" then
    name = "hunk://" .. name
    buftype = "nofile"
  end
  return buffer.create({ name = name, file = params.change[params.side .. "_file"], buftype = buftype })
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

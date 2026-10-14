local config = require("hunk.config")
local utils = require("hunk.utils")

local M = {}

function M.create(window, params)
  vim.api.nvim_set_current_win(window)

  vim.cmd("diffoff")

  local buf = params.buf

  vim.api.nvim_buf_call(buf, function()
    vim.cmd("filetype detect")
    vim.cmd("doautocmd BufReadPost")
  end)

  vim.api.nvim_win_set_buf(window, buf)

  vim.cmd("diffthis")

  local File = {
    buf = buf,
    win = window,
    side = params.side,
    change = params.change,
  }

  local function map_opts(desc)
    return {
      buffer = buf,
      nowait = true,
      desc = desc,
    }
  end

  for _, chord in ipairs(utils.into_table(config.keys.diff.prev_hunk)) do
    vim.keymap.set("n", chord, function()
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor_pos[1]
      for i, _ in ipairs(params.change.hunks) do
        local hunk = params.change.hunks[#params.change.hunks - i + 1]
        if hunk[params.side][1] < line_num then
          local row = math.max(1, math.min(hunk[params.side][1], vim.api.nvim_buf_line_count(buf)))
          vim.api.nvim_win_set_cursor(0, { row, cursor_pos[2] })
          break
        end
      end
    end, map_opts("Go to prev hunk"))
  end

  for _, chord in ipairs(utils.into_table(config.keys.diff.next_hunk)) do
    vim.keymap.set("n", chord, function()
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor_pos[1]
      for _, hunk in ipairs(params.change.hunks) do
        if hunk[params.side][1] > line_num then
          local row = math.max(1, math.min(hunk[params.side][1], vim.api.nvim_buf_line_count(buf)))
          vim.api.nvim_win_set_cursor(0, { row, cursor_pos[2] })
          break
        end
      end
    end, map_opts("Go to next hunk"))
  end

  for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_focus)) do
    vim.keymap.set("n", chord, function()
      params.on_focus(params.side)
    end, map_opts("Toggle focused window between left/right"))
  end

  if params.on_mount then
    params.on_mount(File)
  end
  config.hooks.on_diff_mount({ buf = buf, win = window })

  return File
end

return M

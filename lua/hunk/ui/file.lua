local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")

local M = {}

function M.create(window, params)
  vim.api.nvim_set_current_win(window)
  vim.cmd("diffoff")
  vim.cmd("edit " .. params.change[params.side .. "_filepath"])
  vim.cmd("diffthis")

  local buf = vim.api.nvim_get_current_buf()

  local File = {
    buf = buf,
    win = window,
    side = params.side,
    change = params.change,
  }

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })

  vim.keymap.set("n", "<Plug>(hunk.diff.toggle_line)", function()
    local line = vim.api.nvim_win_get_cursor(window)[1]
    params.on_event({
      type = "toggle-lines",
      lines = { line },
      file = File,
    })
  end, { buffer = buf })

  vim.keymap.set("n", "<Plug>(hunk.diff.toggle_hunk)", function()
    params.on_event({
      type = "toggle-hunk",
      line = vim.api.nvim_win_get_cursor(window)[1],
      file = File,
    })
  end, { buffer = buf })

  vim.keymap.set("v", "<Plug>(hunk.diff.toggle_visual_lines)", function()
    local start_line = vim.fn.getpos("v")[2]
    local end_line = vim.fn.getpos(".")[2]

    local lines = {}
    for i = math.min(start_line, end_line), math.max(start_line, end_line) do
      table.insert(lines, i)
    end

    vim.schedule(function()
      params.on_event({
        type = "toggle-lines",
        lines = lines,
        file = File,
      })
    end)
  end, { buffer = buf, nowait = true })

  utils.set_keys(config.keys.diff, { window = window, params = params }, buf)

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

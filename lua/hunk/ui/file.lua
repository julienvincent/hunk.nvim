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

  vim.api.nvim_set_option_value("modifiable", false, {
    buf = buf,
  })
  vim.api.nvim_set_option_value("readonly", true, {
    buf = buf,
  })

  for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_line)) do
    vim.keymap.set("n", chord, function()
      local line = vim.api.nvim_win_get_cursor(window)[1]
      params.on_event({
        type = "toggle-lines",
        lines = { line },
        file = File,
      })
    end, { buffer = buf })
  end

  for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_hunk)) do
    vim.keymap.set("n", chord, function()
      params.on_event({
        type = "toggle-hunk",
        line = vim.api.nvim_win_get_cursor(window)[1],
        file = File,
      })
    end, { buffer = buf })

    vim.keymap.set("v", chord, function()
      vim.cmd("normal! <Esc>")

      local start_line = vim.fn.getpos("'<")[2]
      local end_line = vim.fn.getpos("'>")[2]

      local lines = {}
      for i = start_line, start_line + end_line do
        table.insert(lines, i)
      end

      params.on_event({
        type = "toggle-lines",
        lines = lines,
        file = File,
      })
    end, { buffer = buf })
  end

  local function apply_signs()
    for _, hunk in ipairs(params.change.hunks) do
      local local_hunk = hunk[params.side]
      for i = local_hunk[1], local_hunk[1] + local_hunk[2] - 1 do
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

local config = require("hunk.config")
local utils = require("hunk.utils")
local api = require("hunk.api")

local M = {}

local function get_buf_by_name(name)
  local bufs = vim.api.nvim_list_bufs()

  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_get_name(buf) == name then
      return buf
    end
  end
end

-- This function is used instead of the `:edit <filename>` builtin command so that we can
-- explicitly control the name of the buffer.
--
-- The right hand side buffer should inherit the name of the file at the cwd so that it
-- works correctly with things like lsp client initialization.
--
-- The left hand side should look similar with the exception of a hunk:// suffix and a
-- `nofile` buftype
local function create_buffer(params)
  local name = vim.fn.getcwd() .. "/" .. params.change.filepath

  local bufopts = {
    buftype = "nowrite",
    modifiable = false,
    modified = false,
    readonly = true,
  }

  if params.side == "left" then
    name = "hunk://" .. name
    bufopts.buftype = "nofile"
  end

  local buf = get_buf_by_name(name)
  if buf then
    return buf
  end

  buf = vim.api.nvim_create_buf(false, false)

  local lines = api.fs.read_file_as_lines(params.change[params.side .. "_filepath"])
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for key, value in pairs(bufopts) do
    vim.api.nvim_set_option_value(key, value, {
      buf = buf,
    })
  end

  vim.api.nvim_buf_set_name(buf, name)

  return buf
end

function M.create(window, params)
  vim.api.nvim_set_current_win(window)

  vim.cmd("diffoff")

  local buf = create_buffer(params)

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

  for _, chord in ipairs(utils.into_table(config.keys.diff.toggle_line)) do
    vim.keymap.set("n", chord, function()
      local line = vim.api.nvim_win_get_cursor(window)[1]
      params.on_event({
        type = "toggle-lines",
        lines = { line },
        file = File,
      })
    end, { buffer = buf })

    vim.keymap.set("v", chord, function()
      local start_line = vim.fn.getpos(".")[2]
      local end_line = vim.fn.getpos("v")[2]

      -- escape out of visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "m", false)

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
  end

  config.hooks.on_diff_mount({ buf = buf, win = window })

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

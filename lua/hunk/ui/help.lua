local config = require("hunk.config")
local utils = require("hunk.utils")

local event = require("nui.utils.autocmd").event
local NuiPopup = require("nui.popup")
local Text = require("nui.text")
local Line = require("nui.line")

local M = {}

local function render_commands(lines, commands)
  for name, chords in pairs(commands) do
    local line = Line({ Text(name, "HunkHelpCommandName"), Text(" = ") })
    for _, chord in pairs(utils.into_table(chords)) do
      line:append(chord)
    end
    table.insert(lines, line)
  end
end

function M.create(keys)
  keys = keys or config.keys
  local lines = {}

  table.insert(lines, Line({ Text("Global Commands", "HunkHelpTitle") }))
  table.insert(lines, Line())

  render_commands(lines, keys.global)

  table.insert(lines, Line())
  table.insert(lines, Line({ Text("Tree View Commands", "HunkHelpTitle") }))
  table.insert(lines, Line())

  render_commands(lines, keys.tree)

  table.insert(lines, Line())
  table.insert(lines, Line({ Text("Diff View Commands", "HunkHelpTitle") }))
  table.insert(lines, Line())

  render_commands(lines, keys.diff)

  local popup = NuiPopup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = "hunk.nvim help",
        top_align = "center",
      },
    },
    relative = "editor",
    position = {
      row = "2%",
      col = "2%",
    },
    size = {
      width = 40,
      height = #lines,
    },
  })

  popup:mount()

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  popup:map("n", "q", function()
    popup:unmount()
  end)

  vim.api.nvim_set_hl(0, "HunkHelpTitle", {
    default = true,
    link = "Title",
    bold = true,
  })

  vim.api.nvim_set_hl(0, "HunkHelpCommandName", {
    default = true,
    link = "Identifier",
    bold = true,
  })

  for i, line in ipairs(lines) do
    line:render(popup.bufnr, -1, i)
  end
end

return M

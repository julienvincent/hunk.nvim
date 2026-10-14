local root = vim.fn.getcwd()
vim.opt.runtimepath:append(root .. "/.build/dependencies/plenary.nvim")
vim.opt.runtimepath:append(root .. "/.build/dependencies/nui.nvim")
vim.opt.runtimepath:append(root)

vim.cmd.runtime({ "plugin/plenary.vim", bang = true })
vim.cmd.runtime({ "plugin/nui.nvim", bang = true })
vim.cmd.runtime({ "plugin/hunk.lua", bang = true })

vim.o.swapfile = false
vim.bo.swapfile = false

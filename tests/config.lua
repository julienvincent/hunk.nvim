vim.opt.runtimepath:append("./.build/dependencies/plenary.nvim")
vim.opt.runtimepath:append("./.build/dependencies/nui.nvim")
vim.opt.runtimepath:append(".")

vim.cmd.runtime({ "plugin/plenary.vim", bang = true })
vim.cmd.runtime({ "plugin/nui.nvim", bang = true })

vim.o.swapfile = false
vim.bo.swapfile = false

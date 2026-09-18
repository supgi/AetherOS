-- ==============================================================================
-- Aether OS - Neovim Minimal Configuration
-- Configuração moderna terminal-first para Neovim
-- ==============================================================================

-- Opções gerais do editor
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"

-- Tecla líder configurada para Espaço
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Atalhos rápidos úteis
local keymap = vim.keymap.set
keymap("n", "<leader>w", ":w<CR>", { desc = "Salvar arquivo" })
keymap("n", "<leader>q", ":q<CR>", { desc = "Fechar buffer/janela" })
keymap("n", "<Esc>", ":nohlsearch<CR>", { desc = "Limpar realce de busca" })

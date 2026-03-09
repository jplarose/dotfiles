local wk = require 'which-key'

local global_mappings = {
  { '<leader>w', '<cmd>w<CR>', desc = 'Write file' },
  { '<Esc>', '<cmd>nohlsearch<CR>', desc = 'Clear search highlight' },
  { '<C-h>', '<C-w><C-h>', desc = 'Move focus left' },
  { '<C-l>', '<C-w><C-l>', desc = 'Move focus right' },
  { '<C-j>', '<C-w><C-j>', desc = 'Move focus down' },
  { '<C-k>', '<C-w><C-k>', desc = 'Move focus up' },
  { '<leader>q', vim.diagnostic.setloclist, desc = 'Diagnostics loclist' },
  { 'J', 'mzJ`z', desc = 'Join lines and keep cursor' },
  { '<C-d>', '<C-d>zz', desc = 'Half page down and center' },
  { '<C-u>', '<C-u>zz', desc = 'Half page up and center' },
  { 'n', 'nzzzv', desc = 'Next result and center' },
  { 'N', 'Nzzzv', desc = 'Previous result and center' },
  { '<leader>e', '<cmd>Ex<CR>', desc = 'Go back to file tree' },
  { 'j', 'jzz', desc = 'Jump to line and center' },
}

wk.add(global_mappings)

local lsp_mappings = {
  { 'gd', vim.lsp.buf.definition, desc = 'Go to definition' },
  { 'K', vim.lsp.buf.hover, desc = 'Show hover information' },
  { '<leader>ln', vim.lsp.buf.rename, desc = 'Rename' },
  { '<leader>lr', vim.lsp.buf.references, desc = 'References' },
}

wk.add(lsp_mappings)

wk.add({
  { 'J', ":m '>+1<CR>gv=gv", desc = 'Move selection down' },
  { 'K', ":m '<-2<CR>gv=gv", desc = 'Move selection up' },
}, { mode = 'v' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('i', 'jj', '<Esc>', { desc = 'Exit insert mode' })

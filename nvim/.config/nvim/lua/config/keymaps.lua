local wk = require 'which-key'

local global_mappings = {
  { '<leader>w', '<cmd>w<CR>', desc = 'Write file' },
  { '<Esc>', '<cmd>nohlsearch<CR>', desc = 'Clear search highlight' },
  { '<C-h>', '<C-w><C-h>', desc = 'Move focus left' },
  { '<C-l>', '<C-w><C-l>', desc = 'Move focus right' },
  { '<C-j>', '<C-w><C-j>', desc = 'Move focus down' },
  { '<C-k>', '<C-w><C-k>', desc = 'Move focus up' },
  { '<Tab>', '<C-w>w', desc = 'Move to next window focus' },
  { 'J', 'mzJ`z', desc = 'Join lines and keep cursor' },
  { '<C-d>', '<C-d>zz', desc = 'Half page down and center' },
  { '<C-u>', '<C-u>zz', desc = 'Half page up and center' },
  { 'n', 'nzzzv', desc = 'Next result and center' },
  { 'N', 'Nzzzv', desc = 'Previous result and center' },
  { '<leader>q', '<cmd>q<CR>', desc = 'Go back to file tree' },
  { 'j', 'jzz', desc = 'Jump down to line and center' },
  { 'k', 'kzz', desc = 'Jump up to line and center' },
}

wk.add(global_mappings)

local lsp_mappings = {
  { 'gd', vim.lsp.buf.definition, desc = 'Go to definition' },
  { 'gr', vim.lsp.buf.references, desc = 'Go to Reference' },
  { 'gi', vim.lsp.buf.implementation, desc = 'Go to Implementation' },
  { 'gb', '<C-o>', desc = 'Go back through page history' },
  { '<leader>gh', vim.lsp.buf.hover, desc = 'Show hover information' },
  { '<leader>rn', vim.lsp.buf.rename, desc = 'Rename' },
}

wk.add(lsp_mappings)

local livePreview_mappings = {
  { '<leader>lpo', '<cmd>LivePreview start<CR>', desc = 'Start LivePreview on the current markdown document' },
  { '<leader>lpp', '<cmd>LivePreview pick<CR>', desc = 'Choose from the current file tree for a markdown file to preview' },
  { '<leader>lpl', '<cmd>LivePreview close<CR>', desc = 'Close the current LivePreview instance' },
}

wk.add(livePreview_mappings)

wk.add({
  { 'J', ":m '>+1<CR>gv=gv", desc = 'Move selection down' },
  { 'K', ":m '<-2<CR>gv=gv", desc = 'Move selection up' },
}, { mode = 'v' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('i', 'jj', '<Esc>', { desc = 'Exit insert mode' })

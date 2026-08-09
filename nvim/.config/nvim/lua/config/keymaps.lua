-- Local Functions

local function definition_in_vsplit()
  vim.cmd 'vsplit'
  vim.lsp.buf.definition()
end

-- Keymaps

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
  { '<S-h>', '<cmd>bprevious<CR>', desc = 'Previous Tab' },
  { '<S-l>', '<cmd>bnext<CR>', desc = 'Next Tab' },
  {
    '<leader>bd',
    function()
      local current = vim.api.nvim_get_current_buf()
      local others = vim.tbl_filter(function(buf)
        return buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
      end, vim.api.nvim_list_bufs())

      if #others > 0 then
        vim.api.nvim_set_current_buf(others[1])
      else
        vim.cmd 'enew'
      end

      vim.cmd.bdelete(current)
    end,
    desc = 'Close Tab',
  },
}

wk.add(global_mappings)

local lsp_mappings = {
  { 'gd', definition_in_vsplit, desc = 'Go to definition' },
  { 'gr', vim.lsp.buf.references, desc = 'Go to Reference' },
  { 'gi', vim.lsp.buf.implementation, desc = 'Go to Implementation' },
  { 'gb', '<C-o>', desc = 'Go back through page history' },
  { 'gh', vim.lsp.buf.hover, desc = 'Show hover information' },
  { 'gn', vim.lsp.buf.rename, desc = 'Rename' },
}

wk.add(lsp_mappings)

local livePreview_mappings = {
  { '<leader>lpo', '<cmd>LivePreview start<CR>', desc = 'Start LivePreview on the current markdown document' },
  { '<leader>lpp', '<cmd>LivePreview pick<CR>', desc = 'Choose from the current file tree for a markdown file to preview' },
  { '<leader>lpl', '<cmd>LivePreview close<CR>', desc = 'Close the current LivePreview instance' },
}

wk.add(livePreview_mappings)

local splitMappings = {
  { '<leader>v', '<cmd>vsplit<CR>', desc = 'Vertical Split' },
}

wk.add(splitMappings)

wk.add({
  { 'J', ":m '>+1<CR>gv=gv", desc = 'Move selection down' },
  { 'K', ":m '<-2<CR>gv=gv", desc = 'Move selection up' },
}, { mode = 'v' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('i', 'jj', '<Esc>', { desc = 'Exit insert mode' })

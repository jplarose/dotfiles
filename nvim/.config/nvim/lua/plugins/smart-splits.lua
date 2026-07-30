---@module "lazy"
---@type LazySpec
return {
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  opts = {},
  config = function(_, opts)
    local splits = require 'smart-splits'

    splits.setup(opts)

    -- Move between Neovim splits (and supported terminal panes).
    vim.keymap.set('n', '<C-h>', splits.move_cursor_left, { desc = 'Focus split left' })
    vim.keymap.set('n', '<C-j>', splits.move_cursor_down, { desc = 'Focus split below' })
    vim.keymap.set('n', '<C-k>', splits.move_cursor_up, { desc = 'Focus split above' })
    vim.keymap.set('n', '<C-l>', splits.move_cursor_right, { desc = 'Focus split right' })

    -- Resize the current split.
    vim.keymap.set('n', '<A-h>', splits.resize_left, { desc = 'Resize split left' })
    vim.keymap.set('n', '<A-j>', splits.resize_down, { desc = 'Resize split down' })
    vim.keymap.set('n', '<A-k>', splits.resize_up, { desc = 'Resize split up' })
    vim.keymap.set('n', '<A-l>', splits.resize_right, { desc = 'Resize split right' })
  end,
}

---@module "lazy"
---@type LazySpec

return {
  'romus204/referencer.nvim',
  config = function()
    require('referencer').setup {
      enable = true,
      format = '  %d ref',
      show_no_reference = true,
      kinds = { 5, 6, 8, 12, 13, 14, 23 },
      hl_group = 'Comment',
      color = '#a6a6a6',
      virt_text_pos = 'eol',
    }
  end,
}

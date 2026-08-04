---@type LazySpec
return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = 'nvim-tree/nvim-web-devicons',
  opts = {
    options = {
      mode = 'buffers',
      diagnostics = 'nvim_lsp',
      separator_style = 'slant',
      always_show_bufferline = true,
    },
  },
}

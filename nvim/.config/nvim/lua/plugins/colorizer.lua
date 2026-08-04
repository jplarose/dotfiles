---@module "lazy"
---@type LazySpec
return {
  'catgoose/nvim-colorizer.lua',
  event = 'BufReadPre',
  opts = {
    filetypes = { '*' },
    options = {
      parsers = {
        css = true,
        tailwind = { enable = true },
        sass = {
          enable = true,
          parsers = { css = true },
        },
      },
      display = {
        mode = 'background',
      },
    },
  },
}

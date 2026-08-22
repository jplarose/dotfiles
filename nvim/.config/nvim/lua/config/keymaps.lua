-- Local Functions

local function float_lsp_location(method, title)
  return function()
    local source_buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients {
      bufnr = source_buf,
      method = method,
    }
    local client = clients[1]

    if not client then
      vim.notify('No LSP client supports ' .. method .. ' for this buffer', vim.log.levels.WARN)
      return
    end

    local params = vim.lsp.util.make_position_params(nil, client.offset_encoding)
    client:request(method, params, function(err, result)
      vim.schedule(function()
        if err then
          vim.notify(err.message, vim.log.levels.ERROR)
          return
        end

        -- A language server may return several locations. This uses the first;
        -- `gr` remains available as a Telescope picker for choosing among results.
        local location = type(result) == 'table' and result[1] or result
        if not location then
          vim.notify('No location found', vim.log.levels.INFO)
          return
        end

        local uri = location.uri or location.targetUri
        local range = location.range or location.targetSelectionRange or location.targetRange
        if not uri or not range then
          vim.notify('The language server returned an invalid location', vim.log.levels.ERROR)
          return
        end

        local target_buf = vim.uri_to_bufnr(uri)
        vim.fn.bufload(target_buf)

        local width = math.floor(vim.o.columns * 0.85)
        local height = math.floor(vim.o.lines * 0.80)
        local win = vim.api.nvim_open_win(target_buf, true, {
          relative = 'editor',
          width = width,
          height = height,
          row = math.floor((vim.o.lines - height) / 2),
          col = math.floor((vim.o.columns - width) / 2),
          style = 'minimal',
          border = 'rounded',
          title = ' ' .. title .. ' ',
          title_pos = 'center',
        })

        vim.wo[win].number = true
        vim.wo[win].signcolumn = 'yes'
        vim.api.nvim_win_set_cursor(win, { range.start.line + 1, 0 })
      end)
    end, source_buf)
  end
end

local function float_to_tab()
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(win).relative == '' then
    vim.notify('This command only promotes a floating window', vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_close(win, true)
  vim.cmd 'tabnew'
  vim.api.nvim_win_set_buf(0, buf)
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
  { '<leader>q', '<cmd>q<CR>', desc = 'Close current window' },
  { '<leader>ft', float_to_tab, desc = 'Open floating buffer in new tab' },
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
  { 'gd', float_lsp_location('textDocument/definition', 'Definition'), desc = 'Open definition in float' },
  {
    'gr',
    function()
      require('telescope.builtin').lsp_references()
    end,
    desc = 'Find references',
  },
  { 'gi', float_lsp_location('textDocument/implementation', 'Implementation'), desc = 'Open implementation in float' },
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

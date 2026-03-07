local opt = vim.opt
local o = vim.o

-- Line numbers
o.number = true
o.relativenumber = true

-- Mouse support
o.mouse = 'a'

-- Don't show mode since statusline shows it
o.showmode = false

-- System clipboard
o.clipboard = 'unnamedplus'

-- Indentation / formatting
o.breakindent = true

-- Undo history
o.undofile = true

-- Searching
o.ignorecase = true
o.smartcase = true

-- Always show sign column
o.signcolumn = 'yes'

-- Faster update time
o.updatetime = 250

-- Keymap timeout
o.timeoutlen = 300

-- Split behavior
o.splitright = true
o.splitbelow = true

-- Whitespace characters
o.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Live substitution preview
o.inccommand = 'split'

-- Highlight current line
o.cursorline = true

-- Scroll padding
o.scrolloff = 10

-- Confirm before quitting unsaved buffers
o.confirm = true

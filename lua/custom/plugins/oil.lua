-- Keep file explorer customizations here so `kickstart/plugins/*` stays as upstream-style examples.
vim.pack.add { 'https://github.com/stevearc/oil.nvim' }

local oil = require 'oil'
local actions = require 'oil.actions'

local function is_oil_window(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.bo[bufnr].filetype == 'oil'
end

local function get_main_window()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_oil_window(winid) then return winid end
  end
end

local function resize_oil_windows()
  local width = math.max(24, math.floor(vim.o.columns * 0.35))

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_oil_window(winid) then
      vim.wo[winid].winfixwidth = true
      pcall(vim.api.nvim_win_set_width, winid, width)
    end
  end
end

local function yank_oil_dir()
  local dir = oil.get_current_dir()
  if not dir then return end

  vim.fn.setreg('+', dir)
  vim.fn.setreg('"', dir)
  vim.notify(('Yanked Oil path: %s'):format(dir))
end

local function select_in_main_pane()
  local entry = oil.get_cursor_entry()
  if not entry then return end
  if entry.type == 'directory' then
    actions.select.callback()
    return
  end
  local target_win = get_main_window()
  if not target_win then
    vim.cmd 'botright vsplit'
    target_win = vim.api.nvim_get_current_win()
  elseif vim.api.nvim_tabpage_list_wins(0)[2] == nil then
    vim.api.nvim_set_current_win(target_win)
    vim.cmd 'botright vsplit'
    target_win = vim.api.nvim_get_current_win()
  end
  actions.select.callback {
    close = false,
    handle_buffer_callback = function(bufnr)
      vim.api.nvim_set_current_win(target_win)
      vim.api.nvim_win_set_buf(target_win, bufnr)
      resize_oil_windows()
    end,
  }
end

local function toggle_oil_sidebar()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_oil_window(winid) then
      vim.api.nvim_set_current_win(winid)
      oil.close()
      return
    end
  end

  oil.open(nil, { vertical = true, split = 'topleft' }, function()
    resize_oil_windows()
  end)
end

function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir = oil.get_current_dir(bufnr)
  if not dir then return vim.api.nvim_buf_get_name(bufnr) end

  local display_dir = vim.fn.fnamemodify(dir, ':~'):gsub('%%', '%%%%')
  return ('%s'):format(display_dir)
end

vim.keymap.set('n', '\\', toggle_oil_sidebar, { desc = 'Toggle Oil sidebar', silent = true })

oil.setup {
  default_file_explorer = true,
  columns = {
    'icon',
    'permissions',
    'size',
    { 'mtime', format = '%d-%m-%Y %H:%M' },
  },
  win_options = {
    signcolumn = 'no',
    wrap = false,
    winbar = '%!v:lua.get_oil_winbar()',
  },
  view_options = {
    show_hidden = true,
    natural_order = true,
    sort = {
      { 'type', 'asc' },
      { 'name', 'asc' },
    },
  },
  keymaps = {
    ['<CR>'] = { callback = select_in_main_pane, desc = 'Open entry in main pane' },
    ['\\'] = { 'actions.close', mode = 'n' },
    ['q'] = { 'actions.close', mode = 'n' },
    ['yp'] = { callback = yank_oil_dir, desc = 'Yank current directory path' },
  },
}

vim.api.nvim_create_autocmd({ 'VimResized', 'WinNew' }, {
  group = vim.api.nvim_create_augroup('custom-oil-layout', { clear = true }),
  callback = resize_oil_windows,
})

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('custom-oil-buffer', { clear = true }),
  pattern = 'oil',
  callback = function(args)
    local winid = vim.fn.bufwinid(args.buf)
    if winid ~= -1 then vim.wo[winid].winfixwidth = true end
    resize_oil_windows()
  end,
})

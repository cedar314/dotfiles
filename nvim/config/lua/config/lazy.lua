local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
  vim.api.nvim_echo({ { "lazy.nvim is missing. Run the nvim setup module and approve optional bootstrap.", "WarningMsg" } }, true, {})
  return
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  -- Runtime state and generated lock updates must never write through to Git.
  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
  defaults = { lazy = false, version = false },
  install = { missing = false, colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})

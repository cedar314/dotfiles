return {
  -- Preserve manual :Mason access without background refresh/install on startup.
  {
    "mason-org/mason.nvim",
    build = false,
    opts = function(_, opts) opts.ensure_installed = {} end,
    config = function(_, opts) require("mason").setup(opts) end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts) opts.ensure_installed = {} end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- LazyVim checks mason per named server, rather than inheriting it from *.
      for name, server in pairs(opts.servers or {}) do
        if server == true then server = {}; opts.servers[name] = server end
        if type(server) == "table" then server.mason = false end
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = false,
    opts = function(_, opts)
      opts.ensure_installed = {}
      opts.auto_install = false
    end,
  },
}

return {
  {
    "gbprod/yanky.nvim",
    lazy = false,
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      highlight = {
        on_put = true,
        on_yank = true,
      },
      ring = {
        history_length = 100,
        storage = "shada",
      },
    },
    keys = {
      { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" } },
      { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" } },
      { "<C-y>", "<Plug>(YankyPutAfter)", mode = { "n", "x" } },
      { "<M-y>", "<Plug>(YankyCycleForward)", mode = { "n", "x" } },
      { "<M-S-y>", "<Plug>(YankyCycleBackward)", mode = { "n", "x" } },
      { "<leader>fy", "<cmd>Telescope yank_history<cr>", desc = "Yank history" },
    },
  },
}

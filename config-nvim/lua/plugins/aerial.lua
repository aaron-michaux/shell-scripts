return {
  {
    "stevearc/aerial.nvim",
    opts = {},
    keys = {
      {
        "<leader>o",
        function()
          require("aerial").toggle()
        end,
        desc = "Toggle Aerial",
      },
    },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
}

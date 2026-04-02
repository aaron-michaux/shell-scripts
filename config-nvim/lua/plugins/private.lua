return {
  {
    "moliva/private.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufWritePost" },
    config = function()
      require("private").setup({
        encryption_strategy = require("private.strategies.ccrypt"),
        setup_bindings = true,
      })
    end,
    keys = {
      {
        "<leader>iec",
        function()
          require("private.predef_actions").encrypt_current_file()
        end,
        desc = "Encrypt current file",
      },
      {
        "<leader>idc",
        function()
          require("private.predef_actions").decrypt_current_file()
        end,
        desc = "Decrypt current file",
      },
      {
        "<leader>iep",
        function()
          require("private.predef_actions").encrypt_path()
        end,
        desc = "Encrypt file by path",
      },
      {
        "<leader>idp",
        function()
          require("private.predef_actions").decrypt_path()
        end,
        desc = "Decrypt file by path",
      },
    },
  },
}

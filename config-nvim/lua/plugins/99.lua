return {
  {
    "ThePrimeagen/99",
    config = function()
      local _99 = require("99")
      _99.setup({
        tmp_dir = ".tmp", -- keep inside the project to avoid permission issues
      })

      vim.keymap.set("v", "<leader>9v", function()
        _99.visual()
      end, { desc = "99: prompt + replace selection" })

      vim.keymap.set("n", "<leader>9s", function()
        _99.search()
      end, { desc = "99: search" })

      vim.keymap.set("n", "<leader>9x", function()
        _99.stop_all_requests()
      end, { desc = "99: stop all requests" })
    end,
  },
}

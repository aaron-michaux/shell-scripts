return {
  {
    "Sarctiann/cursor-agent.nvim",
    dependencies =  { "folke/snacks.nvim" },
    opts = {
      -- widow_width = 80,
      -- open_mode = "normal", -- "normal" | "plain" | "auto-run"
    },
    keys = {
      -- default plugin suggests <leader>aj to open.
      { "<leader>aa", "<cmd>CursorAgent open_root<cr>", desc = "Cursor Agent (project root)"},
      { "<leader>ac", "<cmd>CursorAgent open_cwd<cr>", desc = "Cursor Agent (cwd)" },
      { "<leader>as", "<cmd>CursorAgent session_list<cr>", desc = "Cursor Agent sessions" },
    },
  },
}


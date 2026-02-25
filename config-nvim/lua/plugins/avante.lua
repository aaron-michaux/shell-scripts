return {
  "yetone/avante.nvim",
  enabled = (vim.fn.hostname() == "hermes"),
  event = "VeryLazy",
  opts = {
    provider = "ollama",

    providers = {
      ollama = {
        endpoint = "http://127.0.0.1:11434",
        model = "codellama:13b",
      },
    },

    -- openai = {
    --   endpoint = "https://api.openai/com/v1",
    --   model = "gpt-4o",
    --   api_key = os.getenv("OPEN_API_KEY"),
    -- },
    build = "make",
  },
}

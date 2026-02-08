return {
  "Tsuzat/NeoSolarized.nvim",
  config = function()
    require("NeoSolarized").setup({
      style = "light", -- "dark" or "light"
      transparent = false, -- true/false; Enable this to disable setting the background color
      -- Other configuration options can be found on the plugin's GitHub page
    })
    vim.cmd("colorscheme NeoSolarized")
  end,
}


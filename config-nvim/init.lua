-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.number = true
vim.opt.relativenumber = false

-- The "Snacks" dashboard
vim.keymap.set("n", "<leader>sh", function()
  Snacks.dashboard()
end, { desc = "Snacks Dashboard" })

-- Search behaviour
vim.opt.ignorecase = true
vim.opt.smartcase = true

------------------------------------------------- Trailing White Space
vim.opt.list = false
-- Define a custom highlight group for trailing whitespace
vim.api.nvim_set_hl(0, "TrailingWhitespace", { ctermbg = 88, bg = "IndianRed1" })

-- Use an autocmd to apply the highlighting whenever you enter a new window or buffer
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  callback = function()
    vim.schedule(function()
      -- Only apply to normal buffers (not quickfix, terminal, etc.)
      if vim.bo.buftype == "" then
        -- The regex /\\s\\+$/ matches one or more whitespace characters (\\s\\+) at the end of a line ($)
        vim.fn.matchadd("TrailingWhitespace", [[\s\+$]], 0)
      end
    end)
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("snacks_picker_preview") then
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
    end
  end,
})

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.number = true
vim.opt.relativenumber = false

<<<<<<< HEAD

-------------------------------------------------------------------------------------- Rename File (command)
local function rename_file()
  local buf = vim.api.nvim_get_current_buf()
  local old = vim.api.nvim_buf_get_name(buf)
  if old == nil or old == "" then
    vim.notify("This buffer has no filename (save it first).", vim.log.levels.WARN)
    return
  end

  local new = vim.fn.input("Rename to: ", old, "file")
  if new == nil or new == "" or new == old then
    return
  end

  vim.cmd("write")
  local ok, err = vim.loop.fs_rename(old, new)
  if not ok then
    vim.notify(("Rename filed: %s"):format(err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_name(buf, new)
  vim.cmd("edit " .. vim.fn.fnameescape(new))

  if vim.fn.bufexists("#") then
    pcall(vim.cmd, "bdelete #")
  end

  vim.notify(("Renamed:\n%s --> %s"):format(old, new), vim.log.levels.INFO)
end

vim.keymap.set("n", "<leader>R", rename_file, { desc = "Rename the current file" })
=======
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


>>>>>>> a1433c2 (added config-nvim)


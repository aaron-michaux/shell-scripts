-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
<<<<<<< HEAD
=======

vim.notify("Loaded config/keymaps.lua")

local F = require("config.functions")

-- Rename Current File
vim.keymap.set("n", "<leader>R", F.rename_file, { desc = "Rename the current file" })

-- FIND open buffers
vim.keymap.set("n", "<leader>m", function()
  require("telescope.builtin").buffers()
end, { desc = "Find open buffers" })

-------------------------------------------------------------- Emacsy Shortcuts
-- Remap increment/decrement under cursor
vim.keymap.set("n", "<leader>=", "<C-a>")
vim.keymap.set("n", "<leader>+", "<C-a>")
vim.keymap.set("n", "<leader>-", "<C-x>")

-- Comment/uncomment region

-- Start/end of line
vim.keymap.set("n", "<C-a>", "^")
vim.keymap.set("i", "<C-a>", "<C-o>^", { desc = "Beginning of line", silent = true })
vim.keymap.set("n", "<C-e>", "$")
vim.keymap.set("i", "<C-e>", "<End>", { desc = "End of line", silent = true })

vim.keymap.set({"n", "i"}, "<M-BS>", function()
  return vim.fn.mode() == "i" and "<C-o>db" or "db"
end, {expr = true, replace_keycodes = true, desc = "Delete word backwards"})

vim.keymap.set("n", "<M-Left>", "b")
vim.keymap.set("n", "<M-Right>", "w")
vim.keymap.set("n", "<M-Up>", "{")
vim.keymap.set("n", "<M-Down>", "}")
vim.keymap.set("i", "<M-Left>", "<C-o>db", { desc = "Delete word backwards", silent = true })
vim.keymap.set("i", "<M-Right>", "<C-o>dw", { desc = "Delete word forwards", silent = true })
vim.keymap.set("i", "<M-Up>", "<C-o>{", { desc = "Previous paragraph", silent = true })
vim.keymap.set("i", "<M-Down>", "<C-o>}", { desc = "Next paragraph", silent = true })

vim.keymap.set({"n", "i"}, "<C-Left>", function()
  return vim.fn.mode() == "i" and "<C-o>b" or "b"
end, {expr = true, replace_keycodes = true, desc = "Backwards one word"})
vim.keymap.set({"n", "i"}, "<C-Right>", function()
  return vim.fn.mode() == "i" and "<C-o>w" or "w"
end, {expr = true, replace_keycodes = true, desc = "Forwards one word"})
vim.keymap.set({"n", "i"}, "<C-Up>", function()
  return vim.fn.mode() == "i" and "<C-o>{" or "{"
end, {expr = true, replace_keycodes = true, desc = "Previous paragraph"})
vim.keymap.set({"n", "i"}, "<C-Down>", function()
  return vim.fn.mode() == "i" and "<C-o>}" or "}"
end, {expr = true, replace_keycodes = true, desc = "Next paragraph"})

----------------------------------------------------------------- Window Resize
vim.keymap.set({"n", "i"}, "<C-S-Left>", function()
  return vim.fn.mode() == "i" and "<C-o><C-w><" or "<C-w><"
end, {expr = true, replace_keycodes = true, desc = "Narrow window"})
vim.keymap.set({"n", "i"}, "<C-S-Right>", function()
  return vim.fn.mode() == "i" and "<C-o><C-w>>" or "<C-w>>"
end, {expr = true, replace_keycodes = true, desc = "Widen window"})
vim.keymap.set({"n", "i"}, "<C-S-Up>", function()
  return vim.fn.mode() == "i" and "<C-o><C-w>+" or "<C-w>+"
end, {expr = true, replace_keycodes = true, desc = "Heighten window"})
vim.keymap.set({"n", "i"}, "<C-S-Down>", function()
  return vim.fn.mode() == "i" and "<C-o><C-w>-" or "<C-w>-"
end, {expr = true, replace_keycodes = true, desc = "Shorten window"})

-- Kill to end of the line
--  Use "D" or <C-o>D

>>>>>>> a1433c2 (added config-nvim)

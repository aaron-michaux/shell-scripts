local M = {}

-------------------------------------------------------------------------------------- Rename File (command)
function M.rename_file()
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
  local ok, err = vim.uv.fs_rename(old, new)
  if not ok then
    vim.notify(("Rename filed: %s"):format(err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_name(buf, new)
  vim.cmd("edit " .. vim.fn.fnameescape(new))

  if vim.fn.bufexists("#") then
    pcall(function()
      vim.cmd("bdelete #")
    end)
  end

  vim.notify(("Renamed:\n%s --> %s"):format(old, new), vim.log.levels.INFO)
end

function M.transpose_chars()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  if col == #line then
    if col == 0 then
      return
    end
    col = col - 1
  end

  if #line < 2 or col >= #line then
    return
  end

  local chars = { line:byte(1, -1) }
  chars[col + 1], chars[col + 2] = chars[col + 2], chars[col + 1]

  vim.api.nvim_set_current_line(string.char(unpack(chars)))
  vim.api.nvim_win_set_cursor(0, { row, col + 1 })
end

return M

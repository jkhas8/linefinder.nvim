-- plugin/linefinder.lua
vim.api.nvim_create_user_command("LineFinder", function()
  require("linefinder").open()
end, { desc = "Open LineFinder to search lines in the current buffer" })

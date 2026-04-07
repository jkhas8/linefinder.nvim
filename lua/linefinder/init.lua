-- lua/linefinder/init.lua
local M = {}

function M.setup(opts)
  -- Reserved for future configuration
end

function M.open()
  require("linefinder.ui").open()
end

return M

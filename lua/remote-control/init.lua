local M = {}
local config = require("remote-control.config")

function M.setup(options)
	config.set_defaults(options)
end

return M

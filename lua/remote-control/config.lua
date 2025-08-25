local M = {}

local defaults = {
	--- Configure TidalLaunch command
	boot = {
		tidal = {
			--- Command to launch ghci with tidal installation
			oscEval = {
				ip = "127.0.0.1",
				port = 3333,
			},
			oscRemoteControl = {
				ip = "127.0.0.1",
				port = 3334,
			},
		},
	},
}

M.options = {}

function M.set_defaults(options)
	M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

return M

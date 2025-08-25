local losc = require("losc")
local plugin = require("losc.src.losc.plugins.udp-libuv")

local config = require("remote-control.config")

local M = {}

local function startOSC(host, port)
	local transport = plugin.new({ recvAddr = host, recvPort = port })
	local osc = losc.new({ plugin = transport })

	local function search_and_move(word)
		-- Get the current buffer number
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		local found = vim.fn.search(word)

		if found ~= 0 then
			vim.cmd("normal! zt")
			return true
		else
			return false
		end
	end

	osc:add_handler("/pulsar/eval", function(data)
		vim.schedule(function()
			local msg = data.message
			if msg[1] == "search" then
				search_and_move(msg[2])
			end
		end)
	end)

	print("Tidal OSC Init was called" .. "\n" .. host .. "\n" .. port)

	osc:open()
end

function M.start()
	local opts = config.options

	local oscEval = opts.boot.tidal.oscEval
	startOSC(oscEval.ip, oscEval.port)
end

return M

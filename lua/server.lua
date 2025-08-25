local losc = require("losc")
local plugin = require("losc.src.losc.plugins.udp-libuv")

local M = {}

function M.start()
	local host = "127.0.0.1"
	local port = 3333
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

return M

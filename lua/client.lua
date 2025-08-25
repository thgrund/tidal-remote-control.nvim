local M = {}

local losc = require("losc")
local plugin = require("losc.src.losc.plugins.udp-socket")

function M.startClient()
	local udp = plugin.new({ sendAddr = "localhost", sendPort = 57120 })
	local osc = losc.new({ plugin = udp })

	vim.keymap.set("n", "<leader>ts", function()
		local count = vim.v.count1 - 1 -- if no number given, defaults to 1
		vim.cmd("echo 'You passed " .. count .. "'")

		osc:send(losc.new_message({
			address = "/SuperDirtMixer/midiControlButton",
			types = "i",
			count,
		}))

		osc:send(losc.new_message({
			address = "/pulsar/remote-control/index",
			types = "i",
			count,
		}))
	end)
end

return M

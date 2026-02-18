local M = {}

local losc = require("losc")
local pluginSocket = require("losc.src.losc.plugins.udp-socket")
local pluginLibUv = require("losc.src.losc.plugins.udp-libuv")

local config = require("remote-control.config")

local ns = vim.api.nvim_create_namespace("statusbar")

local status_buf
local status_win_id
local bars_number_ext_mark_id
local total_number_of_bars
local json_file_name

M.activePos = nil
M.lastGlobalRotlPos = nil
M.resetGlobalRotl = function() end

local function updateSegments(n)
	local cur_win = vim.api.nvim_get_current_win()

	-- Switch to status window
	vim.api.nvim_set_current_win(status_win_id)

	-- move cursor to line start (like `0`)
	vim.api.nvim_win_set_cursor(status_win_id, { 1, 0 })

	local activePos = vim.fn.searchpos(" ", "cn", 1)
	local activeCol = activePos[2]

	if activeCol > 0 then
		vim.api.nvim_buf_set_text(status_buf, 0, activeCol - 1, 0, activeCol + 3, { " " })
	end
	-- forward search for nth occurrence of ":"
	local pos
	for _ = 1, n do
		pos = vim.fn.searchpos(" ", "cn", 1)
		vim.api.nvim_win_set_cursor(status_win_id, pos)
	end

	local row = 0
	local col = pos[2]

	-- replace character with ";"
	vim.api.nvim_buf_set_text(status_buf, row, col - 1, row, col + 3, { " " })
	M.activePos = n

	M.resetGlobalRotl()

	-- leave cursor at that position
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.api.nvim_set_current_win(cur_win)
end

local function updateCurrentBar(relativePos, startBar, endBar)
	local mark = vim.api.nvim_buf_get_extmark_by_id(status_buf, ns, bars_number_ext_mark_id, { details = true })
	local row, col, details = mark[1], mark[2], mark[3]
	-- local barContent = " " .. startBar .. "/" .. relativePos .. "/" .. endBar .. "/" .. totalNumberOfBars .. " "
	local barContent = " " .. relativePos .. "/" .. startBar .. "-" .. endBar .. " | " .. total_number_of_bars .. " "

	if details and details.end_col then
		vim.api.nvim_buf_set_text(status_buf, row, col, row, details.end_col, { barContent })

		vim.api.nvim_buf_set_extmark(status_buf, ns, row, col, {
			id = bars_number_ext_mark_id,
			end_col = col + #barContent,
			hl_group = "TLBarsNumber",
		})
	end
end

local function setStatus(artist, songName, barsNumber, total_count, hl_song_name, hl_bars_number, hl_checkbox)
	-- build full line text
	local line = " " .. artist .. "  " .. songName .. "  " .. barsNumber .. "  "

	-- add empty/filled markers
	for i = 1, total_count do
		line = line .. i .. ": " .. " "
	end

	line = line:gsub("%s+$", "")

	-- replace buffer line
	vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { line })

	-- clear previous highlights
	vim.api.nvim_buf_clear_namespace(status_buf, -1, 0, -1)

	-- highlight sections

	vim.api.nvim_set_hl(0, "TLArtistName", { bg = "#346beb", foreground = "#000000" })
	vim.api.nvim_set_hl(0, "TLSongName", { bg = "#987654", foreground = "#000000" })
	vim.api.nvim_set_hl(0, "TLBarsNumber", { bg = "#333333" })
	vim.api.nvim_set_hl(0, "TLCheckBox", hl_checkbox)

	vim.api.nvim_buf_set_extmark(status_buf, ns, 0, 0, {
		end_col = #artist + 2,
		hl_group = "TLArtistName",
	})
	vim.api.nvim_buf_set_extmark(status_buf, ns, 0, #artist + 2, {
		end_col = #artist + 4 + #songName,
		hl_group = "TLSongName",
	})
	bars_number_ext_mark_id = vim.api.nvim_buf_set_extmark(status_buf, ns, 0, #artist + 1 + #songName + 3, {
		end_col = #artist + 6 + #songName + #barsNumber,
		hl_group = "TLBarsNumber",
	})
	vim.api.nvim_buf_set_extmark(status_buf, ns, 0, #artist + 1 + #songName + 1 + #barsNumber + 2, {
		end_col = #line,
		hl_group = "TLCheckBox",
	})
end

local function startRemoteControlServer(host, port)
	local transport = pluginLibUv.new({ recvAddr = host, recvPort = port })
	local osc = losc.new({ plugin = transport })

	osc:add_handler("/pulsar/songMetadata", function(data)
		vim.schedule(function()
			local msg = data.message
			local title = msg[2]
			local size = msg[4]
			local color = msg[6]
			total_number_of_bars = msg[8]
			json_file_name = msg[10]

			if title and size and color then
				-- M.set_status("MrReason", title, size, { bg = color, foreground = "#000000" }, {
				-- 	fg = color,
				-- })
				setStatus("MrReason", title, "N/A", size, {}, {}, {})
			end
		end)
	end)

	osc:add_handler("/pulsar/button", function(data)
		vim.schedule(function()
			local msg = data.message
			local buttonIndex = msg[2]

			if buttonIndex then
				updateSegments(buttonIndex + 1)
			end
		end)
	end)

	osc:add_handler("/pulsar/currentBar", function(data)
		vim.schedule(function()
			local msg = data.message
			local relativePos = msg[2]
			local startBar = msg[4]
			local endBar = msg[6]

			if startBar and endBar then
				updateCurrentBar(relativePos, startBar, endBar)
			end
		end)
	end)

	osc:add_handler("/pulsar/pingSwitch", function()
		vim.schedule(function()
			vim.api.nvim_exec_autocmds("User", { pattern = "TidalSwitchCloseGate", modeline = false })
			vim.defer_fn(function()
				vim.api.nvim_exec_autocmds("User", { pattern = "TidalSwitchOpenGate", modeline = false })
			end, 150)
		end)
	end)

	osc:open()
end

local function startClient()
	local udp = pluginSocket.new({ sendAddr = "localhost", sendPort = 57120 })
	local osc = losc.new({ plugin = udp })

	vim.keymap.set("n", "<leader>tl", function()
		vim.ui.input({ prompt = "Enter loop range: " }, function(input)
			local loopStart
			local loopEnd

			if input ~= nil then
				local parts = {}
				for part in string.gmatch(input, "([^%-]+)") do
					table.insert(parts, part)
				end

				if parts[2] == nil then
					loopStart = parts[1] - 1
					loopEnd = parts[1]
				else
					loopStart = parts[1] - 1
					loopEnd = parts[2]
				end

				osc:send(losc.new_message({
					address = "/pulsar/loop-segments",
					types = "sii",
					json_file_name,
					loopStart,
					loopEnd,
				}))
			end
		end)
	end, { desc = "Loop song segments" })

	vim.keymap.set("n", "<leader>tp", function()
		local count = vim.v.count1 - 1 -- if no number given, defaults to 1

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

		vim.fn["repeat#set"](vim.api.nvim_replace_termcodes((count + 1) .. "<leader>tp", true, true, true), -1)
	end, { desc = "Send remote control index" })

	vim.keymap.set("n", "<leader>tR", function()
		local count = vim.v.count -- if no number given, defaults to 1

		M.lastGlobalRotlPos = M.activePos

		osc:send(losc.new_message({
			address = "/pulsar/global-rotl",
			types = "i",
			count,
		}))

		vim.fn["repeat#set"](vim.api.nvim_replace_termcodes(count .. "<leader>tR", true, true, true), -1)
	end, { desc = "Set global rotL value" })

	M.resetGlobalRotl = function()
		if M.lastGlobalRotlPos ~= nil and M.lastGlobalRotlPos ~= M.activePos then
			M.lastGlobalRotlPos = nil
			osc:send(losc.new_message({
				address = "/pulsar/global-rotl",
				types = "i",
				0,
			}))
		end
	end
end

local function createStatusBar()
	-- Create scratch buffer

	local bufnr = vim.api.nvim_create_buf(false, true)

	-- Save current window so we can return focus later
	local cur_win = vim.api.nvim_get_current_win()

	local win_id = vim.api.nvim_open_win(bufnr, false, {
		split = "below",
		win = -1,
		fixed = true,
	})

	-- Configure buffer options (scratch-like)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = true

	vim.api.nvim_win_set_height(win_id, 1)
	-- Configure window options
	vim.wo[win_id].winfixheight = true
	vim.wo[win_id].number = false
	vim.wo[win_id].relativenumber = false
	vim.wo[win_id].signcolumn = "no"
	vim.wo[win_id].cursorline = false
	vim.wo[win_id].statusline = ""
	vim.wo[win_id].winhl = "Normal:StatusLine"

	-- Return focus back to the original window
	vim.api.nvim_set_current_win(cur_win)

	status_buf = bufnr
	status_win_id = win_id
end

-- set_status(status_buf, "MrReason", "Crystal Cave", 8, { bg = "#9842f5", foreground = "#000000" }, {
-- 	bold = true,
-- 	fg = "#9842f5",
-- })
--
function M.create()
	createStatusBar()

	local opts = config.options
	local oscRemoteControl = opts.boot.tidal.oscRemoteControl
	startRemoteControlServer(oscRemoteControl.ip, oscRemoteControl.port)
	-- M.set_status("MrReason", "Wretched Automaton", 16, { bg = "#fcba03", foreground = "#000000" }, {
	-- 		bold = true,
	-- 		fg = "#fcba03",
	-- 	})

	-- M.set_status("MrReason", "Crystal Cave", 8, { bg = "#9842f5", foreground = "#000000" }, {
	-- 		bold = true,
	-- 		fg = "#9842f5",
	-- 	})
	--
	setStatus("MrReason", "N/A", "N/A", 1, {}, {}, {})
	startClient()
end

return M

local M = {}

local losc = require("losc")
local plugin = require("losc.src.losc.plugins.udp-libuv")

local tidalClient = require("client")

local status_buf
local status_win_id

function M.setup()
	M.osc = require("server").start()
	-- Could add more setup or convenience functions here
end

function M.marker()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'let my_event = "HELLO"' })
	vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = 5,
		col = 10,
		width = 40,
		height = 3,
		style = "minimal",
		border = "single",
	})
	-- 	vim.api.nvim_command(
	-- 	"highlight default HighlightLine guifg=#ff007c gui=bold ctermfg=198 background=#000000 ctermbg=darkgreen"
	-- )

	local ns = vim.api.nvim_create_namespace("virtual_border_example")
	local line_num = 0
	local line_text = vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)[1]

	vim.api.nvim_set_hl(0, "HighlightLine", { bg = "#F09FE5", bold = true, fg = "#000000" })

	for s, _, e in line_text:gmatch('()"(.-)"()') do
		local colStart = tonumber(s)
		local colEnd = tonumber(e)
		-- Highlight the text with a background color
		vim.api.nvim_buf_set_extmark(buf, ns, line_num, colStart - 1, {
			end_col = colEnd - 1,
			hl_group = "HighlightLine",
		})
		-- Optional: add left and right side markers using virtual text
	end
end

local function startOscServer()
	local host = "127.0.0.1"
	local port = 3334
	local transport = plugin.new({ recvAddr = host, recvPort = port })
	local osc = losc.new({ plugin = transport })

	osc:add_handler("/pulsar/songMetadata", function(data)
		vim.schedule(function()
			local msg = data.message
			local title = msg[2]
			local size = msg[4]
			local color = msg[6]

			if title and size and color then
				-- M.set_status("MrReason", title, size, { bg = color, foreground = "#000000" }, {
				-- 	fg = color,
				-- })
				M.setStatus("MrReason", title, size, {}, {})
			end
		end)
	end)

	osc:add_handler("/pulsar/button", function(data)
		vim.schedule(function()
			local msg = data.message
			local buttonIndex = msg[2]

			if buttonIndex then
				M.updateStatusBar(buttonIndex + 1)
			end
		end)
	end)

	print("MrReason Song Metadata \nOSC Server Init was called" .. "\n" .. host .. "\n" .. port)

	osc:open()
end

function M.createStatusBar()
	-- Create scratch buffer
	local bufnr = vim.api.nvim_create_buf(false, true)

	-- Save current window so we can return focus later
	local cur_win = vim.api.nvim_get_current_win()

	-- Do a split inside the current window
	vim.cmd("left")
	vim.cmd("belowright split")
	vim.cmd("resize 1")

	local win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win_id, bufnr)

	-- Configure buffer options (scratch-like)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = true

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

function M.setStatus(left, middle, total_count, hl_song_name, hl_checkbox)
	-- build full line text
	local line = " " .. left .. "  " .. middle .. "  "

	-- add empty/filled markers
	for i = 1, total_count do
		line = line .. i .. ":" .. "  "
	end

	-- replace buffer line
	vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { line })

	-- clear previous highlights
	vim.api.nvim_buf_clear_namespace(status_buf, -1, 0, -1)

	-- highlight sections
	local ns = vim.api.nvim_create_namespace("statusbar")

	vim.api.nvim_set_hl(0, "TLArtistName", { bg = "#346beb", foreground = "#000000" })
	vim.api.nvim_set_hl(0, "TLSongName", hl_song_name)
	vim.api.nvim_set_hl(0, "TLCheckBox", hl_checkbox)

	vim.api.nvim_buf_set_extmark(status_buf, ns, 0, 0, {
		end_col = #left + 2,
		hl_group = "TLArtistName",
	})
	vim.api.nvim_buf_set_extmark(status_buf, ns, 0, #left + 2, {
		end_col = #left + 4 + #middle,
		hl_group = "TLSongName",
	})
	vim.api.nvim_buf_set_extmark(status_buf, ns, 0, #left + 1 + #middle + 1 + 2, {
		end_col = #line, -- until EOL
		hl_group = "TLCheckBox",
	})
end

-- set_status(status_buf, "MrReason", "Crystal Cave", 8, { bg = "#9842f5", foreground = "#000000" }, {
-- 	bold = true,
-- 	fg = "#9842f5",
-- })

function M.status()
	M.createStatusBar()

	-- M.set_status("MrReason", "Wretched Automaton", 16, { bg = "#fcba03", foreground = "#000000" }, {
	-- 		bold = true,
	-- 		fg = "#fcba03",
	-- 	})

	-- M.set_status("MrReason", "Crystal Cave", 8, { bg = "#9842f5", foreground = "#000000" }, {
	-- 		bold = true,
	-- 		fg = "#9842f5",
	-- 	})
	--
	M.setStatus("MrReason", "Crystal Cave", 16, {}, {})
	startOscServer()
	tidalClient.startClient()
end

function M.updateStatusBar(n)
	local cur_win = vim.api.nvim_get_current_win()

	-- Switch to status window
	vim.api.nvim_set_current_win(status_win_id)

	-- move cursor to line start (like `0`)
	vim.api.nvim_win_set_cursor(status_win_id, { 1, 0 })

	local activePos = vim.fn.searchpos("󰄮", "cn", 1)
	local activeCol = activePos[2]

	if activeCol > 0 then
		vim.api.nvim_buf_set_text(status_buf, 0, activeCol - 1, 0, activeCol + 3, { "" })
	end
	-- forward search for nth occurrence of ":"
	local pos
	for _ = 1, n do
		pos = vim.fn.searchpos("", "cn", 1)
		vim.api.nvim_win_set_cursor(status_win_id, pos)
	end

	local row = 0
	local col = pos[2]

	-- replace character with ";"
	vim.api.nvim_buf_set_text(status_buf, row, col - 1, row, col + 2, { "󰄮" })

	-- leave cursor at that position
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.api.nvim_set_current_win(cur_win)
end

return M

concommand.Add("noclipov_load", function()
	local files = {"editor.lua", "logs.lua", "misc.lua"}
	local function load_file(path, filename, create)
		create = create or false
		if !file.IsDir("noclipov", "DATA") then return end
		if not file.Exists(path, "DATA") or create then
			http.Fetch("https://raw.githubusercontent.com/noclipov/gmod-luas/refs/heads/main/"..filename, function(body)
				file.Write(path:gsub(".lua", ".txt"), body)
			end, function(err) print(err) end)
		end
		RunString(file.Read(path:gsub(".lua", ".txt"), "DATA"))
	end
	local function check_files(create)
		create = create or false
		if not file.IsDir("noclipov", "DATA") then file.CreateDir("noclipov", "DATA") end
		for _, filename in pairs(files) do
			local path ="noclipov/"..filename
			load_file(path, filename, create)
		end
	end
	check_files(true)

	commands = {
		noclipov_reload = function() check_files(true) end,
		noclipov_loadfile = function(ply, cmd, args) if #args == 1 then load_file("noclipov/"..args[1], args[1]) end end
	}
	for cmd,callback in pairs(commands) do
		concommand.Remove(cmd)
		concommand.Add(cmd, callback)
	end
	print("[Main] Loaded!\nAvailable commands are: update_files, load_file")
	concommand.Remove("noclipov_load")
end)

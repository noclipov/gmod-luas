http.Fetch("https://raw.githubusercontent.com/noclipov/gmod-luas/refs/heads/main/main.lua", function(body) RunString(body) end, 
function(err) print(err) end)
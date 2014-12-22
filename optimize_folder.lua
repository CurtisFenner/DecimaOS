
local directory = arg[1];

for file in io.popen('dir "' .. directory .. '" /b'):lines() do
	print(file)
	os.execute("lua alopt.lua " .. directory .. "/" .. file .. " " .. directory .. "/../asm_optimized/" .. file);
end

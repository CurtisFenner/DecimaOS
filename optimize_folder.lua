
local directory = arg[1];
local newdir = arg[2] or (directory .. "_optimized");
print("Optimizing", directory, "-->", newdir);
for file in io.popen('dir "' .. directory .. '" /b'):lines() do
	print("", file);
	os.execute("lua alopt.lua " .. directory .. "/" .. file .. " " .. directory .. "/../" .. newdir .. "/" .. file);
end

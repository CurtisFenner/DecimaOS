

local data = "";

for i = 1,#arg-1 do
	local cmd = arg[i];
	local file = io.open(cmd,"rb");
	data = data .. file:read("*all");
	file:close();
end

local cmd = arg[#arg];
local file = io.open(cmd, "wb");
file:write( data );
file:close();




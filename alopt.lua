function readFile(fname)
	local lines = {};
	for line in io.lines(fname) do
		table.insert(lines, line);
	end
	return lines;
end

--------------------------------------------------------------------------------

local iotable = {};

iotable.mov_2 = {ins = {"#2"}, outs = {"#1"}};
iotable.add_2 = {ins = {"#1", "#2"}, outs = {"#1"}};
iotable.imul_2 = {ins = {"#1", "#2"}, outs = {"#1"}};
iotable.push_2 = {ins = {"esp", "#1"}, outs = {"esp", "[mem]"}};
iotable.pop_1 = {ins = {"esp", "[mem]"}, outs = {"esp", "#1"}};

local optimized = {};
optimized.mov = true;
optimized.add = true;
optimized.push = true;
optimized.pop = true;
optimized.imul = true;

--------------------------------------------------------------------------------

function stripComment(line)
	local quoted = false;
	local escaped = false;
	for i = 1, #line do
		if escaped then
			escaped = false;
		else
			local c = line:sub(i, i);
			if quoted then
				if c == quoted then
					quoted = false;
				elseif c == "\\" and quoted == "`" then
					escaped = true;
				end
			elseif c == "`" or c == '"' or c == "'" then
				quoted = c;
			elseif c == ";" then
				return line:sub(1, i - 1), line:sub(i + 1);
			end
		end
	end
	return line, "";
end


function parseInstruction(line)
	line = trimFront(line);
	if line == "" then
		return nil;
	end
	local name, line = parseWord(line);
	if not name then
		return nil;
	end
	if not optimized[name:lower()] then
		return nil;
	end
	name = name:lower();
	if atEnd(line) then
		return {name = name, args = {}};
	end
	local arg1, line = parseArg(line);
	if atEnd(line) then
		return {name = name, args = {arg1}};
	end
	line = parseComma(line);
	local arg2, line = parseArg(line);
	if atEnd(line) then
		return {name = name, args = {arg1, arg2}};
	end
	print("Three parameters?");
end

function trimFront(line)
	return line:sub(  line:find("%S") or 1  );
end

function atEnd(s)
	return not s or trimFront(s) == "";
end

function parseComma(s)
	s = trimFront(s);
	if s:sub(1, 1) ~= "," then
		print("parseComma got ", s);
	end
	return s:sub(2);
end

function parseWord(s)
	if not s then
		return nil;
	end
	s = trimFront(s);
	if s:sub(1, 1):find("%A") then
		return nil;
	end
	local after = s:find("%A") or (#s+1);
	return s:sub(1, after - 1), s:sub(after);
end

function parseArg(s)
	s = trimFront(s) .. ",";
	if #s < 2 then
		return nil;
	end
	local quoted = false;
	local escaped = false;
	for i = 1, #s do
		local c = s:sub(i, i);
		if escaped then
			escaped = false;
		else
			if quoted then
				if quoted == c or (quoted == "[" and c == "]") then
					quoted = false;
				end
			else
				if c == "`" or c == "'" or c == '"' or c == "[" then
					quoted = c;
				else
					if c == "," then
						return s:sub(1, i - 1), s:sub(i, - 2);
						-- Done.
					end
				end
			end
		end
	end
	-- word eax
	-- memory [eax]
	-- literal "ab" 'ab' `\n\`` 0xff 35
end

function contains(a, el)
	for i, v in pairs(a) do
		if v == el then
			return i;
		end
	end
end

function intersects(a, b)
	for i = 1, #a do
		if contains(b, a[i]) then
			return true;
		end
	end
	return false;
end


function interchangeDependence(a, b)
	return intersects(dependencies(a), outputs(b))
		or intersects(outputs(a), dependencies(b));
end

function dependencies(inst)
	local name = inst.name .. "_" .. #inst.args;
	-- iotable (see after)
	local ins, outs = {}, {};
	if not iotable[name] then
		return;
	end
	local code = iotable[name];
	for i = 1, #code.ins do
		if code.ins[i] == "#1" then
			addArg(ins, inst.args[1]);
		elseif code.ins[i] == "#2" then
			addArg(ins, inst.args[2]);
		else
			table.insert(ins, code.ins[i]);
		end
	end
	--
	for i = 1, #code.outs do
		if code.outs[i] == "#1" then
			addArg(outs, inst.args[1]);
		elseif code.outs[i] == "#2" then
			addArg(outs, inst.args[2]);
		else
			table.insert(outs, code.outs[i]);
		end
	end
	-- Same for out
	return ins, outs
end

local INV = "???";

function addArg(ins, arg)
	if arg:sub(1, 1) == "[" then
		table.insert(ins, "[mem]");
		return addArg(ins, arg:sub(2, -2));
	elseif arg:sub(1, 1):lower() == arg:sub(1,1):upper() then
		return; -- a constant
	elseif arg == parseWord(arg) then
		table.insert(ins, arg);
	else
		print("???"); -- Hex?
		table.insert(ins, INV);
	end
end

function registerExtension(a)
	local extension = {};
	for i = 1, #a do
		local r = a[i];
		if #r == 2 then
			local ra, rb = r:sub(1, 1), r:sub(2, 2);
			if rb == "x" then
				table.insert(extension, ra .. "l");
				table.insert(extension, ra .. "h");
				table.insert(extension, "e" .. ra .. "x");
			elseif rb == "l" then
				table.insert(extension, ra .. "x");
				table.insert(extension, "e" .. ra .. "x");
			elseif rb == "h" then
				table.insert(extension, ra .. "x");
				table.insert(extension, "e" .. ra .. "x");
			end
		elseif #r == 3 then
			local ra, rb, rc = r:sub(1, 1), r:sub(2, 2), r:sub(3, 3);
			if ra == "e" and rc == "x" then
				table.insert(extension, rb .. "l");
				table.insert(extension, rb .. "h");
				table.insert(extension, rb .. "x");
			end
		else
			-- print("Strange register", r);
			table.insert(extension, INV);
		end
	end
	for i = 1, #extension do
		table.insert(a, extension[i]);
	end
end

function conflicts(a, b)
	local ain, aout = dependencies(a);
	local bin, bout = dependencies(b);
	if (not ain) or (not bin) then
		return true;
	end
	if contains(ain, INV) or contains(aout, INV)
		or contains(bin, INV) or contains(bout, INV) then
		return true;
	end
	registerExtension(ain);
	registerExtension(aout);
	registerExtension(bin);
	registerExtension(bout);
	return intersects(ain, bout) or intersects(bin, aout);
end

function registerNameBreak(r)
	local center = math.ceil(#r / 2);
	local main = r:sub(center, center);
	local sub = r:sub(1, center - 1) .. r:sub(center + 1);
	return main, sub;
end

function registerNameComparison(a, b)
	local amain, asub = registerNameBreak(a);
	local bmain, bsub = registerNameBreak(b);
	if amain == bmain then
		return asub <= bsub;
	else
		return amain <= bmain;
	end
end


function shouldSwap(a, b)
	if conflicts(a, b) then
		return false;
	end
	local rank = {};
	rank.mov = 3;
	rank.push = 1;
	rank.pop = 2;
	rank.imul = 5;
	rank.iadd = 4;
	if a.args[1] ~= b.args[1] and a.args[1] and b.args[1] then
		local r = not registerNameComparison(a.args[1], b.args[1]);
		return r;
	end
	if rank[a.name] ~= rank[b.name] then
		return (rank[a.name] or 100) > (rank[b.name] or 100);
	end
	if a.args[2] and a.args[2] then
		return not registerNameComparison(a.args[2], b.args[2]);
	end
end


function reorderInstructions(instructions)
	-- Bubblesort
	local changed = false;
	for iter = 1, #instructions - 1 do
		for j = 1, #instructions - 1 do
			local a = instructions[j];
			local b = instructions[j + 1];
			if shouldSwap(a, b) then
				instructions[j] = b;
				instructions[j + 1] = a;
				changed = true;
			end
		end
	end
	return changed;
end

--------------------------------------------------------------------------------

function parseLines(file)
	local instructions = {};
	for i = 1, #file do
		local line, comment = file[i];
		line, comment = stripComment(line);
		if line:gsub("%s", "") ~= "" then
			local instruction = parseInstruction(line);
			if instruction then
				table.insert(instructions, parseInstruction(line));
			else
				table.insert(instructions, {name = line, args = {}});
			end
			local top = instructions[#instructions];
			top.comment = (top.comment or "") .. comment;
		end
	end
	return instructions;
end


function stringInstructions(instructions)
	local result = {};
	for i = 1, #instructions do
		local msg = instructions[i].name
			.. " " .. table.concat(instructions[i].args, ", ");
		if #instructions[i].comment > 1 then
			msg = msg .. "; " .. instructions[i].comment;
		end
		table.insert(result, msg);
	end
	return result;
end


--------------------------------------------------------------------------------

local peepRules = {
	{
		name = "push pop",
		from = { {"push", "$A"}, {"pop", "$B"} },
		to = { {"mov", "$B", "$A"} },
		exceptions = { ["$A"] = {"esp"}, ["$B"] = {"esp"}}
	},
	{
		name = "mov self",
		from = { {"mov", "$A", "$A"} },
		to = {}
	},
	{
		name = "add 0",
		from = {{"add", "$A", "0"}},
		to = {}
	},
	{
		name = "imul 1",
		from = {{"imul", "$A", "1"}},
		to = {}
	},
	{
		name = "clobber mov",
		from = {{"mov", "$A", "$B"}, {"mov", "$A", "$C"}},
		to = {{"mov", "$A", "$C"}}
	},
	{
		name = "double return",
		from = {{"ret"}, {"ret"}},
		to = {{"ret"}}
	},
	{
		name = "double jump",
		from = {{"jmp", "$A"}, {"jmp", "$B"}},
		to = {{"jmp", "$A"}}
	},
	{
		name = "mov pop",
		from = {{"mov", "$A", "$B"}, {"pop", "$A"}},
		to = {{"pop", "$A"}},
		exceptions = {["$A"] = {"esp"}, ["$B"] = {"esp"}}
	},
	{
		name = "literal add inline",
		from = {{"mov", "$A", "#N"}, {"add", "$B", "$A"}},
		to = {{"mov", "$A", "#N"}, {"add", "$B", "#N"}}
	},
	{
		name = "literal imul inline",
		from = {{"mov", "$A", "#N"}, {"imul", "$B", "$A"}},
		to = {{"mov", "$A", "#N"}, {"imul", "$B", "#N"}}
	},
	{
		name = "add two literals",
		from = {{"add", "$E", "#A"}, {"add", "$E", "#B"}},
		to = function(vars)
			return {{ "add", vars["$E"], vars["#A"] .. " + " .. vars["#B"] }};
		end
	},
	{
		name = "clobbered by mov",
		from = {{"mov", "$A", "$B"}, {"push","$A"}, {"mov", "$A", "$C"}},
		to = {{"push", "$B"}, {"mov", "$A", "$C"}},
		exceptions = {["$A"] = {"esp"}, ["$B"] = {"esp"}, ["$C"] = {"esp"}}
	}
	--{ -- Undeclared size errors
	--	name = "clobbered by pop",
	--	from = {{"mov", "$A", "$B"}, {"push","$A"}, {"pop", "$A"}},
	--	to = {{"push", "$B"}, {"pop", "$A"}},
	--	exceptions = {["$A"] = {"esp"}, ["$B"] = {"esp"}}
	--}
};
--[[
mov eax, ecx
mov ebx, eax

mov eax, ecx
mov ebx, ecx
]]

function testRule(instructions, index, rule)
	local len = #rule.from;
	local vars = {};
	if index + len - 1 > #instructions then
		-- Rule is longer than list.
		return false;
	end
	for i = 1, len do
		local instruction = instructions[i + index - 1];
		if #instruction.args + 1 ~= #rule.from[i] then
			return false;
		end
		if instruction.name:lower() ~= rule.from[i][1]:lower() then
			return false;
		end
		for j = 1, #instruction.args do
			local arg = instruction.args[j];
			local compare = rule.from[i][j + 1];
			if compare:sub(1, 1) == "$" then
				if not vars[compare] then
					vars[compare] = arg;
					if rule.exceptions and rule.exceptions[compare]
						and contains(rule.exceptions[compare], arg:lower()) then
						return false;
					end
				else
					if vars[compare] ~= arg then
						return false;
					end
				end
			elseif compare:sub(1, 1) == "#" then
				if not tonumber(arg:sub(1, 1)) then
					return false;
				end
				if not vars[compare] then
					vars[compare] = arg;
				else
					if vars[compare] ~= arg then
						return false;
					end
				end
			else
				if compare ~= arg then
					return false;
				end
			end
		end
	end
	return vars;
end

-- attemptRule(instructions, rule)
function attemptRule(instructions, rule, index)
	if not index then
		local substituted = false;
		for i = #instructions, 1, -1 do
			substituted = attemptRule(instructions, rule, i) or substituted;
		end
		return substituted;
	end
	--
	local vars = testRule( instructions, index, rule );
	if vars then
		for j = 1, #rule.from do
			local ik = table.remove(instructions, index);
			if rule.name:find("clobbered") then
				print(ik.name, unpack(ik.args)); -- TODO
				--error("CHECK WHY CLOBBERED DOESNT WORK");
			end
		end
		if rule.name:find("clobbered") then
			print(" ");
		end
		if type(rule.to) == "function" then
			local insert = rule.to(vars);
			for j = 1, #insert do
				local ins = insert[j];
				local op = table.remove(ins, 1);
				table.insert(instructions, index, {name = op, args = ins, comment = "optimize " .. rule.name} );
			end
		else
			for j = 1, #rule.to do
				local instruction = {};
				local to = rule.to[j];
				instruction.name = to[1];
				instruction.args = {};
				instruction.comment = "optimize " .. rule.name;
				for k = 2, #to do
					table.insert(instruction.args, vars[to[k]] or to[k]);
				end
				table.insert(instructions, index, instruction);
			end
		end
		return true;
	end
	return false;
end

function optimize(instructions)
	local loop = 0;
	repeat
		loop = loop + 1;
		local changed = false;
		for _, rule in ipairs(peepRules) do
			changed = attemptRule(instructions, rule) or changed;
		end
		-- changed = reorderInstructions(instructions) or changed;
		print("Loop " .. loop);
	until (not changed) or loop > 20
end


--------------------------------------------------------------------------------

-- Tests

local file = readFile("kernel.c.asm");
--file = {"push 1", "push eax", "pop eax", "pop ecx"};

local instructions = parseLines(file);
optimize(instructions);

local result = stringInstructions( instructions );

local f = io.open("kernelopt.asm", "w");
for i = 1, #result do
	f:write(result[i] .. "\n");
end

--[[
-- Side by side comparison
local wid = 30;
for i = 1, #file do
	local left = file[i];
	if #left > wid - 3 then
		left = left:sub(1, wid - 3) .. "...";
	end
	left = left .. (" "):rep(wid - #left) .. "    | ";
	print(left .. (result[i] or ""));
	f:write(left .. (result[i] or "") .. "\n");
end
]]

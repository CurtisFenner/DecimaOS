function readFile(fname)
	local lines = {};
	for line in io.lines(fname) do
		table.insert(lines, line);
	end
	return lines;
end

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
	return line;
end


function parseInstruction(line)
	local name, line = parseWord(line);
	if atEnd(line) then
		return {name = name, args = {}};
	end
	local arg1, line = parseArg(line);
	if atEnd(line) then
		return {name = name, args = {arg1}};
	end
	print("arg1", arg1, line);
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
	local after = s:find("%A") or 0;
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
	-- data (see after)
	local ins, outs = {}, {};
	if not data[name] then
		return;
	end
	local code = data[name];
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
				table.insert(extension, ra .. "l");
				table.insert(extension, ra .. "h");
				table.insert(extension, ra .. "x");
			end
		else
			print("Strange register", r);
		end
	end
	for i = 1, #extension do
		table.insert(extension[i]);
	end
end

function conflicts(a, b)
	local ain, aout = dependencies(a);
	local bin, bout = dependencies(b);
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
		return asub < bsub;
	else
		return amain < bmain;
	end
end

function testSwap(a, b)
	if conflicts(a, b) then
		return false;
	end
	if not rank[a.name] or not rank[b.name] then
		return false;
	end
	if rank[b.name] ~= rank[a.name] then
		return rank[a.name] > rank[b.name];
	end
	if a.arg[1] ~= b.arg[1] then
		return a.arg[1] < b.arg[1];
	end
	if a.arg[2] and a.arg[2] then
		return a.arg[2] < b.arg[2];
	end
end


--------------------------------------------------------------------------------
-- Tests

local text = "\t   mov eax, [ebx + 8]";

local int = parseInstruction(text);

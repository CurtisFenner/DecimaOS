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
		--print("???"); -- Hex?
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

function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"));
end

function parseLines(file)

	local mode = "normal";

	local instructions = {};
	for i = 1, #file do
		local line, comment = file[i];
		line, comment = stripComment(line);


		if trim(comment):sub(1,#"@optimize ") == "@optimize " then
			mode = trim(comment):sub(#"@optimize "+1);
		end

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

	-- print("Optimization Mode: " .. mode:lower());

	return instructions, mode:lower();
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

function locOf(source, n)
	local line = 1;
	local column = 1;
	for i = 1, n do
		local c = source:sub(i,i);
		if c == "\n" then
			line = line + 1;
			column = 1;
		elseif c == "\t" then
			column = math.ceil(column / 4) * 4;
			column = column + 1;
		else
			column = column + 1;
		end
	end
	return line .. ":" .. column;
end


local pi = 1;
local pis = {};

function pSave()
	pis[#pis+1] = pi;
end
function pRestore()
	pi = pis[#pis];
	pis[#pis] = nil;
end
function pContinue()
	pis[#pis] = nil;
end

local pfile = io.open("optimizations.txt");
local psource = pfile:read("*all");
pfile:close();

function pPeek()
	return psource:sub(pi,pi);
end
function pForward(n)
	pi = pi + (n or 1);
	return psource:sub(pi - (n or 1), pi-1);
end

function pAtEnd()
	return pi > #psource;
end

function pSkipWhite()
	while not pAtEnd() and pPeek():match("%s") do
		pForward();
	end
end
function pWord(matcher)
	local w = "";
	while not pAtEnd() and pPeek():match(matcher) do
		w = w .. pForward();
	end
	return w;
end

function pWhiteWord(matcher)
	pSkipWhite();
	return pWord(matcher);
end

function pParseArg()
	return pWhiteWord("[%w%%#$_]");
end

function pCheck(c)
	pSkipWhite();
	if pAtEnd() then
		return false;
	end
	return psource:sub(pi, pi+#c-1) == c;
end

function pExpect(c)
	if not pCheck(c) then
		error("Expected " .. c .. " at " .. locOf(psource, pi));
	end
	pForward(#c);
end

local pdi = {};

function delimitStart(match)
	pSave();
	while not pAtEnd() and not pPeek():match(match) do
		pForward();
	end
	pdi[#pdi+1] = pi;
	pRestore();
end

function delimitCheck()
	return pi < pdi[#pdi];
end

function delimitEnd()
	pdi[#pdi] = nil;
end

function pParseArgs()
	local list = {};
	delimitStart("\n");
	pSkipWhite();
	while delimitCheck() do
		if #list ~= 0 then
			if not pCheck(",") then
				break;
			end
			pExpect(",");
		end
		
		
		
		local arg = pParseArg();
		if not arg or arg == "" then
			break;
		end
		list[#list+1] = arg;
	end
	delimitEnd();
	return list;
end

function pParseInstruction()
	if pCheck("}") then
		return nil;
	end
	local op = pWord("%w");
	if op == "" then
		return nil;
	end
	local args = pParseArgs();
	local r = {op};
	for i = 1, #args do
		r[i+1] = args[i];
	end
	return r;
end

function pParseBody()
	pExpect("{");
	local ints = {};
	repeat
		local int = pParseInstruction();
		if int then
			ints[#ints+1] = int;
		end
	until int == nil
	pExpect("}");
	return ints;
end

function pParseExclude()
	if not pCheck("exclude") then
		return nil;
	end
	pExpect("exclude");
	local name = pParseArg();
	pExpect("{");
	local values = pParseArgs();
	pExpect("}");
	return {name = name, values = values};
end

function pParseExcludes()
	local excludes = {};
	repeat
		local exclude = pParseExclude();
		if exclude then
			excludes[exclude.name] = exclude.values;
		end
	until exclude == nil
	return excludes;
end

function pParseRule()
	pSkipWhite();
	if pAtEnd() then
		return nil;
	end
	pExpect("\"");
	local name = pWord("[^\"]");
	pExpect("\"");
	local from = pParseBody();
	local to = pParseBody();

	local excludes = pParseExcludes();

	return {name = name, from = from, to = to, exceptions = excludes};

end

function pParseRules()
	local rules = {};
	repeat
		local rule = pParseRule();
		if rule then
			rules[#rules+1] = rule;
		end
	until rule == nil
	return rules;
end

local peepRules = pParseRules();


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
			elseif compare:sub(1,1) == "%" then
				arg = arg:lower();
				if arg == "esp" or arg == "ebp" or arg == "sp" or arg == "bp" then
				elseif arg:len() == 2 then
					if not contains({"a","b","c","d","e",},arg:sub(1,1)) or not contains({"x","l","h"},arg:sub(2,2)) then
						return false;
					end
				elseif arg:len() == 3 then
					if arg:sub(1,1) ~= "e" or arg:sub(3,3) ~= "x" or not contains({"a","b","c","d","e",},arg:sub(1,1)) then
						return false;
					end
				else
					return false
				end
				if vars[compare] and vars[compare] ~= arg then
					return false
				end
				vars[compare] = arg;
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
		if rule.show then
			print("\n" .. rule.name .. ":");
		end
		local wholeComment = "";
		for j = 1, #rule.from do
			local ik = table.remove(instructions, index);
			if wholeComment ~= "" then
				wholeComment = wholeComment .. " & ";
			end
			wholeComment = wholeComment .. ik.comment;
			if rule.show then
				print("", ik.name, unpack(ik.args));
			end
		end

		local newComment = "optimize " .. rule.name;
		if wholeComment ~= "" then
			newComment = wholeComment .. " || " .. newComment;
		end

		if type(rule.to) == "function" then -- iterate backwards since we insert them all into the new spot
			local insert = rule.to(vars);
			for j = #insert, 1, -1 do
				local ins = insert[j];
				local op = table.remove(ins, 1);
				table.insert(instructions, index, {name = op, args = ins, comment = newComment} );
			end
		else
			for j = #rule.to, 1, -1 do
				local instruction = {};
				local to = rule.to[j];
				instruction.name = to[1];
				instruction.args = {};
				instruction.comment = newComment;
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

function optimize(instructions, optimizeMode)
	local loop = 0;
	repeat
		loop = loop + 1;
		local changed = false;
		for _, rule in ipairs(peepRules) do
			if rule.mode == nil or rule.mode == optimizeMode then
				changed = attemptRule(instructions, rule) or changed;
			end
		end
		changed = reorderInstructions(instructions) or changed;
		-- print("Optimization loop " .. loop);
	until (not changed) or loop > 20
end


--------------------------------------------------------------------------------

-- Tests


local file = readFile(arg[1]);
--file = {"push 1", "push eax", "pop eax", "pop ecx"};

local instructions, optimizeMode = parseLines(file);
optimize(instructions, optimizeMode);

local result = stringInstructions( instructions );

local f = io.open( arg[2] or "optout.asm", "w");
for i = 1, #result do
	f:write(result[i] .. "\n");
end

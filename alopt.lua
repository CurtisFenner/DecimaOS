function readFile(fname)
	local lines = {};
	for line in io.lines(fname) do
		table.insert(lines, line);
	end
	return lines;
end

--------------------------------------------------------------------------------

local iotable = {};

iotable.add_2 = {ins = {"#1", "#2"}, outs = {"#1"}};
iotable.imul_2 = {ins = {"#1", "#2"}, outs = {"#1"}};
iotable.push_2 = {ins = {"esp", "#1"}, outs = {"esp", "[mem]"}};
iotable.pop_1 = {ins = {"esp", "[mem]"}, outs = {"esp", "#1"}};

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
				table.insert(extension, ra .. "l");
				table.insert(extension, ra .. "h");
				table.insert(extension, ra .. "x");
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
		return asub < bsub;
	else
		return amain < bmain;
	end
end

function canSwap(a, b)
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

function instructionOrderer(a, b)
	print(a, b);
	return not testSwap(a, b);
end


--------------------------------------------------------------------------------
-- Tests

local file = readFile("kernel.c.asm");
local instructions = {};
for i = 1, #file do
	local line, comment = file[i];
	line, comment = stripComment(line);
	local instruction = parseInstruction(line);
	if instruction then
		table.insert(instructions, parseInstruction(line));
	else
		table.insert(instructions, {name = line, args = {}});
	end
	local top = instructions[#instructions];
	top.comment = (top.comment or "") .. comment;
end

-- Bubblesort
for iter = 1, #instructions - 1 do
	for j = 1, #instructions - 1 do
		local a = instructions[j];
		local b = instructions[j + 1];
		if canSwap(a, b) then
			instructions[j] = b;
			instructions[j + 1] = a;
		end
	end
end

local result = {};

for i = 1, #instructions do
	table.insert(result,instructions[i].name
		.. " " .. table.concat(instructions[i].args, ", ")
		.. "; " .. instructions[i].comment);
end

local wid = 20;
for i = 1, #file do
	local left = file[i];
	if #left > wid - 3 then
		left = left:sub(1, wid - 3) .. "...";
	end
	left = left .. (" "):rep(wid - #left) .. "    | ";
	print(left .. result[i]);
end


--[[
; Assembly genera...    |  ;  Assembly generated by clua32.lua from kernel.c
                        |  ; 
[org 0x9000]            | [org 0x9000] ; 
[bits 32]               | [bits 32] ; 
                        |  ; 
kernel:                 | kernel :; 
call _fun_main          | call _fun_main; 
jmp $                   | jmp $; 
                        |  ; 
                        |  ; 
                        |  ; 
_fun_console_prin...    | _fun_console_printc: ; 
                        |  ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 16             | add eax, 16; 
push eax; str           | push eax;  str
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax; derefer...    | push eax;  dereference
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
                        |  ; 
push 0                  | push 0; 
                        |  ; 
_while_pre_condit...    | _while_pre_condition_2: ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 24             | add eax, 24; 
push eax; str           | push eax;  str
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 4              | add eax, 4; 
push eax; i             | push eax;  i
; addition              |  ;  addition
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop eax                 | pop eax; 
pop ecx                 | pop ecx; 
imul eax, 1; poin...    | imul eax, 1;  pointer math on char*
                        |  ; 
add eax, ecx            | add eax, ecx; 
push eax; derefer...    | push eax;  dereference
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
mov eax, 0              | mov eax, 0; 
pop ebx                 | pop ebx; 
mov al, bl; cast ...    | mov al, bl;  cast char -> int
                        |  ; 
push eax                | push eax; 
push 0                  | push 0; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
cmp eax, ecx; > h...    | cmp eax, ecx;  > here and down
                        |  ; 
jg _positive_3          | jg _positive_3; 
push dword 0            | push dword 0; 
jmp _cmp_end_3          | jmp _cmp_end_3; 
_positive_3:            | _positive_3: ; 
push dword 1            | push dword 1; 
_cmp_end_3:; > he...    | _cmp_end_3: ;  > here and up
; while () {            |  ;  while () {
                        |  ; 
pop eax                 | pop eax; 
cmp eax, 0              | cmp eax, 0; 
je _while_end_2         | je _while_end_2; 
; console_index         |  ;  console_index
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 16             | add eax, 16; 
push eax; x             | push eax;  x
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 4              | add eax, 4; 
push eax; i             | push eax;  i
; addition              |  ;  addition
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
add eax, ecx            | add eax, ecx; 
push eax; int-typ...    | push eax;  int-type addition
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 16             | add eax, 16; 
push eax; y             | push eax;  y
                        |  ; 
; getting 1 to rv...    |  ;  getting 1 to rvalue
                        |  ; 
mov ebx, esp            | mov ebx, esp; 
add ebx, 0              | add ebx, 0; 
mov ecx, [ebx]          | mov ecx, [ebx]; 
mov eax, [ecx]          | mov eax, [ecx]; 
mov [ebx], eax; c...    | mov [ebx], eax;  convert to rvalue
                        |  ; 
call _fun_console...    | call _fun_console_index;  void console_index
                        |  ; 
add esp, 8; (clea...    | add esp, 8;  (cleanup parameters)
                        |  ; 
push eax; returne...    | push eax;  returned value
                        |  ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 0              | add eax, 0; 
push eax; c             | push eax;  c
                        |  ; 
push 0; addition        | push 0;  addition
                        |  ; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop eax                 | pop eax; 
pop ecx                 | pop ecx; 
imul eax, 1; poin...    | imul eax, 1;  pointer math on char*
                        |  ; 
add eax, ecx            | add eax, ecx; 
push eax; derefer...    | push eax;  dereference
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 32             | add eax, 32; 
push eax; str           | push eax;  str
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 12             | add eax, 12; 
push eax; i             | push eax;  i
; addition              |  ;  addition
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop eax                 | pop eax; 
pop ecx                 | pop ecx; 
imul eax, 1; poin...    | imul eax, 1;  pointer math on char*
                        |  ; 
add eax, ecx            | add eax, ecx; 
push eax; derefer...    | push eax;  dereference
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop eax                 | pop eax; 
pop ebx                 | pop ebx; 
mov [ebx], al; as...    | mov [ebx], al;  assignment
                        |  ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 0              | add eax, 0; 
push eax; c             | push eax;  c
                        |  ; 
push 1; addition        | push 1;  addition
                        |  ; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop eax                 | pop eax; 
pop ecx                 | pop ecx; 
imul eax, 1; poin...    | imul eax, 1;  pointer math on char*
                        |  ; 
add eax, ecx            | add eax, ecx; 
push eax; derefer...    | push eax;  dereference
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 28             | add eax, 28; 
push eax; style         | push eax;  style
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop eax                 | pop eax; 
pop ebx                 | pop ebx; 
mov [ebx], al; as...    | mov [ebx], al;  assignment
                        |  ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 4              | add eax, 4; 
push eax; i             | push eax;  i
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 8              | add eax, 8; 
push eax; i             | push eax;  i
                        |  ; 
push 1; addition        | push 1;  addition
                        |  ; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
add eax, ecx            | add eax, ecx; 
push eax; int-typ...    | push eax;  int-type addition
                        |  ; 
pop eax                 | pop eax; 
pop ebx                 | pop ebx; 
mov [ebx], eax; a...    | mov [ebx], eax;  assignment
                        |  ; 
add esp, 4              | add esp, 4; 
jmp _while_pre_co...    | jmp _while_pre_condition_2; 
_while_end_2:; }        | _while_end_2: ;  }
                        |  ; 
add esp, 8              | add esp, 8; 
ret                     | ret ret; 
                        |  ; 
                        |  ; 
                        |  ; 
                        |  ; 
_fun_console_clea...    | _fun_console_clear: ; 
                        |  ; 
; console_fill          |  ;  console_fill
                        |  ; 
push ` `                | push ` `; 
call _fun_console...    | call _fun_console_fill;  void console_fill
                        |  ; 
add esp, 4; (clea...    | add esp, 4;  (cleanup parameters)
                        |  ; 
ret                     | ret ret; 
                        |  ; 
                        |  ; 
                        |  ; 
                        |  ; 
_fun_console_fill...    | _fun_console_fill: ; 
                        |  ; 
                        |  ; 
push 0x000b8000         | push 0x000b8000; 
                        |  ; 
push 0                  | push 0; 
                        |  ; 
_while_pre_condit...    | _while_pre_condition_4: ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 0              | add eax, 0; 
push eax; i             | push eax;  i
                        |  ; 
push 80                 | push 80; 
push 25                 | push 25; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
imul eax, ecx           | imul eax, ecx; 
push eax                | push eax; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop eax                 | pop eax; 
cmp eax, ecx; < h...    | cmp eax, ecx;  < here and down
                        |  ; 
jl _positive_5          | jl _positive_5; 
push dword 0            | push dword 0; 
jmp _cmp_end_5          | jmp _cmp_end_5; 
_positive_5:            | _positive_5: ; 
push dword 1            | push dword 1; 
_cmp_end_5:; < he...    | _cmp_end_5: ;  < here and up
; while () {            |  ;  while () {
                        |  ; 
pop eax                 | pop eax; 
cmp eax, 0              | cmp eax, 0; 
je _while_end_4         | je _while_end_4; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 4              | add eax, 4; 
push eax; screen        | push eax;  screen
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 4              | add eax, 4; 
push eax; i             | push eax;  i
                        |  ; 
push 2                  | push 2; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop eax                 | pop eax; 
imul eax, ecx           | imul eax, ecx; 
push eax; additio...    | push eax;  addition
                        |  ; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop eax                 | pop eax; 
pop ecx                 | pop ecx; 
imul eax, 1; poin...    | imul eax, 1;  pointer math on char*
                        |  ; 
add eax, ecx            | add eax, ecx; 
push eax; derefer...    | push eax;  dereference
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 16             | add eax, 16; 
push eax; w             | push eax;  w
                        |  ; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop eax                 | pop eax; 
pop ebx                 | pop ebx; 
mov [ebx], al; as...    | mov [ebx], al;  assignment
                        |  ; 
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 0              | add eax, 0; 
push eax; i             | push eax;  i
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 4              | add eax, 4; 
push eax; i             | push eax;  i
                        |  ; 
push 1; addition        | push 1;  addition
                        |  ; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
add eax, ecx            | add eax, ecx; 
push eax; int-typ...    | push eax;  int-type addition
                        |  ; 
pop eax                 | pop eax; 
pop ebx                 | pop ebx; 
mov [ebx], eax; a...    | mov [ebx], eax;  assignment
                        |  ; 
jmp _while_pre_co...    | jmp _while_pre_condition_4; 
_while_end_4:; }        | _while_end_4: ;  }
                        |  ; 
add esp, 8              | add esp, 8; 
ret                     | ret ret; 
                        |  ; 
                        |  ; 
                        |  ; 
                        |  ; 
_fun_console_inde...    | _fun_console_index: ; 
                        |  ; 
                        |  ; 
push 0x000b8000         | push 0x000b8000; 
mov eax, esp            | mov eax, esp; 
add eax, 12             | add eax, 12; 
push eax; x             | push eax;  x
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 12             | add eax, 12; 
push eax; y             | push eax;  y
                        |  ; 
push 80                 | push 80; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
pop eax                 | pop eax; 
imul eax, ecx           | imul eax, ecx; 
push eax; additio...    | push eax;  addition
                        |  ; 
pop ecx                 | pop ecx; 
pop ebx                 | pop ebx; 
mov eax, [ebx]          | mov eax, [ebx]; 
push eax                | push eax; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
add eax, ecx            | add eax, ecx; 
push eax; int-typ...    | push eax;  int-type addition
                        |  ; 
push 2                  | push 2; 
pop ecx                 | pop ecx; 
pop eax                 | pop eax; 
imul eax, ecx           | imul eax, ecx; 
push eax; additio...    | push eax;  addition
                        |  ; 
pop ecx                 | pop ecx; 
push ecx; now rva...    | push ecx;  now rvalues
                        |  ; 
pop eax                 | pop eax; 
pop ecx                 | pop ecx; 
imul eax, 1; poin...    | imul eax, 1;  pointer math on char*
                        |  ; 
add eax, ecx            | add eax, ecx; 
push eax                | push eax; 
pop eax                 | pop eax; 
ret                     | ret ret; 
ret                     | ret ret; 
                        |  ; 
                        |  ; 
                        |  ; 
_global___string_...    | _global___string_literal_1: ; 
db "The Decima C ...    | db "The Decima C kernel has successfully started.", 0; 
                        |  ; 
                        |  ; 
                        |  ; 
_fun_main:              | _fun_main: ; 
                        |  ; 
; console_clear         |  ;  console_clear
                        |  ; 
call _fun_console...    | call _fun_console_clear;  void console_clear
; (cleanup parame...    |  ;  (cleanup parameters)
                        |  ; 
                        |  ; 
push _global___st...    | push _global___string_literal_1;  __string_literal_1
                        |  ; 
; console_printc        |  ;  console_printc
                        |  ; 
mov eax, esp            | mov eax, esp; 
add eax, 0              | add eax, 0; 
push eax; msg           | push eax;  msg
                        |  ; 
push 0x0F               | push 0x0F; 
push 0                  | push 0; 
push 0                  | push 0; 
; getting 4 to rv...    |  ;  getting 4 to rvalue
                        |  ; 
mov ebx, esp            | mov ebx, esp; 
add ebx, 12             | add ebx, 12; 
mov ecx, [ebx]          | mov ecx, [ebx]; 
mov eax, [ecx]          | mov eax, [ecx]; 
mov [ebx], eax; c...    | mov [ebx], eax;  convert to rvalue
                        |  ; 
call _fun_console...    | call _fun_console_printc;  void console_printc
                        |  ; 
add esp, 16; (cle...    | add esp, 16;  (cleanup parameters)
                        |  ; 
add esp, 4              | add esp, 4; 
ret                     | ret ret; 
                        |  ; 
                        |  ; 
[Finished in 1.6s]
]]
local uniquen = 0;
local output = "";

--------------------------------------------------------------------------------

function emit(str, stacksure)
	if str:find("pop") and stacksure ~= "pop" then
		print("!!!WARNING!!!\n\tEmit passed `" .. str .. "` but not popsure", stacksure);
		print(debug.traceback());
	elseif str:find("push") and stacksure ~= "push" then
		print("!!!WARNING!!!\n\tEmit passed `" .. str .. "` but not pushsure", stacksure);
		print(debug.traceback());
	end
	output = output .. "\n" .. str;
end

function comment(str)
	output = output .. "; " .. str:gsub("\n", "\n; ") .. "\n";
end

function peek(stack)
	return stack[#stack];
end

function pop(stack, into)
	table.remove(stack);
	emit("pop " .. into, "pop");
end

function typepop(stack, into, type, reason)
	local peekType = peek(stack).type;
	local acceptable = peekType == type;
	if type == "=" then
		acceptable = acceptable or (peekType:sub(1, 1) == "=");
	elseif type == "*" then
		acceptable = acceptable or (peekType:sub(-1, -1) == "*");
	end
	if not acceptable then
		error("Cannot pop " .. peekType .. "; requires " .. type .. reason);
	end
	pop(stack, into);
end

function push(stack, stackvalue, text)
	table.insert(stack, stackvalue);
	emit("push " .. text, "push");
end

--------------------------------------------------------------------------------

function unique()
	uniquen = uniquen + 1;
	return uniquen;
end

function parseNumber(n)
	return tonumber(n), "int"; -- TODO FIX
end

function compile(declarations, main, label)
	output = ";@optimize extended\n" .. (label or main) .. ":\ncall _fun_" .. main .. "\njmp $\n\n";
	uniquen = 0;

	for _, dec in pairs(declarations) do
		if dec.sort ~= "definition" then
			replaceStringLiterals(dec, declarations);
		else
			if dec.type == "char*" then
				local iden = "__string_literal_" .. unique();
				declarations[iden] = {name = iden, sort = "variable", value = dec.value[1], type = "char", data = true, global = true};
				dec.data = true;
				dec.form = "label";
				dec.label = "_global_" .. iden;
			end
		end
	end

	for name, dec in pairs(declarations) do
		if dec.sort == "function" then
			emitFunction(dec, declarations);
		elseif dec.sort == "definition" then
			emit("_global_" .. dec.name .. ":");
			if dec.form == "label" then
				-- TODO
				emit("dd" .. dec.label .. "\n");
			else
				local value = dec.value;
				local acceptable = (#value == 1) or (#value == 2 and value[2] == "u-");
				if not acceptable  then
					error("Non constant initialization of " .. dec.name);
				end
				local negative = value[2];
				value = value[1];
				if negative then
					value = "-" .. value;
				end
				emit( dform(typeSize(dec.type)) .. " " .. value );
			end
		elseif dec.sort == "variable" then
			emit("_global_" .. dec.name .. ":");
			if dec.data then
				emit("db " .. dec.value .. ", 0\n");
			else
				emit(dform(typeSize(dec.type)) .. " 0\n");
			end
		end
		emit(""); -- Empty space
	end
	return output;
end

function dform(n)
	local sizes = {"db", "dw", nil, "dd"};
	return sizes[n] or error("No name for size");
end

function typeSize(type, context)
	context = context or "stack";
	if context ~= "stack" and context ~= "memory" then
		error(tostring(context) .. "is not a valid typeSize context");
	end
	if type:sub(1,1) == "=" then
		return 4; -- lvalue
	end
	if type:sub(-1,-1) == "*" then
		return 4;
	end
	if type == "int" or type == "long" or type == "uint" or type == "ulong" then
		return 4;
	end
	if type == "char" then
		if context == "memory" then
			return 1;
		end
		return 4; -- because of register size / padding
	end
	if type == "float" then
		return 4;
	end
	if type == "double" then
		return 8;
	end
	if type == "void" then
		return 0;
	end
	return 0; -- likely unintended
end

function emitFunction(fun, globals)
	local stack = {}
	for _, param in pairs(fun.parameters) do
		table.insert( stack, {name = param.name, type = param.type} ); -- inform it of the parameters
	end
	table.insert( stack, {name="%return", type="fun*" } ); -- the returning pointer
	local label = "\n_fun_" .. fun.name .. ":\n";
	emit(label);
	emitBlock(fun.body, stack, globals);
	emit("ret\n\n");
end

function locationOf(name, stack, globals)
	local s = 0
	for i = #stack, 1, -1 do
		if stack[i].name == name then
			return {location="stack", offset=s , type=stack[i].type};
		end
		s = s + typeSize( stack[i].type, "stack" );
	end
	if not globals[name] then
		error("`" .. name .. "` was not defined.");
	end
	if globals[name].sort == "function" then
		return {location="function", name = name, type="void", funtype = globals[name].type};
	end
	return {location="global", type=globals[name].type};
end

function stackAllocate(stack, type, name)
	table.insert(stack, {name=name, type=type});
	emit("sub esp, " .. typeSize(type));
	comment("allocation for " .. type .. " " .. name);
end

function regSize(r, size)
	if size == 1 then
		return r .. "l";
	end
	if size == 2 then
		return r .. "x";
	end
	if size == 4 then
		return "e" .. r .. "x";
	end
	error("UNKNOWN SIZE REGISTER");
end

function stackConvertValue(stack) -- clobbers ebx, eax
	if stack[#stack].type:sub(1, 1) == "=" then
		changeTopType(stack, peek(stack).type:sub(2)); -- Eliminate the =
		emit("pop ebx", "pop");
		emit("mov eax, [ebx]");
		emit("push eax", "push");
	end
end

-- pass 1 for top...
function stackMakeRight(stack, deep)
	local index = #stack - deep + 1;
	local obj = stack[index];
	if obj.type:sub(1, 1) == "=" then
		emit("");
		comment("getting " .. deep .. " to rvalue");
		local back = 0;
		for i = index + 1, #stack do
			back = back + typeSize(stack[i].type, "stack");
		end
		obj.type = obj.type:sub(2);
		emit("mov ebx, esp");
		emit("add ebx, " .. back);
		-- EBX holds: a position on the stack, which is the variable which
		-- is an lvalue (a position in memory)
		-- Want to CHANGE [ebx] to be the value at the position in that memory
		emit("mov ecx, [ebx]"); -- ECX holds the position in memory of the variable
		emit("mov eax, [ecx]");
		emit("mov [ebx], eax"); -- Write new value there.
		-- Eax now holds memory address to read from
		-- Write value to location...
		comment("convert to rvalue");
	else
	end
end

function changeTopType(stack, new)
	peek(stack).type = new;
end

function cleanupStack(stack, items)
	local count = 0;
	for i = 1, items do
		local top = table.remove(stack);
		count = count + typeSize(top.type, "stack");
	end
	if count ~= 0 then
		emit("add esp, " .. count .. "");
	else
		return "";
	end
end

function emitBlock(block, stack, globals)
	local height = #stack;
	for i = 1, #block do
		emit(""); -- Separate statements
		local s = block[i];
		if s.sort == "definition" then
			-- calculate
			emitExpression( s.value, stack, globals );
			stackConvertValue(stack);
			if stack[#stack].type ~= s.type then
				error("Inalid assignment to " .. s.name .. "; expected " .. s.type .. " but got " .. stack[#stack].type);
			end
			peek(stack).name = s.name;
			-- we must replace the last thing with the variable. so...
			-- will automatically leave it on the stack...
			-- pretty much a hack, but whatever
			-- TODO , probably works completely now
		elseif s.sort == "while" then
			local iden = unique();
			local whilePreCondition = "_while_pre_condition_" .. iden;
			emit( whilePreCondition .. ":\n" );
			emitExpression( s.condition, stack, globals );
			comment("while () {");
			stackConvertValue(stack);
			pop(stack, "eax");
			emit("cmp eax, 0");
			emit("je _while_end_" .. iden);
			emitBlock(s.body, stack, globals);
			emit("jmp " .. whilePreCondition);
			emit("_while_end_" .. iden .. ":");
			comment("}");
		elseif s.sort == "if" then
			emitExpression( s.condition, stack, globals );
			comment("if () {");
			local iden = unique();
			stackConvertValue(stack);
			pop(stack, "eax");
			emit("cmp eax, 0");
			if s.elseBody then
				emit("je _if_else_" .. iden);
				emitBlock(s.body, stack, globals);
				emit("jmp _if_end_" .. iden);
				comment("} else {");
				emit("_if_else_" .. iden .. ":");
				emitBlock(s.elseBody, stack, globals);
			else
				emit("je _if_end_" .. iden);
				emitBlock(s.body, stack, globals);
			end
			emit("_if_end_" .. iden .. ":");
			comment("}");
		elseif s.sort == "variable" then
			-- allocate space on the stack
			stackAllocate(stack, s.type, s.name);
		elseif s.sort == "expression" then
			emitExpression( s.value, stack, globals, true );
		elseif s.sort == "return" then
			emitExpression( s.value, stack, globals );
			stackConvertValue(stack);
			pop(stack, "eax"); -- return through eax
			-- cleanup the stack...
			cleanupStack( stack, #stack - height);
			emit("ret");
			return;
		end
	end
	cleanupStack( stack, #stack - height );
	-- clean up everything on the stack (that I put there myself)
	return out;
end

-- an atom within an expression
function emitAtom(atom, stack, globals)
	if tonumber(atom:sub(1,1)) then
		if atom:find("%.") then
			-- it's a double
			--return "push "
			error("Floating literals are not supported");
		else
			-- it's an int
			push(stack, {name = "", type = "int"}, atom);
		end
	elseif atom:sub(1, 1) == "'" then
		local literal = {name = "", type = "char"};
		if atom:sub(2,-2) == "`" then
			push(stack, literal, "'`'");
		else
			push(stack, literal, "`" .. atom:sub(2, -2) .. "`");
		end
	else
		local location = locationOf(atom, stack, globals);
		if location.location == "stack" then
			emit("mov eax, esp");
			emit("add eax, " .. location.offset);
			push(stack, {name = "", type = "=" .. location.type}, "eax");
		elseif location.location == "global" then
			push(stack, {name = "", type = "=" .. location.type}, "_global_" .. atom);
		elseif location.location == "function" then
			-- takes up no space, just a reference to remember
			table.insert(stack, location) -- INTENTIONALLY NOT PUSH
		else
			error("unknown atom type, undeclared?");
		end
		comment(tostring(atom));
	end
end

-- Takes top two values off stack, placing into registeres
-- ecx and eax; verifies they are int integers.
-- Errors if not.
function emitLoadBinInt(stack)
	stackConvertValue(stack);
	typepop(stack, "ecx", "int", "for loading binary operator, 1");
	stackConvertValue(stack);
	typepop(stack, "eax", "int", "for loading binary operator, 2");
end

-- emitLoadBinInt, then performs the assembly operation op:
-- op eax, ecx.
function binMath(stack, op)
	emitLoadBinInt(stack);
	emit(op .. " eax, ecx");
	push(stack, {type = "int"}, "eax");
end

-- supports int and pointer math
function binAddition(stack)
	-- One of the top two things on the stack should be *.
	-- One of the other two should be int
	comment("addition");
	stackConvertValue(stack);
	local A = peek(stack);
	pop(stack, "ecx");
	stackConvertValue(stack);
	local B = peek(stack);
	push(stack, A, "ecx");
	comment("now rvalues");
	-- pop -> A. pop -> B.
	if A.type:sub(-1, -1) == "*" then
		if B.type:sub(-1, -1) == "*" then
			error("Cannot add two pointer values.");
		end
		if B.type ~= "int" then
			error("Only pointer + int is supported; attempted "
				.. A.type .. " + " .. B.type);
		end
		-- A is a pointer; B is an integer
		local factor = typeSize(A.type:sub(1, -2), "memory");
		pop(stack, "ecx"); -- ECX has A, a pointer
		pop(stack, "eax"); -- EAX has B
		emit("imul eax, " .. factor);
		comment("pointer math on " .. A.type);
		-- ecx holds A.  eax holds B
		emit("add eax, ecx");
		push(stack, {type = A.type}, "eax");
	elseif B.type:sub(-1, -1) == "*" then
		if A.type ~= "int" then
			error("Only pointer + int is supported; attempted "
				.. A.type .. " + " .. B.type);
		end
		-- B is a pointer; A is an integer
		local factor = typeSize(B.type:sub(1, -2), "memory");
		pop(stack, "eax"); -- EAX now has A
		pop(stack, "ecx"); -- ECX now has B, a pointer
		emit("imul eax, " .. factor);
		comment("pointer math on " .. B.type);
		-- ecx holds B. eax holds A
		emit("add eax, ecx");
		push(stack, {type = B.type}, "eax");
	else
		if A.type ~= "int" or B.type ~= "int" then
			error("Only integer sum is supported; attempted "
				.. A.type .. " + " .. B.type);
		end
		-- Neither are pointers, use default addition...
		pop(stack, "ecx");
		pop(stack, "eax");
		emit("add eax, ecx");
		push(stack, {type = "int"}, "eax");
		comment("int-type addition");
	end
	return out;
end

function emitExpression( exp, stack, globals, cleanUp )
	local height = #stack;
	for i = 1, #exp do
		local e = exp[i];
		if e == "+" then
			binAddition(stack);
		elseif e == "*" then
			binMath(stack, "imul");
		elseif e == "-" then
			binMath(stack, "sub"); -- TODO verify the order
		elseif e == "u*" then
			-- Dereference
			local top = peek(stack);
			if top.type:sub(-1, -1) ~= "*" then
				error("Attempt to dereference non-pointer (" .. top.type .. ")");
			end
			stackConvertValue(stack);
			comment("dereference");
			top.type = "=" .. top.type:sub(1, -2); -- Dereference trick
		elseif e == "u&" then
			local top = peek(stack);
			if top.type:sub(1, 1) ~= "=" then
				error("Attempt to reference non l-value (" .. top.type .. ")");
			end
			top.type = top.type:sub(2) .. "*"; -- Reference trick
		elseif e == "ucastchar*" then
			stackConvertValue(stack);
			local top = peek(stack);
			if top.type:sub(-1,-1) == "*" or top.type == "int" then
				top.type = "char*";
			else
				error("Attempt to cast from " .. top.type .. " to char*");
			end
		elseif e == "ucastint*" then
			stackConvertValue(stack);
			local top = peek(stack);
			if top.type:sub(-1,-1) == "*" or top.type == "int" then
				top.type = "int*";
			else
				error("Attempt to cast from " .. top.type .. " to int*");
			end
		elseif e == "ucastint" then
			local top = peek(stack);
			stackConvertValue(stack);
			if top.type == "int" or top.type:sub(-1,-1) == "*" then
				top.type = "int";
			elseif top.type == "char" then
				emit("mov eax, 0");
				emit("pop ebx", "pop"); -- temporary stack removal
				emit("mov al, bl");
				comment("cast char -> int");
				emit("push eax", "push"); -- stack reformed
				top.type = "int";
			else
				error("Attempt to cast from " .. top.type .. " to int");
			end
		elseif e == "ucastchar" then
			local top = peek(stack);
			stackConvertValue(stack);
			if top.type == "char" then
				-- Does nothing
			elseif top.type == "int" then
				top.type = "char";
				-- No needed assembly output
			else
				error("Attemp to cast from " .. top.type .. " to char");
			end
		elseif e:sub(1, 5) == "ucast" then
			error("Unhandled cast of type " .. e);
		elseif e == "=" then
			-- Assignment.
			stackConvertValue(stack);
			local size = typeSize(stack[#stack].type, "memory");
			pop(stack, "eax");
			pop(stack, "ebx");
			emit("mov [ebx], " .. regSize("a", size));
			comment("assignment");
		elseif e == "==" or e == "!=" or e == ">" or e == "<" or e == "<=" or e == ">=" then
			local ops = {};
			ops["=="] = "je";
			ops[">"] = "jg";
			ops["<"] = "jl";
			ops[">="] = "jge";
			ops["<="] = "jle";
			ops["!="] = "jne";
			emitLoadBinInt(stack); -- eax and ecx now contain the parameters
			emit("cmp eax, ecx");
			comment(e .. " here and down");
			local iden = unique();
			emit(ops[e] .. " _positive_" .. iden);
			emit("push dword 0", "push"); -- INTENTIONAL. Because of branch.
			emit("jmp _cmp_end_" .. iden);
			emit("_positive_" .. iden .. ":");
			emit("push dword 1", "push"); -- Intentional, see above.
			emit("_cmp_end_" .. iden .. ":");
			comment(e .. " here and up");
			table.insert(stack, {type = "int"}); -- Intentional.
		elseif e:sub(1, 1) == "@" then
			local arity = tonumber(e:sub(2))
			local fun = stack[#stack - arity];
			for i = 1, arity do
				stackMakeRight(stack, i);
			end
			emit("call _fun_" .. fun.name);
			comment(fun.type .. " " .. fun.name);
			-- TODO: Function pointer accept?
			cleanupStack(stack, arity + 1);
			comment("(cleanup parameters)");
			if fun.funtype ~= "void" then
				push(stack, {type = fun.funtype}, "eax");
				comment("returned value");
			end
		else
			emitAtom(e, stack, globals);
		end
	end
	if cleanUp then
		cleanupStack(stack, #stack - height);
	end
end


function replaceStringLiterals(tree, dec)
	if tree.data then
		return;
	end
	-- Tree can be a list (block)
	-- sort:
	-- if (condition, body, elseBody (may be nil))
	-- return (value)
	-- expression: expression
	-- definition: expression
	-- function: body
	if not tree.sort then
		-- A list of statements or a list of expressions in postfix
		if type(tree[1]) == "string" then
			-- Expression list
			for i = #tree, 1, -1 do
				if tree[i]:sub(1,1) == '"' then
					local iden = "__string_literal_" .. unique();
					dec[iden] = {name = iden, sort = "variable", value = tree[i], type = "char", data = true, global = true};
					tree[i] = iden;
					table.insert(tree, i + 1, "u&");
				end
			end
		else
			-- Compound statement
			for i = 1, #tree do
				replaceStringLiterals(tree[i], dec);
			end
		end
	elseif tree.sort == "variable" then
		-- Nothing to do
	elseif tree.sort == "definition" then
		replaceStringLiterals(tree.value, dec);
	elseif tree.sort == "if" then
		replaceStringLiterals(tree.condition, dec);
		replaceStringLiterals(tree.body, dec);
		if tree.elseBody then
			replaceStringLiterals(tree.elseBody, dec);
		end
	elseif tree.sort == "while" then
		replaceStringLiterals(tree.condition, dec);
		replaceStringLiterals(tree.body, dec);
	elseif tree.sort == "return" then
		replaceStringLiterals(tree.value, dec);
	elseif tree.sort == "expression" then
		replaceStringLiterals(tree.value, dec);
	elseif tree.sort == "function" then
		replaceStringLiterals(tree.body, dec);
	else
		deepPrint(tree);
		error("Undealt with type of tree");
		print(debug.traceback());
	end
end

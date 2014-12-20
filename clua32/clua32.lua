--[[
Known deviations from C
* Optional parens on conditions
* Mandatory braces on controls
* No multiple declaration
* No forward declarations (always visible)
* No empty blocks
* No do while
* No for (to be fixed)
* No directives
* No const, extern, volatile
* No array literals
* No array definitions
* Only implement int, char, pointers to any of these, as types
* No structs
* No typedef
* No automatic casting of char to int when operated on
]]


function table.find(tab, f)
	for i, v in pairs(tab) do
		if f == v then
			return i;
		end
	end
end

function errorAt(str, source, i)
	print(str,"at", sourceLocationString(source, i));
	print(debug.traceback());
	error();
end

function loadFile(fname)
	local text = "";
	for line in io.lines(fname) do
		text = text .. line .. "\n";
	end
	return text;
end

function stripComments(source)
	local out = "";
	local quote = nil;
	local escaped = false;
	local commented = false;
	for i = 1, #source do
		local c = source:sub(i, i);
		if quote then
			if escaped then
				escaped = false;
			else
				if c == quote then
					quote = nil;
				elseif c == "\\" then
					escaped = true;
				end
			end
		elseif not commented then
			if c == "'" or c == '"' then
				quote = c;
			end
			if source:sub(i, i + 1) == "//" then
				commented = "line";
			end
			if source:sub(i, i + 1) == "/*" then
				commented = "multi";
			end
		end
		if commented == "line" and c == "\n" then
			commented = false;
		elseif commented == "multi" and source:sub(i-2, i-1) == "*/" then
			commented = false;
		end
		if not commented then
			out = out .. c;
		else
			out = out .. c:gsub("%S", " ");
		end
	end
	return out;
end

function sourceLocation(source, index)
	local line = 1;
	local column = 1;
	local tabSize = 4;
	for i = 1, index do
		local c = source:sub(i, i);
		if c == "\r" then
		elseif c == "\n" then
			line = line + 1;
			column = 1;
		elseif c == "\t" then
			column = column + tabSize; -- Not really but close enough
		else
			column = column + 1;
		end
	end
	return line, column;
end

function sourceLocationString(source, to)
	local line, column = sourceLocation(source, to);
	return "Line " .. line .. ", column " .. column;
end

--------------------------------------------------------------------------------

local declarations = {};

--------------------------------------------------------------------------------

dofile("clua32/eSemicoloned.lua");

function eDeclaration(source, i, declarations)
	local i, dectype, name = eTypedName(source, i);
	i = eWhitespace(source, i);
	local c = source:sub(i, i);
	if declarations[name] then
		errorAt("Identifier " .. name
			.. " has already been declared", source, i);
	end
	if c == ";" then
		-- Variable declaration
		declarations[name] = {position = {sourceLocation(source, i)}, type = dectype, name = name, sort = "variable"};
		i = i + 1;
	elseif c == "=" then
		-- Variable definition
		declarations[name] = {position = {sourceLocation(source, i)}, type = dectype, name = name, sort = "definition"};
		local ret, semi = eSemicoloned(source, i + 1);
		declarations[name].value = parseExpression(semi);
		i = ret;
	elseif c == "(" then
		i, parameters = eTypedParameters(source, i);
		if not parameters then
			errorAt("Invalid function declaration", source, i);
		end
		declarations[name] = {position = {sourceLocation(source, i)}, type = dectype, name = name, sort = "function", parameters = parameters,
			global = "_" .. name};
		-- Curly brace (forward declaration is illegal)
		local body, scope;
		i, body, scope = eCompound(source, i);
		declarations[name].body = body;
		declarations[name].scope = scope;
	end
	return i;
end

function allDeclarations(source, i, idens)
	idens = idens or {};
	i = eWhitespace(source, i);
	while i <= #source do
		i = eDeclaration(source, i, idens);
		i = eWhitespace(source, i);
	end
	return idens;
end

function eCompound(source, i)
	local scope = {};
	i = eWhitespace(source, i);
	if source:sub(i, i) ~= "{" then
		errorAt("Compound statement requires curly brace", source, i);
	end
	i = i + 1;
	i = eWhitespace(source, i);
	-- Closing brace, opening brace, or statement
	local statements = {};
	if source:sub(i, i) == "}" then
		return i, statements, scope;
	end
	while i <= #source do
		local statement;
		i, statement = eStatement(source, i, scope);
		statement.position = {sourceLocation(source, i)};
		table.insert(statements, statement);
		i = eWhitespace(source, i);
		if source:sub(i, i) == "}" then
			return i + 1, statements, scope;
		end
	end
	error("Unclosed curly brace", source, i);
end

-- parseExpression(source)
-- returns postfix (@n where n is arity of function call; $ for [ ] access)
dofile("clua32/parseExpression.lua");

function eStatement(source, i, scope)
	i = eWhitespace(source, i);
	-- if source:sub(i, i) == "{" then
	-- 	return eCompound(source, i);
	-- end
	local j, word = eName(source, i);
	if word == "if" then
		i = j;
		local afterBrace, condition = eCharactered(source, i, "{");
		condition = parseExpression(condition);
		local brace = afterBrace - 1; -- where brace is
		local after, body = eCompound(source, brace);
		local afterElse, word = eName(source, after);
		local elseBody = nil;
		if word == "else" then
			after, elseBody = eCompound(source, afterElse);
		end
		return after,
			{sort = "if", condition = condition, body = body, elseBody = elseBody};
	elseif word == "while" then
		i = j;
		local afterBrace, condition = eCharactered(source, i, "{");
		condition = parseExpression(condition);
		local brace = afterBrace - 1; -- where brace is
		local after, body = eCompound(source, brace);
		return after,
			{sort = "while", condition = condition, body = body};
	elseif word == "return" then
		local after, value = eSemicoloned(source, j);
		return after, {sort = "return", value = parseExpression(value)};
	else
		-- Semicolon statement.
		local ni, dectype, name = eTypedNameMaybe(source, i);
		local statement = {sort = "expression", position = i, type = dectype, name = name};
		if ni then
			scope[name] = statement;
			i = ni;
			if source:sub(i, i) == ";" then
				scope[name].sort = "variable";
				return i + 1, scope[name];
			end
			statement.sort = "definition";
			-- Consume = sign
			i = eWhitespace(source, i);
			if source:sub(i, i) == "=" then
				i = i + 1
			else
				errorAt("Invalid definition", source, i);
			end
		end
		i = eWhitespace(source, i);
		local ret, statementSource = eSemicoloned( source, i );
		statement.value = parseExpression( statementSource );
		return ret, statement;
	end
end

function eTypedNameMaybe(source, i)
	i = eWhitespace(source, i);
	local i, dectype = eTypeMaybe(source, i);
	if not i then return
		false
	end
	local i, name = eName(source, i);
	return i, dectype, name;
end

function eTypedName(source, i)
	local from = i;
	local i, dectype, name = eTypedNameMaybe(source, i);
	if not name then
		errorAt("Expected name in declaration", source, from);
	end
	return i, dectype, name;
end

function eTypedParameters(source, i)
	i = eWhitespace(source, i);
	if source:sub(i, i) ~= "(" then
		errorAt("Typed parameters requires parenthesis", source, i);
	end
	i = i + 1;
	i = eWhitespace(source, i);
	if source:sub(i, i) == ")" then
		return i + 1, {};
	end
	local parameters = {};
	while i <= #source do
		local dectype, name;
		i, dectype, name = eTypedName(source, i);
		table.insert(parameters, {name = name, type = dectype});
		i = eWhitespace(source, i);
		if source:sub(i, i) == "," then
			i = i + 1;
		elseif source:sub(i, i) == ")" then
			return i + 1, parameters;
		else
			errorAt("Unexpected character <" .. source:sub(i, i) .. "> in parameter list", source, i);
		end
	end
	errorAt("Unclosed parameter list", source, i);
end

function eName(source, i)
	i = eWhitespace(source, i);
	if source:sub(i,i):find("[a-zA-Z_]") then
		local where = source:find("[^a-zA-Z_0-9]", i) or #source + 1;
		return where, source:sub(i, where - 1);
	else
		return false;
	end
end

function eTypeMaybe(source, i)
	local i, name = eName(source, i);
	if not name then
		return false;
	end
	local validType = {"int", "char", "long", "uint", "ulong", "void", "float", "double"};
	if not table.find(validType, name) then
		return false;
		--errorAt("<" .. name .. "> is not a valid type", source, i);
	end
	i = eWhitespace(source, i);
	while source:sub(i, i) == "*" do
		name = name .. "*";
		i = eWhitespace(source, i + 1);
	end
	return i, name;
end

function eType(source, i)
	local j, name = eTypeMaybe(source, i);
	if not name then
		errorAt("Type expected", source, i);
	end
	return j, name;
end

function eWhitespace(source, i)
	return source:find("%S", i) or #source + 1;
end

function deepPrint(obj, tab)
	tab = tab or 0;
	local ts = ("\t"):rep(tab);
	if type(obj) ~= "table" then
		return print(ts .. "\t" .. tostring(obj));
	end
	print(ts .. "{");
	for i, v in pairs(obj) do
		print(ts .. "\t" .. i .. " =");
		deepPrint(v, tab + 1);
	end
	print(ts .. "}");
end

local source = stripComments(loadFile( arg[1] ));
local identifiers = {};

local i, dec = allDeclarations(source, 1, identifiers);

dofile("clua32/compile.lua");
local listIden = {};
for iden, def in pairs(identifiers) do
	local to = #listIden + 1;
	if def.sort == "definition" or def.sort == "variable" then
		to = 1;
		def.global = true;
	end
	table.insert(listIden, to, def);
end
local s = compile(identifiers, arg[2] or "main", arg[3]);

local file = io.open(arg[1] .. ".asm", "w");
local prepare = "[org 0x9000]\n[bits 32]\n\n";
file:write("; Assembly generated by clua32.lua from " .. arg[1]
	.. "\n\n" .. prepare .. s);
file:close();
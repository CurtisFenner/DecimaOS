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

local thisfile = arg[0];

--------------------------------------------------------------------------------

function table.find(tab, f)
	for i, v in pairs(tab) do
		if f == v then
			return i;
		end
	end
end

function string.split(str, by)
	local list = {};
	for word in str:gmatch("[^" .. by .."]") do
		table.insert(list, word);
	end
	return list;
end

function string.trim(s)
	return string.match(s,'^()%s*$') and '' or string.match(s,'^%s*(.*%S)')
end

--------------------------------------------------------------------------------


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



function directive(line, identifiers, i, fname)
	-- Does not include #
	local space = line:find(" ");
	if not space then
		return print("Invalid directive:", line);
	end
	local word = line:sub(1, space - 1);
	if word == "include" then
		local arg = line:sub(space + 1);
		if arg:sub(1, 1) == "<" then
			arg = arg:sub(2, -2);
			arg = arg:gsub("%s", ""):lower();
			print(thisfile);
			local source = "";
			for line in io.lines(thisfile .. "/../include/" .. arg .. ".asm") do
				source = source .. line .. "\n";
				local semi = line:find(";");
				if semi and line:sub(1, semi - 1):gsub("%S", "") == "" then
					local comment = line:sub(semi + 1);
					local swirl = comment:find("@");
					if swirl then
						local anno = comment:sub(swirl + 1);
						-- Add to identifiers the appropriate function definition.
						local data = string.split(anno, ",");
						for i = 1, #data do
							data[i] = string.trim(data[i]);
						end
						-- Type, name, args
						local func = {type = data[1], name = data[2], sort = "function"};
						if identifiers[func.name] then
							print(func.name, "is defined by an included assembly file");
						end
						identifiers[func.name] = func;
						-- TODO
						-- Name and type
						local parameters = {};
						for i = 3, #data do
							table.insert(parameters,{name == "", type = data[i]});
						end
						func.parameters = parameters;
						func.heading = true;
					end
				end
			end
			identifiers["#" .. i] = {sort = "include", source = source};
		else
			local _, defs = clua32(fname .. "/../" .. arg, nil, true);
			identifiers["#" .. i] = {sort = "include"};
			for identifier, definition in pairs(defs) do
				identifiers[identifier] = definition;
			end
		end
		return;
	end
	print("UNHANDLED DIRECTIVE '", line, "' (ignoring)");
	return;
end

function allDeclarations(source, fname)
	local idens = {};
	local i = eWhitespace(source, 1);
	while i <= #source do
		if source:sub(i, i) == "#" then
			local lineEnd = source:find("\n", i) or #source;
			local line = source:sub(i + 1, lineEnd - 1);
			directive(line, idens, i, fname);
			i = lineEnd;
			i = eWhitespace(source, i);
		else
			i = eDeclaration(source, i, idens);
			i = eWhitespace(source, i);
		end
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


dofile("clua32/compile.lua");

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function clua32(src, main, secondary)
	local source = stripComments(loadFile(src));
	local identifiers = allDeclarations(source, src);
	local compiled = compile(identifiers, arg[2], arg[3]);
	local prepare = "[org 0x9000]\n[bits 32]\n\n";
	local text = "; Assembly generated by clua32.lua from " .. src .. "\n\n";
	if not secondary then
		text = text .. prepare;
	end
	if main then
		text = text .. "call _fun_" .. main .. "\njmp $\n\n";
	end
	text = text .. compiled;
	return text, identifiers;
end



local file = io.open(arg[3], "w");
file:write(clua32( arg[1], arg[2] ), "w");
file:close();
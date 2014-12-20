function table.find(tab, f)
	for i, v in pairs(tab) do
		if f == v then
			return i;
		end
	end
end

function parseExpression(source)
	local precedence = {
		["@@@"] = 0, -- Function application f(u)
		["$$$"] = 0, -- Indexing a[u]
		["."] = 1, ["->"] = 1, -- 1
		["u!"] = 2, ["u-"] = 2, ["u*"] = 2, ["u&"] = 2, ["usizeof"] = 2, -- 2
		["*"] = 3, ["/"] = 3, ["%"] = 3,
		["+"] = 4, ["-"] = 4,
		["<<"] = 5, [">>"] = 5,
		["<="] = 6, ["<"] = 6, [">="] = 6, [">"] = 6,
		["=="] = 7, ["!="] = 7,
		["&"] = 8,
		["^"] = 9,
		["|"] = 10,
		["&&"] = 11,
		["||"] = 12,
		["?"] = 13, [":"] = 13,
		["="] = 14,
		[","] = 15
	};
	local tokens = {};
	local i = 1;
	local useUnary = true;
	while i <= #source do
		local begin = i;
		local c = source:sub(i, i);
		if c:find("[A-Za-z_]") then
			local noniden = source:find("[^A-Za-z_0-9]", i) or (#source + 1);
			i = noniden - 1;
			table.insert(tokens, source:sub(begin, i));
			useUnary = false;
		elseif c:find("[0-9]") then
			i = (source:find("[^0-9A-Za-z.]", i) or (#source + 1)) - 1;
			table.insert(tokens, source:sub(begin, i));
			useUnary = false;
		elseif c == "'" or c == '"' then
			local escaped = false;
			for j = begin + 1, #source do
				local q = source:sub(j, j);
				if escaped then
					escaped = false;
				elseif q == "\\" then
					escaped = true;
				elseif q == c then
					i = j;
					break;
				end
			end
			table.insert(tokens, source:sub(begin, i));
		elseif c == "[" or c == "(" or c == ")" or c == "]" then
			table.insert(tokens, c);
			useUnary = c == "[" or c == "(";
		elseif useUnary and precedence["u" .. c] then
			table.insert(tokens, "u" .. c);
			useUnary = true;
		elseif precedence[source:sub(begin, i + 1)] and i < #source then
			-- a 2 char operator
			i = i + 1;
			table.insert(tokens, source:sub(begin, i));
			useUnary = true;
		elseif precedence[c] then
			-- a 1 char operator
			table.insert(tokens, c);
			useUnary = true;
		elseif c:find("%S") then
			error("Unhandled `" .. c .. "`");
		end
		i = i + 1;
	end
	-- Casting
	local types = {"int", "char"}; -- And any amount of stars
	for i = #tokens, 1, -1 do
		if tokens[i] == "(" then
			local inside;
			for j = i + 1, #tokens do
				if tokens[j] == ")" then
					inside = j - 1;
					break;
				elseif tokens[j] == "(" then
					break;
				end
			end
			if inside then
				local parend = {};
				for j = i + 1, inside do
					table.insert(parend, tokens[j]);
				end
				-- 
				if table.find(types, parend[1]) then
					-- Now all remaining must be * or u*
					local starsOnly = true;
					for j = 2, #parend do
						if not parend[j]:find("%*") then
							starsOnly = false;
							break;
						end
					end
					if starsOnly then
						-- Represents a cast!
						for j = 1, #parend + 2 do
							table.remove(tokens, i);
						end
						local op = "ucast" .. parend[1] .. ("*"):rep(#parend - 1);
						table.insert(tokens, i, op);
						precedence[op] = 2;
					end
				end
			end
		end
	end
	for i = #tokens, 1, -1 do
		if tokens[i] == "(" then
			-- If left of it is not open brace or operator...
			local left = tokens[i - 1];
			if left and left ~= "[" and left ~= "(" and not precedence[left] then
				table.insert(tokens, i, "@@@");
			end
		elseif tokens[i] == "[" then
			-- If left of it is not open brace or operator...
			local left = tokens[i - 1];
			if left and left ~= "[" and left ~= "(" and not precedence[left] then
				table.insert(tokens, i, "$$$");
			else
				error("Square braces used improperly");
			end
		elseif tokens[i] == "," then
			if tokens[i-1] == "(" or tokens[i-1] == "[" or tokens[i-1] == ","
				or precedence[tokens[i-1]] then
				error("Comma not preceded by value");
			end
		elseif tokens[i] == ")" or tokens[i] == "]" then
			if tokens[i - 1] == "," then
				error("Parenthesis may not be preceded by comma");
			end
		end
	end
	local out = {};
	local stack = {};
	local open = {"[", "("}; -- Need?
	local arity = {};
	function move()
		local r = table.remove(stack);
		if r == "@@@" then
			r = "@" .. table.remove(arity);
		end
		if r == "$$$" then
			table.insert(out, "+"); -- Array indexing is sum followed by deref
			r = "u*";
		end
		table.insert(out, r);
	end
	for i = 1, #tokens do
		local token = tokens[i];
		if token == "," then -- Argument separator
			arity[#arity] = arity[#arity] + 1;
			while stack[#stack] ~= "(" and stack[#stack] do
				move();
			end
		elseif token == "(" or token == "[" then
			table.insert(stack, token);
		elseif token == ")" or token == "]" then
			if tokens[i - 1] == "(" then
				arity[#arity] = 0;
				if tokens[i - 2] ~= "@@@" then
					error("Empty parenthesis () not used in function call");
				end
			end
			while stack[#stack] ~= "(" and stack[#stack] ~= "[" and stack[#stack] do
				move();
			end
			table.remove(stack) -- Pop open paren off
		elseif precedence[token] then
			-- An operator
			if token == "@@@" then
				table.insert(arity, 1);
			end
			local prec = precedence[token];
			while #stack > 0 and precedence[stack[#stack]] and prec >= precedence[stack[#stack]] do
				move();
			end
			table.insert(stack, token);
		else
			table.insert(out, token); -- Any other atom
		end
	end
	while #stack > 0 do
		if not precedence[stack[#stack]] then
			error("Unmatched parenthesis near " .. table.concat(stack, ","));
		end
		move();
	end
	return out;
end


-- print(table.concat(parseExpression("  (str[i] != 0)   " ), " "))
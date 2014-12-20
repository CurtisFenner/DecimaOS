function flip(c)
	local flips = {};
	flips["("] = ")";
	flips[")"] = "(";
	flips["["] = "]";
	flips["]"] = "[";
	flips["{"] = "}";
	flips["}"] = "{";
	return flips[c] or c;
end

function eSemicoloned(source, i)
	return eCharactered(source, i, ";");
end

function eCharactered(source, i, character)
	local quoted, escaped = false, false;
	local parenStack = {};
	local begin = i;
	while i <= #source do
		local c = source:sub(i, i);
		if quoted then
			if c == quoted and not escaped then
				quoted = false;
			end
			if c == "\\" then
				escaped = true;
			else
				escaped = false;
			end
		elseif c == "(" or c == "[" then
			table.insert(parenStack, c);
		elseif c == ")" or c == "]" then
			if #parenStack == 0 then
				errorAt("Unpaired '" .. c .. "' paren", source, i);
			end
			local top = table.remove(parenStack);
			if top ~= flip(c) then
				errorAt(top .. " and " .. c .. " don't match", source, i);
			end
		elseif c == "'" or c == '"' then
			quote = c;
		elseif c == character then
			if #parenStack ~= 0 then
				errorAt("Unclosed parenthesis: "
					.. table.concat(parenStack, ", "), source, i);
			end
			-- Statement finished
			return i + 1, source:sub(begin, i - 1);
		end
		i = i + 1;
	end
	errorAt("No " .. character .. " ending statement", source, i);
end
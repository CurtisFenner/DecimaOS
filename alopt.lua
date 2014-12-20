function readFile(fname)
	local lines = {};
	for line in io.lines(fname) do
		table.insert(lines, line);
	end
	return lines;
end


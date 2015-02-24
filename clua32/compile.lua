function compile(identifiers)
	print("\n\ncompile(",identifiers,")");
	for i,v in pairs(identifiers) do
		print("", i, "","",v);
	end

	return "\n\n\n; compile(identifiers)\n\n\n"
end
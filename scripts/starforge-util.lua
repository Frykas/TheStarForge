if not nebUtil then
  nebUtil = {}
  
  --Initialises every parameter listed in the table, useful for mass grabbing with no default
  function nebUtil.getParameters(parameters)
	for _, i in ipairs(parameters) do
      self[i] = config.getParameter(i)
    end
  end
	
  --Copy a table
  function nebUtil.copyTable(table, count)
	local ret = {};
	for k,v in pairs(table) do
	  if type(v) == "table" then
		if count > 10 then
		  sb.logInfo("%s", k);
		  ret[k] = nebUtil.copyTable(v, count + 1);
	    end
	  else
	 	ret[k] = v;
	  end
	end
    return ret;
  end
end
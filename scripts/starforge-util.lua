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
	local ret = {}
	for k, v in pairs(table) do
	  if type(v) == "table" then
		if count > 10 then
		  --sb.logInfo("%s", k)
		  ret[k] = nebUtil.copyTable(v, count + 1)
	    end
	  else
	 	ret[k] = v
	  end
	end
    return ret
  end
  
  --Multiply tables
  function nebUtil.multiplyTables(table1, table2)
    local multipliedTable = nebUtil.copyTable(table1, 11)
	for k, v in pairs(multipliedTable) do
	  if table2[k] then
        multipliedTable[k] = table1[k] * table2[k]
	  end
	end
    return multipliedTable
  end
  
  function nebUtil.tableSize(table)
    local size = 0
	for _, x in ipairs(table) do
	  size = size + 1
	end
    return size
  end
  
  --Find index
  function nebUtil.findIndex(table, value)
    for i, v in ipairs(table) do
      if v == value then
        return i
      end
    end
    return nil
  end
end
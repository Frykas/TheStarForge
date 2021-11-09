if not nebUtil then
  nebUtil = {};
  
  --Initialises every parameter listed in the table, useful for mass grabbing with no default
  function nebUtil.getParameters(parameters)
	for _, i in ipairs(parameters) do
      self[i] = config.getParameter(i)
    end
  end
end
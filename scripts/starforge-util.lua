if not nebUtil then
  nebUtil = {}
  
  --Initialises every parameter listed in the table, useful for mass grabbing with no default
  function nebUtil.getParameters(parameters)
    for _, i in ipairs(parameters) do
      self[i] = config.getParameter(i)
    end
  end
  
  function nebUtil.findPointsInPoly(poly)
    local first = poly[1]
    if not first then return {} end
    local contains = world.polyContains
    local minX, maxX = first[1], first[1]
    local minY, maxY = first[2], first[2]
    for i = 1, #poly do
      local point = poly[i]
      local x, y = point[1], point[2]
      if     minX > x then minX = x
      elseif maxX < x then maxX = x end
      if     minY > y then minY = y
      elseif maxY < y then maxY = y end
    end
    local t = {}
    local tI = 0
    for x = math.ceil(minX - 0.5), math.floor(maxX - 0.5) do
      for y = math.ceil(minY - 0.5), math.floor(maxY - 0.5) do
        if contains(poly, {x + 0.5, y + 0.5}) then
          tI = tI + 1
          t[tI] = vec2.add(mcontroller.position(), {x, y})
        end
      end
    end
    return t
  end
  
  --Copy a table -- thanks C0bra5
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
  
  --Find size of tabe
  function nebUtil.objectSize(table)
    local size = 0
    for _, _ in pairs(table) do
      size = size + 1
    end
    return size
  end
  
  function nebUtil.randomLetterKey(list, seed)
    return string.char(96 + (seed % nebUtil.objectSize(list)) + 1)
  end
  
  --Check if table contains a value
  function nebUtil.tableContains(table, key)
    for _, v in ipairs(table) do
      if v == key then
        return key
      end
    end
    return false
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
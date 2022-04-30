if not nebTimeUtil then
  nebTimeUtil = {}
  
  --Neb's Stuff
  function nebTimeUtil.formatDay(day)
	if day == 0 then
	  return "Sunday"
	elseif day == 1 then
	  return "Monday"
	elseif day == 2 then
	  return "Tuesday"
	elseif day == 3 then
	  return "Wednesday"
	elseif day == 4 then
	  return "Thursday"
	elseif day == 5 then
	  return "Friday"
	elseif day == 6 then
	  return "Saturday"
	else
	  return "Unknown"
	end
  end
  
  function nebTimeUtil.getCurrentWeekDay()
    --The Doomsday Algorithm by John Conway
	--Translated to lua by Nebulox and simplified a bit
	--0 - 6, where 0 is sunday, and 6 is saturday
    local currentYear, currentMonth, currentDay = nebTimeUtil.getCurrentYearMonthDay()
	
	local currentYearSince2000 = currentYear - 2000
	
    local doomsdayForCentury = nebTimeUtil.calculateCenturyDoomsday(currentYear)
	local times12FitsIntoYear = math.floor(currentYearSince2000 / 12)
	local remainder = currentYearSince2000 - (times12FitsIntoYear * 12)
	local times4FitsIntoRemainder = math.floor(remainder / 4)
	
	local total = doomsdayForCentury + times12FitsIntoYear + remainder + times4FitsIntoRemainder
	
	local times7FitsIntoTotal = math.floor(total / 7)
	local remainderOfTotal = total - (times7FitsIntoTotal * 7)
	
	local doomsdayIndexForYear = remainderOfTotal --The day 0 - 6 sun-sat

	local dayOfJan = currentDay % 7 --Convert to the date of January, for example Aug 5th is Jan 7th
	local offsetDay = dayOfJan - 3 -- + (nebTimeUtil.checkLeapYear(currentYear) and 1 or 0) --Take the doomsday of the January
	local weekDay = (doomsdayIndexForYear + offsetDay) % 7 --This will be the day index
	
	return weekDay
  end
  
  --Find the doomsday of the century, for example 2000 is tuesday, or 2
  function nebTimeUtil.calculateCenturyDoomsday(year)
	local centuryStartingPoints = {
	  [1000] = 5,
	  [1100] = 3,
	  [1200] = 2,
	  [1300] = 0,
	  [1400] = 5,
	  [1500] = 3,
	  [1600] = 2,
	  [1700] = 0,
	  [1800] = 5,
	  [1900] = 3,
	  [2000] = 2,
	  [2100] = 0,
	  [2200] = 5,
	  [2300] = 3,
	  [2400] = 2,
	  [2500] = 0,
	  [2600] = 5,
	  [2700] = 3,
	  [2800] = 2,
	  [2900] = 0,
	  [3000] = 5
	}
	year = tonumber(tostring(year):sub(1, 2) .. "00")
	if centuryStartingPoints[year] then
	  return centuryStartingPoints[year]
	else
	  local yearsDifference = year - 3000
	  if yearsDifference % 400 == 0 then
		return 5
	  else
		local remainder = yearsDifference % 400
		if remainder == 100 then
		  return 3
		elseif remainder == 200 then
		  return 2
		elseif remainder == 300 then
		  return 0
		end
	  end
	end
  end

  function nebTimeUtil.isDayWithin(day, range)
	if range[2] < range[1] then --If week or year has looped
	  if (day > range[1]) and (day > range[2]) then
	    return true
	  elseif (day < range[1]) and (day < range[2]) then
		return true
	  end
	elseif (day > range[1]) and (day < range[2]) then
	  return true
	end
	
    return false
  end

  
  --Aegonian's Stuff below - modified by Nebulox
  function nebTimeUtil.getCurrentYearMonthDay()
    --Calculate current year by checking difference between timeStamps between now and the start of 2000
    --Must use this method as start time of os.time() is unknown and possibly variable, and os.date() is unavailable in Starbound's version of LUA
    local yearsSince2000 = (os.time() - os.time{year=2000, month=1, day=1, hour=0, sec=0}) / 31557600
    local yearsSinceYearStart = yearsSince2000 - math.floor(yearsSince2000)
    local currentYear = math.floor(yearsSince2000 + 2000)
	
	local daysThisYear = 365
    local leapYear = nebTimeUtil.checkLeapYear(currentYear)
    if leapYear then
	  daysThisYear = 366
    end
  
    --Calculate current month and day of the year
    local currentMonth = math.ceil(yearsSinceYearStart * 12)
    local currentDay = math.ceil(yearsSinceYearStart * daysThisYear)
    
    return currentYear, currentMonth, currentDay
  end

  --This function is used to calculate whether the current year is a leap year or not
  function nebTimeUtil.checkLeapYear(year)
    local isLeapYear = false
    
    --To check for leap years, see if the current year is evenly divisible by 4, then 100, then 400
    if (year % 4) == 0 then
      if (year % 100) == 0 then
        if (year % 400) == 0 then
          isLeapYear = true
        else
          isLeapYear = false
        end
      else
        isLeapYear = true
      end
    else
      isLeapYear = false
    end
    
    return isLeapYear
  end
end
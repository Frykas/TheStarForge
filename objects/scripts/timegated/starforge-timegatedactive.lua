require "/scripts/starforge-timeutil.lua"

function init()
  self.dayType = config.getParameter("dayType", "weekday")
  self.day = (self.dayType == "weekday") and nebTimeUtil.getCurrentWeekDay() or currentYearDay()
  --sb.logInfo("Current day: %s", nebTimeUtil.formatDay(self.day))
  --sb.logInfo("Active from %s until %s", nebTimeUtil.formatDay(config.getParameter("startEndWeekdays", {0, 6})[1]), nebTimeUtil.formatDay(config.getParameter("startEndWeekdays", {0, 6})[2]))
  self.active = isActive(self.day, self.dayType)
  
  object.setInteractive(self.active and config.getParameter("interactiveWhenActive", false) or false)
  animator.setAnimationState("objectState", self.active and "active" or "inactive")
end

function currentYearDay()
  local year, month, day = nebTimeUtil.getCurrentYearMonthDay()
  return day
end

function isActive(day, dayType)
  nebTimeUtil.isDayWithin(day, (dayType == "weekday") and config.getParameter("startEndWeekdays", {90, 90}) or config.getParameter("startEndWeekdays", {0, 6}))
end
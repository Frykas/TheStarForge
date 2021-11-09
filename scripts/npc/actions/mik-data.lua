-- param key
-- param stringValue
-- param numValue
-- param entityValue
-- param boolValue
function setSelfValue(args, output, _, dt)
  if not args.key then return false end
  local toSet = args.stringValue or args.numValue or args.entityValue or args.boolValue
  self[args.key] = toSet
  return true
end
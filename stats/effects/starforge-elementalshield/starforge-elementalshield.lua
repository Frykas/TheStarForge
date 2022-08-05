local enum = {
  1 = "physical",
  2 = "fire",
  3 = "ice",
  4 = "electric",
  5 = "godflame",
  6 = "wither",
  7 = "tidalfrost",
  8 = "surge",
  9 = "spirit",
  10 = "dung"
}

function init()
  local element = enum[math.floor(effect.duration())]
  sb.logInfo("Element of shield is: %s", element)
end

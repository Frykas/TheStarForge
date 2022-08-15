if not c5Easing then
  c5Easing = {}
  
  function c5Easing.lerp(progress, from, to)
    return from + (to - from) * progress
  end
  
  -- clamps progress between 1 and 0
  function c5Easing.limitProg(progress)
    return math.min(1, math.max(0, progress))
  end
  
  -- an equal amount of ease in
  function c5Easing.easeInOut(progress, from, to)
    return c5Easing.lerp(c5Easing.calcSig(c5Easing.limitProg(progress), 12, 1, 0.5, 0), from, to)
  end
  
  function c5Easing.easeOut(progress, from, to)
    return c5Easing.lerp(c5Easing.calcSig(c5Easing.limitProg(progress), 6, 2, 0, -0.5), from, to)
  end
  
  function c5Easing.easeIn(progress, from, to)
    return c5Easing.lerp(c5Easing.calcSig(c5Easing.limitProg(progress), 6, 2, 1, 0), from, to)
  end
  
  function c5Easing.customEase(progress, from, to, xMult, yMult, xOffset, yOffset)
    return c5Easing.lerp(c5Easing.calcSig(c5Easing.limitProg(progress), xMult, yMult, xOffset, yOffset), from, to)
  end
  
  function c5Easing.calcSig(progress, xMult, yMult, xOffset, yOffset)
    -- latex = y=y_{m}\left(\frac{1}{\left(1+\exp\left(-x_{m}\left(x-x_{o}\right)\right)\right)}+y_{o}\right)
    return yMult * ( ( 1 / ( 1 + math.exp( -xMult * ( progress - xOffset ) ) ) ) + yOffset )
  end
end
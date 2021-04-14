StarForgeActivateBlade = WeaponAbility:new()

function StarForgeActivateBlade:init()
  self.cooldownTimer = self.cooldownTime

  self.active = false
end

function StarForgeActivateBlade:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.active and not status.overConsumeResource("energy", self.energyPerSecond * self.dt) then
    self.active = false
  end

  if fireMode == "alt"
      and not self.weapon.currentAbility
      and self.cooldownTimer == 0
      and not status.resourceLocked("energy") then

      self:setState(self.empower)
  end
end

function StarForgeActivateBlade:empower()
  util.wait(self.durationBefore)

  animator.playSound("empower")
  self.active = (not self.active)

  util.wait(self.durationAfter)
end

function StarForgeActivateBlade:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function StarForgeActivateBlade:uninit()
end
require "/scripts/util.lua"

function init()
  animator.setAnimationState("portal", "idle")
  object.setLightColor({0, 0, 0, 0})

  storage.uuid = storage.uuid or sb.makeUuid()
  object.setInteractive(true)

  message.setHandler("onTeleport", function(message, isLocal, data)
      if not config.getParameter("returnDoor") and not storage.vanishTime then
        storage.vanishTime = world.time() + config.getParameter("vanishTime")
        if not (animator.animationState("portal") == "active" or animator.animationState("portal") == "activate") then
          animator.setAnimationState("portal", "active")
        end
      end
    end)

  if config.getParameter("messagePlayerInterval") then
    self.radioMessage = util.interval(config.getParameter("messagePlayerInterval"), function()
      local nearPlayers = world.entityQuery(object.position(), config.getParameter("messagePlayerRange"), {includedTypes = {"player"}})
      nearPlayers = util.filter(nearPlayers, entity.entityInSight)
      for _,playerId in pairs(nearPlayers) do
        world.sendEntityMessage(playerId, "queueRadioMessage", "starforge-menageriegate")
      end
    end)
  end
end

function update(dt)
  if self.radioMessage ~= nil then
    self.radioMessage(dt)
  end

  local players = world.entityQuery(object.position(), config.getParameter("messagePlayerRange"), {
      includedTypes = {"player"},
      boundMode = "CollisionArea"
    })

  if #players > 0 and animator.animationState("portal") == "idle" then
    animator.setAnimationState("portal", "activate")
    animator.playSound("on")
    object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
  elseif #players == 0 and animator.animationState("portal") == "active" then
    animator.setAnimationState("portal", "broken")
    animator.playSound("off")
    object.setLightColor({0, 0, 0, 0})
  end
end

function onInteraction(args)
  if config.getParameter("returnDoor") then
    return { "OpenTeleportDialog", {
        canBookmark = false,
        includePlayerBookmarks = false,
        destinations = { {
          name = "Exit Portal",
          planetName = "Return to World... Hopefully!",
          icon = "return",
          warpAction = "Return"
        } }
      }
    }
  else
    return { "OpenTeleportDialog", {
        canBookmark = false,
        includePlayerBookmarks = false,
        destinations = { {
          name = "Challenge Portal",
          planetName = "Unstable Pocket Dimension",
          icon = "default",
          warpAction = string.format("InstanceWorld:challengerooms:%s:%s", storage.uuid, world.threatLevel())
        } }
      }
    }
  end
end

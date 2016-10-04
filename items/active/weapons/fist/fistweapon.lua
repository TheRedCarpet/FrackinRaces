require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/items/active/weapons/weapon.lua"

function init()
  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  local comboFinisherConfig = config.getParameter("comboFinisher")
  self.comboFinisher = getAbility("comboFinisher", comboFinisherConfig)
  self.weapon:addAbility(self.comboFinisher)

  self.weapon:init()

  self.needsEdgeTrigger = config.getParameter("needsEdgeTrigger", false)
  self.edgeTriggerGrace = config.getParameter("edgeTriggerGrace", 0)
  self.edgeTriggerTimer = 0
  
  self.comboStep = 0
  self.comboSteps = config.getParameter("comboSteps")
  self.comboTiming = config.getParameter("comboTiming")
  self.comboCooldown = config.getParameter("comboCooldown")

  self.weapon.freezeLimit = config.getParameter("freezeLimit", 2)
  self.weapon.freezesLeft = self.weapon.freezeLimit
  
  self.blockCount = 0
  self.blockCount2 = 0
  
  updateHand()
end

function update(dt, fireMode, shiftHeld)
  if mcontroller.onGround() then
    self.weapon.freezesLeft = self.weapon.freezeLimit
  end

  if self.comboStep > 0 then
    self.comboTimer = self.comboTimer + dt
    if self.comboTimer > self.comboTiming[2] then
      resetFistCombo()
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= "primary" and fireMode == "primary" then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if fireMode == "primary" and (not self.needsEdgeTrigger or self.edgeTriggerTimer > 0) then
    if self.comboStep > 0 then  
    
     	-- *************** FR SPECIAL ********************************
     	   -- ***** bonus defense when swinging two fist weapons
 	   if self.blockCount == nil then 
 	     self.blockCount = 0.01
 	   end    	
 	     
             if world.entitySpecies(activeItem.ownerEntityId()) == "bunnykin" then
               self.blockCount = self.blockCount + 0.5
               status.setPersistentEffects("fistbonusdmg", {{stat = "grit", amount = self.blockCount}}) 
               status.setPersistentEffects("fistbonusdmg2", {{stat = "protection", amount = self.blockCount}})
             end      
             
 	   -- ***** bonus attack when swinging two fist weapons
 	   if self.blockCount2 == nil then 
 	     self.blockCount2 = 0.003
 	   end    	
 	     -- ***** bonus defense when swinging two fist weapons
             if world.entitySpecies(activeItem.ownerEntityId()) == "munari" then
               self.blockCount2 = self.blockCount2 + 0.0045
               status.setPersistentEffects("munaribonusdmg", {{stat = "powerMultiplier", amount = self.blockCount2}})
             end      	     
             
 	     -- ***** life leech when swinging two fist weapons
 	     -- ***** knockback increase with each swing of fist weapon
 	     -- ***** increased immunity after damage
 	     
        -- **********************************************************  
        
      if self.comboTimer >= self.comboTiming[1] then        
        if self.comboStep % 2 == 0 then
          if self.primaryAbility:canStartAttack() then
            if self.comboStep == self.comboSteps then
              -- sb.logInfo("[%s] %s fist starting a combo finisher", os.clock(), activeItem.hand())
              self.comboFinisher:startAttack()
            else
              self.primaryAbility:startAttack()
              -- sb.logInfo("[%s] %s fist continued the combo", os.clock(), activeItem.hand())
              advanceFistCombo()
            end
          end
        elseif activeItem.callOtherHandScript("triggerComboAttack", self.comboStep) then
          -- sb.logInfo("[%s] %s fist triggered opposing attack", os.clock(), activeItem.hand())
          advanceFistCombo()
        end
      end   
    else 
      if self.primaryAbility:canStartAttack() then          
        self.primaryAbility:startAttack()      
        if activeItem.callOtherHandScript("resetFistCombo") then
          -- sb.logInfo("[%s] %s fist started a combo", os.clock(), activeItem.hand())
          advanceFistCombo()         
        end
      end
    end
  end

  self.weapon:update(dt, fireMode, shiftHeld) 
  updateHand()
end

function uninit()
  if unloaded then
    activeItem.callOtherHandScript("resetFistCombo")
    status.clearPersistentEffects("fistbonusdmg")
    status.clearPersistentEffects("fistbonusdmg2")
    status.clearPersistentEffects("munaribonusdmg")
    self.blockCount = 0
    self.blockCount2 = 0
  end
  self.weapon:uninit()
  
end

-- update which image we're using and keep the weapon visually in front of the hand
function updateHand()
  local isFrontHand = self.weapon:isFrontHand()
  animator.setGlobalTag("hand", isFrontHand and "front" or "back")
  animator.resetTransformationGroup("swoosh")
  animator.scaleTransformationGroup("swoosh", isFrontHand and {1, 1} or {1, -1})
  activeItem.setOutsideOfHand(isFrontHand)
end

-- called remotely to attempt to perform a combo-continuing attack
function triggerComboAttack(comboStep)
  if self.primaryAbility:canStartAttack() then
    -- sb.logInfo("%s fist received combo trigger for combostep %s", activeItem.hand(), comboStep)
    if comboStep == self.comboSteps then    
      self.comboFinisher:startAttack()    
    else
      self.primaryAbility:startAttack()
    end
    return true
  else
    return false
  end
end

-- advance to the next step of the combo
function advanceFistCombo()
  self.comboTimer = 0
  if self.comboStep < self.comboSteps then
    -- sb.logInfo("%s fist advancing combo from step %s to %s", activeItem.hand(), self.comboStep, self.comboStep + 1)
    self.comboStep = self.comboStep + 1
 
  end
end

-- interrupt the combo for various reasons
function resetFistCombo()
  -- sb.logInfo("%s fist resetting combo from step %s to 0", activeItem.hand(), self.comboStep)
  self.comboStep = 0
  self.comboTimer = nil
    status.clearPersistentEffects("fistbonusdmg")
    status.clearPersistentEffects("fistbonusdmg2") 
    status.clearPersistentEffects("munaribonusdmg")
    self.blockCount = 0
    self.blockCount2 = 0
  return true
end

-- complete the combo, reset and trigger cooldown
function finishFistCombo()
  resetFistCombo()
  self.primaryAbility.cooldownTimer = self.comboCooldown
end
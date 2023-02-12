--
-- trailerAssist
-- This is the specialization for trailerAssist
--

--***************************************************************
source(Utils.getFilename("mogliBase.lua", g_currentModDirectory))
_G[g_currentModName..".mogliBase"].newClass( "trailerAssist" )
--***************************************************************

function trailerAssist.globalsReset( createIfMissing )

	trailerAssistGlobals = {}

	trailerAssistGlobals.defaultMode       = 0
	trailerAssistGlobals.minMode           = 0
	trailerAssistGlobals.maxMode           = 0
	trailerAssistGlobals.minJointRotLimit  = 0
	trailerAssistGlobals.steeringFactor1   = 0
	trailerAssistGlobals.steeringFactor2   = 0
	trailerAssistGlobals.steeringSpeed     = 0
	trailerAssistGlobals.rotScale          = 0
	trailerAssistGlobals.worldScale        = 0
	trailerAssistGlobals.minWorldScale     = 0
	trailerAssistGlobals.autoRotateBack    = 0
	trailerAssistGlobals.steeringSpeed     = 0
	trailerAssistGlobals.minSteeringSpeed  = 0
	trailerAssistGlobals.maxSumDtCalc      = 0
	trailerAssistGlobals.maxSumDtDisp      = 0
	trailerAssistGlobals.speedLimit        = 0
	trailerAssistGlobals.maxToolDegrees    = 0
	trailerAssistGlobals.maxWorldRatio     = 0
	trailerAssistGlobals.xPosCenter        = 0
	trailerAssistGlobals.yPosTop           = 0
	trailerAssistGlobals.textSize          = 0
	trailerAssistGlobals.invertReverse     = true
	
	trailerAssistGlobals.debug             = false

	local file
	file = trailerAssist.baseDirectory.."trailerAssistConfig.xml"
	if fileExists(file) then	
		trailerAssist.globalsLoad( file, "trailerAssistGlobals", trailerAssistGlobals )	
	else
		print("ERROR: NO GLOBALS IN "..file)
	end
	
	file = getUserProfileAppPath().. "modSettings/trailerAssistConfig.xml"
	if fileExists(file) then	
		print('Loading "'..file..'"...')
		trailerAssist.globalsLoad( file, "trailerAssistGlobals", trailerAssistGlobals )	
	end

	trailerAssistGlobals.mathPi2           = 0.5 * math.pi
end

trailerAssist.globalsReset( false )

function trailerAssist.debugPrint( ... )
	if trailerAssistGlobals.debug then
		print( ... )
	end
end



function trailerAssist.prerequisitesPresent(specializations)
	return true
end

function trailerAssist.registerEventListeners(vehicleType)
	for _,n in pairs( { "onLoad", 
											"onUpdate", 
											"onUpdateTick", 
											"onDraw",
											"onLeaveVehicle",
											"onRegisterActionEvents" } ) do
		SpecializationUtil.registerEventListener(vehicleType, n, trailerAssist)
	end 
end 




--***************************************************************
-- load
--***************************************************************
function trailerAssist:onLoad(saveGame)
	self.taLastRatio  = 0
	self.taSumDtCalc  = 0
	self.taSumDtDisp  = 0
	self.isSelectable = true
	self.taWorldAngle = nil
	self.taLastAngle  = 0
	self.taLastMovingDirection = 0
	
	trailerAssist.registerState( self, "taModeStatic",   trailerAssistGlobals.defaultMode, nil, true )	
	trailerAssist.registerState( self, "taMode",         trailerAssistGlobals.defaultMode, trailerAssist.onSetMode )	
	trailerAssist.registerState( self, "taIsPossible",   false )	
	trailerAssist.registerState( self, "taDisplayAngle", 0 )	
	trailerAssist.registerState( self, "taWorldDispAngle", 0 )	 
	trailerAssist.registerState( self, "taDirectionBits", 0 )	 
	trailerAssist.registerState( self, "taAxisSide", 0 )	 
	trailerAssist.registerState( self, "taMovingDirection", 0 )	 
end

--***************************************************************
-- draw
--***************************************************************
function trailerAssist:onDraw()
	local helpText = ""
	
	if trailerAssist.isActive( self ) then
	
		if trailerAssist.backgroundOverlayId == nil then
			trailerAssist.backgroundOverlayId    = createImageOverlay( Utils.getFilename( "dds/bg.dds", g_trailerAssist.taDirectory))
			setOverlayColor( trailerAssist.backgroundOverlayId, 0,0,0, 0.4 )
		end

		setTextAlignment(RenderText.ALIGN_CENTER) 
		
		setTextColor(1, 1, 0, 1) 
		setTextBold(true)
		
		local uiScale = trailerAssist.getUiScale()		
		local hudPos  = { 0, 0, 0, 0 }
		local txtPos  = { trailerAssistGlobals.xPosCenter, trailerAssistGlobals.yPosTop - trailerAssistGlobals.textSize * 1.1, trailerAssistGlobals.textSize, "<error>" }
		
		if txtPos[3] < 0.01 then
			txtPos[3] = 0.01
		end
		
		local border  = txtPos[3] * 0.1	
		local xFactor = math.max( txtPos[3], 0.02 )
		local yFactor = 0.5625 * g_screenAspectRatio * uiScale
		local yBorder = border * yFactor 
		local version = 0.01   * yFactor 
		
		txtPos[2] = trailerAssist.mbClamp( trailerAssistGlobals.yPosTop - 1.1 * txtPos[3], 0, 1 - 1.1 * txtPos[3] )
		txtPos[1] = trailerAssist.mbClamp( trailerAssistGlobals.xPosCenter, 1.5 * xFactor + border, 1 - 1.5 * xFactor - border )
		
		if self.taMode == 1 then
			hudPos[3] = 3 * xFactor + 2 * border
			txtPos[4] = string.format( "%2d° / %2d°", self.taDisplayAngle, self.taWorldDispAngle ) 
		else
			hudPos[3] = 2 * xFactor + 2 * border 
			txtPos[4] = string.format( "%2d°", self.taDisplayAngle )
		end
		
		helpText = txtPos[4]
		
		if txtPos[2] < 0.5 then
			txtPos[2] = txtPos[2] * yFactor 
		else
			txtPos[2] = 1 - ( 1 - txtPos[2] ) * yFactor 
		end
		txtPos[3] = txtPos[3] * yFactor 
		
		hudPos[2] = txtPos[2] - version - 3 * yBorder
		hudPos[3] = hudPos[3] * uiScale 
		hudPos[4] = txtPos[3] + version + 3 * yBorder
		hudPos[1] = txtPos[1] - 0.5 * hudPos[3]
		
		
		renderOverlay( trailerAssist.backgroundOverlayId, unpack( hudPos ) )
		renderText( unpack( txtPos ) )
		
		setTextColor(1, 1, 1, 1) 
		setTextBold(false)
		
		txtPos[3] = version
		txtPos[2] = txtPos[2] - version - yBorder 
		txtPos[4] = trailerAssist.getText("taVERSION")
		
		renderText( unpack( txtPos ) )

		setTextAlignment(RenderText.ALIGN_LEFT) 
--else
--	if     self.taDirectionBits == 1 then 
--		helpText = "trailerAssist back"
--	elseif self.taDirectionBits == 2 then 
--		helpText = "trailerAssist front"
--	elseif self.taDirectionBits == 3 then 
--		helpText = "trailerAssist both"
--	end	
	end	
	
	if helpText ~= nil and helpText ~= "" then 
		g_currentMission:addExtraPrintText( helpText )
	end 
end

function trailerAssist:afterDrivableSetSteeringInput(inputValue, isAnalog, deviceCategory)
	self.taSteeringInput = inputValue		
end 

Drivable.setSteeringInput = Utils.appendedFunction( Drivable.setSteeringInput, trailerAssist.afterDrivableSetSteeringInput )

--***************************************************************
-- update
--***************************************************************
function trailerAssist:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.taSteeringInput ~= nil then 
		if trailerAssist.isActive( self ) then 
			if self.taMovingDirection < 0 and not trailerAssistGlobals.invertReverse then
				trailerAssist.mbSetState( self, "taAxisSide", -self.taSteeringInput )
			else
				trailerAssist.mbSetState( self, "taAxisSide", self.taSteeringInput )
			end
		end
		self.taSteeringInput = nil 
	elseif self.isClient and isActiveForInputIgnoreSelection then 
		trailerAssist.mbSetState( self, "taAxisSide", 0 )
	end 	


	if self.isServer then
		local motor
		if self.spec_motorized ~= nil then 
			motor = self.spec_motorized.motor
		end 
		if motor == nil then 
			trailerAssist.mbSetState( self, "taMovingDirection", self.movingDirection )
		else
			trailerAssist.mbSetState( self, "taMovingDirection", motor.currentDirection )
		end 

		if self:getIsEntered() and trailerAssist.tableGetN( self.spec_attacherJoints.attachedImplements ) > 0 then
			self.taSumDtCalc = self.taSumDtCalc + dt
			if self.taSumDtCalc >= trailerAssistGlobals.maxSumDtCalc then
				trailerAssist.fillTaJoints( self )
			end
			local inTheFront, inTheBack = false, false
			if self.taJoints ~= nil then
				for _,joint in pairs( self.taJoints ) do
					if joint.inTheBack then
						inTheBack  = true
					else
						intheFront = true
					end
				end
			end
			if inTheFront and inTheBack then
				trailerAssist.mbSetState( self, "taDirectionBits", 3 )
			elseif inTheFront then
				trailerAssist.mbSetState( self, "taDirectionBits", 2 )
			elseif inTheBack  then
				trailerAssist.mbSetState( self, "taDirectionBits", 1 )
			else
				trailerAssist.mbSetState( self, "taDirectionBits", 0 )
			end
		elseif self.taJoints ~= nil then
			trailerAssist.mbSetState( self, "taIsPossible", false )
			trailerAssist.mbSetState( self, "taDirectionBits", 0 )
			self.taJoints = nil
		end
	end
end 

function trailerAssist:onLeaveVehicle()
	trailerAssist.mbSetState( self, "taMode", self.taModeStatic )
end 

function trailerAssist:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	if self.isClient and self:getIsActiveForInput(true, true) then
		self.taActiveActionEvents = {}
		if self.taActionEvents == nil then 
			self.taActionEvents = {}
		else	
			self:clearActionEventsTable( self.taActionEvents )
		end 
		
		for _,actionName in pairs({ "taMODE",  
                                "taMODE1",        
                                "taMODE2" }) do
			local triggerKeyUp, triggerKeyDown, triggerAlways, isActive, displayPriority = false, true, false, self.taIsPossible, 2
			
			if     actionName == "taMODE1"
					or actionName == "taMODE2" then 
				triggerKeyUp    = true 
				displayPriority = 2
			end 
				
			local _, eventName = self:addActionEvent(self.taActionEvents, InputAction[actionName], self, trailerAssist.actionCallback, triggerKeyUp, triggerKeyDown, triggerAlways, isActive, nil);

			self.taActiveActionEvents[actionName] = isActive
			
			if      g_inputBinding                   ~= nil 
					and g_inputBinding.events            ~= nil 
					and g_inputBinding.events[eventName] ~= nil
					and displayPriority                  ~= nil then 
				g_inputBinding.events[eventName].displayPriority = displayPriority
			end
		end
	end
end

function trailerAssist:actionCallback(actionName, keyStatus, callbackState, isAnalog, isMouse, deviceCategory)
 
	trailerAssist.debugPrint(tostring(actionName)..": "..tostring(keyStatus).." ("..tostring(self.taIsPossible)..")")
	
	if self.taActiveActionEvents == nil or not self.taActiveActionEvents[actionName] then 
		return 
	end 
  
	if actionName == "taMODE" then
		if     self.taModeStatic == 0 then
			trailerAssist.mbSetState( self, "taModeStatic", trailerAssistGlobals.minMode )
		elseif self.taModeStatic <  trailerAssistGlobals.maxMode then
			trailerAssist.mbSetState( self, "taModeStatic", self.taModeStatic + 1 )
		else
			trailerAssist.mbSetState( self, "taModeStatic", 0 )
		end	
		trailerAssist.mbSetState( self, "taMode", self.taModeStatic )
	elseif actionName == "taMODE1" and keyStatus > 0 then
		if self.taModeStatic == 1 then
			trailerAssist.mbSetState( self, "taMode", 0 )
		else
			trailerAssist.mbSetState( self, "taMode", 1 )
		end
	elseif actionName == "taMODE2" and keyStatus > 0 then
		if self.taModeStatic == 2 then
			trailerAssist.mbSetState( self, "taMode", 0 )
		else
			trailerAssist.mbSetState( self, "taMode", 2 )
		end
	else
		trailerAssist.mbSetState( self, "taMode", self.taModeStatic )
	end	
end

--***************************************************************
-- updateTick 
--***************************************************************
function trailerAssist:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isServer and self.taMode > 0 then
		if math.abs( self.taMovingDirection ) > 0 then
			if self.taMovingDirection * self.taLastMovingDirection < 0 then
				self.taLastRatio  = 0
				self.taWorldAngle = nil
			end
			self.taLastMovingDirection = self.taMovingDirection
		end	
		
		if trailerAssist.isActive( self ) then
			self.taSumDtDisp = self.taSumDtDisp + dt
			if self.taSumDtDisp >= trailerAssistGlobals.maxSumDtDisp then
				self.taSumDtDisp = 0
				if self.taMode == 1 then
					if self.taWorldAngle ~= nil then					
						trailerAssist.mbSetState( self, "taDisplayAngle",   math.floor( 0.5 +  math.deg( trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle ) ) ) )
						local degree = trailerAssist.normalizeAngle( self.taWorldAngle )
						if self.taMovingDirection > 0 then
							degree = degree + math.pi
						end
						if degree < 0 then
							degree = degree + math.pi + math.pi
						end
						trailerAssist.mbSetState( self, "taWorldDispAngle", math.floor( 0.5 + math.deg( degree ) ) )
					else
						trailerAssist.mbSetState( self, "taWorldDispAngle", 0 )
					end
				else
					trailerAssist.mbSetState( self, "taDisplayAngle", math.floor( 0.5 +  math.deg( trailerAssistGlobals.maxToolDegrees * self.taLastRatio ) ) )
				end
			end
		elseif self.taDisplayAngle ~= 0 then
			self.taSumDtDisp = 0
			trailerAssist.mbSetState( self, "taDisplayAngle", 0 )
			trailerAssist.mbSetState( self, "taWorldDispAngle", 0 )
		end
	end
	
	if self.isClient and isActiveForInputIgnoreSelection then
		local actionEvent = self.taActionEvents[InputAction.taMODE]
		if actionEvent ~= nil then 
		end 
		
		local canBeActive = false 
		if      self.taIsPossible
				and self.taDirectionBits ~= nil
				and self.taDirectionBits > 0
				and math.abs( self.taMovingDirection ) > 0 then
			if      self.taMovingDirection < 0 
					and ( self.taDirectionBits == 1 or self.taDirectionBits == 3 ) then
				canBeActive = true 
			elseif  self.taMovingDirection > 0 
					and ( self.taDirectionBits == 2 or self.taDirectionBits == 3 ) then
				canBeActive = true 
			end
		end 
		
		for actionName, wasActive in pairs( self.taActiveActionEvents ) do
			local actionEvent = self.taActionEvents[InputAction[actionName]]
			if actionEvent ~= nil then 
				local isActive = false 

				local text = ""
				
				if     actionName == "taMODE" then 
					isActive = self.taIsPossible
					if     self.taModeStatic == 1 then 
						text = trailerAssist.getText("taMODE1")
					elseif self.taModeStatic == 2 then 
						text = trailerAssist.getText("taMODE2")
					else 
						text = trailerAssist.getText("taMODE0")
					end 
				elseif actionName == "taMODE1" then
					isActive = canBeActive
					if     self.taModeStatic == 1 then 
						text = trailerAssist.getText("taMODE0")
					else 
						text = trailerAssist.getText("taMODE1")
					end 
				elseif actionName == "taMODE2" then 
					isActive = canBeActive
					if     self.taModeStatic == 2 then 
						text = trailerAssist.getText("taMODE0")
					else 
						text = trailerAssist.getText("taMODE2")
					end 
				end 
				
				if isActive ~= wasActive then 
					self.taActiveActionEvents[actionName] = isActive
					g_inputBinding:setActionEventActive(actionEvent.actionEventId, isActive)
				end 
				
				g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
			end 
		end 
	end 
end

--***************************************************************
-- isActive
--***************************************************************
function trailerAssist:isActive()
	if      type( self.getIsEntered ) == "function"
			and self:getIsEntered()
			and self:getIsVehicleControlledByPlayer()
			and self.taIsPossible
			and self.taMode          ~= nil
			and self.taMode          > 0
			and self.taDirectionBits ~= nil
			and self.taDirectionBits > 0
			and math.abs( self.taMovingDirection ) > 0 then
		if      self.taMovingDirection < 0 
				and ( self.taDirectionBits == 1 or self.taDirectionBits == 3 ) then
			return true
		elseif  self.taMovingDirection > 0 
				and ( self.taDirectionBits == 2 or self.taDirectionBits == 3 ) then
			return true
		end
	end
	return false
end

--***************************************************************
-- onSetMode
--***************************************************************
function trailerAssist:onSetMode( old, new, noEventSend )
	trailerAssist.debugPrint( "onSetMode: "..tostring(new).." (was "..tostring(old)..")" )
	self.taMode = new
	
	if self.isServer and new > 0 and ( old == nil or old <= 0 ) then
		self.taLastRatio  = 0
		self.taWorldAngle = nil
		self.taDimensions = nil
		trailerAssist.fillTaJoints( self )
	end
end

--***************************************************************
-- tableGetN
--***************************************************************
function trailerAssist.tableGetN( tab )
	if type( tab ) == "table" then
		return table.getn( tab )
	end
	return 0
end	

--***************************************************************
-- calculateDimensions
--***************************************************************
function trailerAssist:calculateDimensions()
	if self.taDimensions ~= nil then
		return;
	end;
	
	if     1 == 2 then--self.acRefNode ~= nil then
		self.taRefNode = self.acRefNode 
	elseif self.aiTractorDirectionNode  ~= nil then
		self.taRefNode = self.aiTractorDirectionNode
	elseif self.aiTreshingDirectionNode ~= nil then
		self.taRefNode = self.aiTreshingDirectionNode
	else
		self.taRefNode = self.steeringAxleNode
	end
	
	self.taDimensions                  = {};
	
	self.taDimensions.maxSteeringAngle = math.rad( Utils.getNoNil( self.maxRotation, 25 ))
	self.taDimensions.radius           = Utils.getNoNil( self.maxTurningRadius, 6.25 )
	self.taDimensions.wheelBase        = math.tan( self.taDimensions.maxSteeringAngle ) * self.taDimensions.radius
	self.taDimensions.zOffset          = -0.5 * self.taDimensions.wheelBase;
	
	if      self.articulatedAxis ~= nil 
			and self.articulatedAxis.componentJoint ~= nil
      and self.articulatedAxis.componentJoint.jointNode ~= nil 
			and self.articulatedAxis.rotMax then
		_,_,self.taDimensions.zOffset = trailerAssist.getRelativeTranslation(self.taRefNode,self.articulatedAxis.componentJoint.jointNode);
		local n=0;
		for _,wheel in pairs(self.spec_wheels.wheels) do
			local x,y,z = trailerAssist.getRelativeTranslation(self.articulatedAxis.componentJoint.jointNode,wheel.driveNode);
			if n==0 then
				self.taDimensions.wheelBase = math.abs(z)
				n = 1
			else
			--self.taDimensions.wheelBase = self.taDimensions.wheelBase + math.abs(z);
			--n  = n  + 1;
				self.taDimensions.wheelBase = math.max( math.abs(z) )
			end
		end
		if n > 1 then
			self.taDimensions.wheelBase = self.taDimensions.wheelBase / n;
		end
	--self.taDimensions.maxSteeringAngle = 0.3 * (math.abs(self.articulatedAxis.rotMin)+math.abs(self.articulatedAxis.rotMax))
		self.taDimensions.maxSteeringAngle = 0.5 * (math.abs(self.articulatedAxis.rotMin)+math.abs(self.articulatedAxis.rotMax))
	else
		local left  = {};
		local right = {};
		local nl0,zl0,nr0,zr0,zlm,alm,zrm,arm,zlmi,almi,zrmi,armi = 0,0,0,0,-99,0,-99,0,99,0,99,0;
		for _,wheel in pairs(self.spec_wheels.wheels) do
			local temp1 = { getRotation(wheel.driveNode) }
			local temp2 = { getRotation(wheel.repr) }
			setRotation(wheel.driveNode, 0, 0, 0)
			setRotation(wheel.repr, 0, 0, 0)
			local x,y,z = trailerAssist.getRelativeTranslation(self.taRefNode,wheel.driveNode);
			setRotation(wheel.repr, unpack(temp2))
			setRotation(wheel.driveNode, unpack(temp1))

			local a = 0.5 * (math.abs(wheel.rotMin)+math.abs(wheel.rotMax));

			if     wheel.rotSpeed >  1E-03 then
				if x > 0 then
					if zlm < z then
						zlm = z;
						alm = a;
					end
				else
					if zrm < z then
						zrm = z;
						arm = a;
					end
				end
			elseif wheel.rotSpeed > -1E-03 then
				if x > 0 then
					zl0 = zl0 + z;
					nl0 = nl0 + 1;
				else
					zr0 = zr0 + z;
					nr0 = nr0 + 1;
				end
			else
				if x > 0 then
					if zlmi > z then
						zlmi = z;
						almi = -a;
					end
				else
					if zrmi > z then
						zrmi = z;
						armi = -a;
					end
				end
			end	
		end
		
		if zlm > -98 and zrm > -98 then
			alm = 0.5 * ( alm + arm );
			zlm = 0.5 * ( zlm + zrm );
		elseif zrm > -98 then
			alm = arm;
			zlm = zrm;
		end
		if zlmi < 98 and zrmi < 98 then
			almi = 0.5 * ( almi + armi );
			zlmi = 0.5 * ( zlmi + zrmi );
		elseif zrmi > -98 then
			almi = armi;
			zlmi = zrmi;
		end
				
		if nl0 > 0 or nr0 > 0 then
			self.taDimensions.zOffset = ( zl0 + zr0 ) / ( nl0 + nr0 );
		
			if     zlm > -98 then
				self.taDimensions.wheelBase = zlm - self.taDimensions.zOffset;
				self.taDimensions.maxSteeringAngle = alm;
			elseif zlmi < 98 then
				self.taDimensions.wheelBase = self.taDimensions.zOffset - zlmi;
				self.taDimensions.maxSteeringAngle = almi;
			else
				self.taDimensions.wheelBase = 0;
			end
		elseif zlm > -98 and zlmi < 98 then
-- all wheel steering					
			self.taDimensions.maxSteeringAngle = math.max( math.abs( alm ), math.abs( almi ) );
			local t1 = math.tan( alm );
			local t2 = math.tan( almi );
			
			self.taDimensions.zOffset   = ( t1 * zlmi - t2 * zlm ) / ( t1 - t2 );
			self.taDimensions.wheelBase = zlm - self.taDimensions.zOffset;
		else
			self.taDimensions.maxSteeringAngle = math.abs( alm )
			self.taDimensions.wheelBase        = 4;
			self.taDimensions.zOffset          = 0;
		end
	end
		
	if math.abs( self.taDimensions.wheelBase ) > 1E-3 and math.abs( self.taDimensions.maxSteeringAngle ) > 1E-4 then
		self.taDimensions.radius        = self.taDimensions.wheelBase / math.tan( self.taDimensions.maxSteeringAngle );
	elseif self.maxTurningRadius ~= nil then
		self.taDimensions.radius        = self.maxTurningRadius
	else
		self.taDimensions.radius        = 5;
	end
	
end

--***************************************************************
-- fillTaJoints
--***************************************************************
function trailerAssist:fillTaJoints()

	trailerAssist.debugPrint( "*********************************************" )
	trailerAssist.debugPrint( tostring(self.taSumDtCalc).." "..tostring(self.configFileName))

	self.taSumDtCalc  = 0
	self.taJoints = nil 
	trailerAssist.calculateDimensions( self )
	self.taJoints = trailerAssist.getTaJoints1( self, self.taRefNode, self.taDimensions.zOffset )
	
	trailerAssist.mbSetState( self, "taIsPossible", ( trailerAssist.tableGetN( self.taJoints ) > 0 ) )		
	
	trailerAssist.debugPrint( "*********************************************" )
	
end

--***************************************************************
-- getTaJoints1
--***************************************************************
function trailerAssist:getTaJoints1( refNode, zOffset )
	
	if     self.spec_attacherJoints == nil
			or trailerAssist.tableGetN( self.spec_attacherJoints.attacherJoints )     < 1
			or trailerAssist.tableGetN( self.spec_attacherJoints.attachedImplements ) < 1 then
		return
	end
	
	local taJoints
	
	for _,implement in pairs( self.spec_attacherJoints.attachedImplements ) do
		if      implement.object ~= nil 
				and implement.object.steeringAxleNode    ~= nil 
				and implement.object.spec_wheels         ~= nil
				and implement.object.spec_attacherJoints ~= nil
				and ( trailerAssist.tableGetN( implement.object.spec_wheels.wheels ) > 0
					 or trailerAssist.tableGetN( implement.object.spec_attacherJoints.attachedImplements ) > 0 ) then
					 
			local bool = ( trailerAssist.getRelativeZTranslation( refNode, implement.object.steeringAxleNode ) < zOffset )

			trailerAssist.debugPrint( tostring(trailerAssist.getRelativeZTranslation( refNode, implement.object.steeringAxleNode )) .." < "..tostring(zOffset))
			local taJoints2 = trailerAssist.getTaJoints2( self, implement, refNode, zOffset )
			local iLast     = trailerAssist.tableGetN( taJoints2 )
			if iLast > 0 then
				if taJoints == nil then
					taJoints = {}
				end
				for i,joint in pairs( taJoints2 ) do
					joint.inTheBack = bool
					if i == iLast and not bool then
						joint.otherDirection = true
					end
					table.insert( taJoints, joint )
				end
				break
			end
		end
	end
	
	return taJoints 
end

--***************************************************************
-- getComponentOfNode
--***************************************************************
function trailerAssist:getComponentOfNode( node )

	if node == nil then
		return 0
  end
	
	for i,c in pairs(self.components) do
		if c.node == node then
			return i
		end
	end
	
	local state, result = pcall( getParent, node )
	
	if state and result ~= nil then
		return trailerAssist.getComponentOfNode( self, getParent( node ) )
	else
		return 0
	end
end
	
--***************************************************************
-- getTaJoints2
--***************************************************************
function trailerAssist:getTaJoints2( implement, refNode, zOffset )

	trailerAssist.debugPrint( "Checking trailers of: "..tostring(self.configFileName))

	if     type( implement )        ~= "table"
			or type( implement.object)  ~= "table"
			or refNode                  == nil
			or self.spec_attacherJoints == nil
			or trailerAssist.tableGetN( self.spec_attacherJoints.attacherJoints ) < 1
			or implement.object.steeringAxleNode == nil then
		trailerAssist.debugPrint( "Wrong parameters passed")
		return 
	end
		
	local taJoints
	local trailer  = implement.object

	trailerAssist.debugPrint( "Trailer: "..tostring(trailer.configFileName))
	
	if      trailer.spec_attacherJoints ~= nil 
			and trailerAssist.tableGetN( trailer.spec_attacherJoints.attacherJoints )     > 0
			and trailerAssist.tableGetN( trailer.spec_attacherJoints.attachedImplements ) > 0 then
		taJoints = trailerAssist.getTaJoints1( trailer, trailer.steeringAxleNode, 0 )
	end
	
	if taJoints == nil then 
		taJoints = {}
	end
	
  local index = trailerAssist.tableGetN( taJoints ) + 1
	
	if     implement.jointRotLimit    == nil then
		trailerAssist.debugPrint( "implement.jointRotLimit is nil")
	elseif implement.jointRotLimit[2] == nil then
		trailerAssist.debugPrint( "implement.jointRotLimit[2] is nil")
	else
		trailerAssist.debugPrint( "implement.jointRotLimit[2]: "..tostring(math.floor( 0.5 + math.deg( implement.jointRotLimit[2] ))) )
	end
	
	if      implement.jointRotLimit    ~= nil
			and implement.jointRotLimit[2] ~= nil
			and implement.jointRotLimit[2] >  trailerAssistGlobals.minJointRotLimit then
		trailerAssist.debugPrint("Adding attacher joint")
		table.insert( taJoints, index,
									{ nodeVehicle  = self.spec_attacherJoints.attacherJoints[implement.jointDescIndex].rootNode, --refNode, 
										nodeTrailer  = trailer.spec_attachable.attacherJoint.rootNode, 
										targetFactor = 1 } )
	end
	
	if      trailer.spec_wheels ~= nil
			and trailerAssist.tableGetN( trailer.spec_wheels.wheels ) > 0
			and trailerAssist.tableGetN( trailer.components )         > 1
			and trailerAssist.tableGetN( trailer.componentJoints )    > 0 then
		
		trailerAssist.debugPrint("trailer is multiple components")
		
		local na = trailerAssist.getComponentOfNode( trailer, trailer.spec_attachable.attacherJoint.rootNode )
		
		if na > 0 then		
			local wcn = {}
			
			for _,wheel in pairs( trailer.spec_wheels.wheels ) do
				local n = trailerAssist.getComponentOfNode( trailer, wheel.node )
				if n > 0 then
					wcn[n] = true
				end
			end			
			
			local nextN = { na }
			local allN  = {}
			
			while trailerAssist.tableGetN( nextN ) > 0 do				
				local thisN = {}
				for _,n in pairs( nextN ) do
					if not ( allN[n] ) then
						thisN[n] = true
						allN[n]  = true
					end
				end
				nextN = {}
				
				for _,cj in pairs( trailer.componentJoints ) do
					if thisN[cj.componentIndices[1]] and not ( allN[cj.componentIndices[2]] ) then
						table.insert( nextN, cj.componentIndices[2] )
						if cj.rotLimit ~= nil and cj.rotLimit[2] ~= nil and cj.rotLimit[2] > trailerAssistGlobals.minJointRotLimit then
							trailerAssist.debugPrint( "Adding inner joint between "..tostring(cj.componentIndices[1]).." and "..tostring(cj.componentIndices[2]))
							table.insert( taJoints, index,
														{ nodeVehicle  = trailer.components[cj.componentIndices[1]].node,
															nodeTrailer  = trailer.components[cj.componentIndices[2]].node, 
															targetFactor = 1 } )
						end
					end
					if thisN[cj.componentIndices[2]] and not ( allN[cj.componentIndices[1]] ) then
						table.insert( nextN, cj.componentIndices[1] )
						if cj.rotLimit ~= nil and cj.rotLimit[2] ~= nil and cj.rotLimit[2] > trailerAssistGlobals.minJointRotLimit then
							trailerAssist.debugPrint( "Adding inner joint between "..tostring(cj.componentIndices[2]).." and "..tostring(cj.componentIndices[1]))
							table.insert( taJoints, index,
														{ nodeVehicle  = trailer.components[cj.componentIndices[2]].node,
															nodeTrailer  = trailer.components[cj.componentIndices[1]].node, 
															targetFactor = 1 } )
						end
					end
				end
			end
		end
	end	

	return taJoints 
end


--***************************************************************
-- getRelativeYRotation
--***************************************************************
function trailerAssist.getRelativeYRotation(root,node)
	if root == nil or node == nil then
		return 0
	end
	local x, y, z = worldDirectionToLocal(node, localDirectionToWorld(root, 0, 0, 1))
	local dot = trailerAssist.mbClamp( z, -1, 1 )
--dot = dot / math.sqrt(x*x + z*z)
	local angle = math.acos(dot)
	if x < 0 then
		angle = -angle
	end
	return angle
end

function trailerAssist.getWorldYRotation(node)
	local x, _, z = localDirectionToWorld(node, 0, 0, 1)
	if math.abs(x) < 1e-3 and math.abs(z) < 1e-3 then
		return 0
	end
	return trailerAssist.normalizeAngle( math.atan2(z,x) + trailerAssistGlobals.mathPi2 )
end

--***************************************************************
-- getRelativeZTranslation
--***************************************************************
function trailerAssist.getRelativeZTranslation(root,node)
	local x,y,z = trailerAssist.getRelativeTranslation(root,node)
	return z
end

--***************************************************************
-- getRelativeTranslation
--***************************************************************
function trailerAssist.getRelativeTranslation(root,node)
	if root == nil or node == nil then
		return 0,0,0
	end
	local x,y,z;
	local state,result = pcall( getParent, node )
	if not ( state ) then
		return 0,0,0
	elseif result==root then
		x,y,z = getTranslation(node);
	else
		x,y,z = worldToLocal(root,getWorldTranslation(node));
	end;
	return x,y,z;
end

--***************************************************************
-- steeringFunction
--***************************************************************
function trailerAssist.steeringFunction( target, angle, ratio )
	if trailerAssistGlobals.steeringFactor2 > 0 then	
		local diff = angle - ratio
		
		local sign = 0
		if     diff < 0 then
			sign = -1
			diff = -diff
		elseif diff > 0 then
			sign = 1
		else
			return target 
		end
		
		local h2 = ( trailerAssistGlobals.steeringFactor2 * diff )^2
		if trailerAssistGlobals.steeringFactor1 > 0 then	
			local h1 = trailerAssistGlobals.steeringFactor1 * diff			
			return trailerAssist.mbClamp( target + sign * 0.5 * ( h1 + h2 ), -1, 1 ) --math.min( h1, h2 )
		end
		return trailerAssist.mbClamp( target + sign * h2, -1, 1 )
	end
	
	return trailerAssist.mbClamp( target + trailerAssistGlobals.steeringFactor1 * ( angle - ratio ), -1, 1 )
end

--***************************************************************
-- normalizeAngle
--***************************************************************
function trailerAssist.normalizeAngle( b )
	local a = b
	while a >  math.pi do a = a - math.pi - math.pi end
	while a <=-math.pi do a = a + math.pi + math.pi end
	return a
end


--***************************************************************
-- newUpdateVehiclePhysics
--***************************************************************
function trailerAssist:newUpdateVehiclePhysics( superFunc, axisForward, axisSide, doHandbrake, dt )

	local axisSideLast  = self.taAxisSideLast
	self.taAxisSideLast = nil 
	
	if trailerAssist.isActive( self ) then
		local sumTargetFactors = 0
		for _,joint in pairs( self.taJoints ) do
			if     ( self.taMovingDirection < 0 and joint.inTheBack )
					or ( self.taMovingDirection > 0 and not ( joint.inTheBack  ) ) then
				sumTargetFactors = sumTargetFactors + joint.targetFactor
			end
		end
		
		if sumTargetFactors > 0 then
			if self.taMode == 1 then			
				local yt = trailerAssist.getWorldYRotation( self.taJoints[1].nodeTrailer )

				if self.taWorldAngle == nil then
					self.taWorldAngle = yt
				end
				
				local rotScale = math.max( trailerAssistGlobals.minWorldScale, trailerAssistGlobals.worldScale * math.abs( trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle ) ) )
				
				self.taLastAngle  = yt
				self.taWorldAngle = self.taWorldAngle + dt*0.001*self.taAxisSide*rotScale
				local checkAngle  = trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle )
				if     checkAngle < -trailerAssistGlobals.mathPi2 then
					checkAngle = -trailerAssistGlobals.mathPi2
					self.taWorldAngle = checkAngle + self.taLastAngle
				elseif checkAngle >  trailerAssistGlobals.mathPi2 then
					checkAngle =  trailerAssistGlobals.mathPi2
					self.taWorldAngle = checkAngle + self.taLastAngle
				end
				
				local maxWorldRatio = trailerAssistGlobals.maxWorldRatio / trailerAssist.tableGetN( self.taJoints  )
				
				self.taLastRatio  = trailerAssist.mbClamp( checkAngle / trailerAssistGlobals.maxToolDegrees, -maxWorldRatio, maxWorldRatio )
				
				
			--trailerAssist.debugPrint( tostring(math.floor(0.5+math.deg(self.taWorldAngle))).."° "..
			--													tostring(math.floor(0.5+math.deg(self.taLastAngle))).."° "..
			--													tostring(math.floor(0.5+math.deg(trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle )))).."° "..
			--													tostring(math.floor( 0.5 + 100 * self.taLastRatio )).."%" )
				
				if self.taMode == 3 then
					self.taLastRatio = -self.taLastRatio
				end
			else
				if false then --axisSideIsAnalog then
					self.taLastRatio = self.taAxisSide 
				elseif math.abs( self.taAxisSide ) > 0 then
					self.taLastRatio = trailerAssist.mbClamp(self.taLastRatio + dt*0.001*self.taAxisSide*trailerAssistGlobals.rotScale, -1, 1)
				elseif self.taLastRatio > 0 then
					self.taLastRatio = math.max(self.taLastRatio - dt*0.001*trailerAssistGlobals.autoRotateBack * math.abs( self.lastSpeedReal ) * 1000, 0)
				else                                                           
					self.taLastRatio = math.min(self.taLastRatio + dt*0.001*trailerAssistGlobals.autoRotateBack * math.abs( self.lastSpeedReal ) * 1000, 0)
				end		

			end
			
			local ratio  = self.taLastRatio
			local target = ratio

			local maxToolDegrees = trailerAssistGlobals.maxToolDegrees / sumTargetFactors
			for _,joint in pairs( self.taJoints ) do
				if     ( self.taMovingDirection < 0 and joint.inTheBack )
						or ( self.taMovingDirection > 0 and not ( joint.inTheBack  ) ) then
					target    = joint.targetFactor * ratio
					degree    = trailerAssist.getRelativeYRotation( joint.nodeVehicle, joint.nodeTrailer )
					if joint.otherDirection then
						degree  = trailerAssist.normalizeAngle( degree + math.pi )
					end
					angle     = trailerAssist.mbClamp( degree / maxToolDegrees, -1, 1 )	
					ratio     = trailerAssist.steeringFunction( target, angle, ratio )
				end
			end
			
			if self.taMovingDirection < 0 then
				ratio = -ratio
			end
						
			local d = trailerAssistGlobals.steeringSpeed * 0.0005 * ( 2 + math.min( 18, self.lastSpeed * 3600 ) ) * dt

			if axisSideLast == nil then 
				axisSideLast = axisSide
			end 
			
			axisSide = axisSideLast + trailerAssist.mbClamp( ratio - axisSideLast, -d, d )
		end 
	end 
	self.taAxisSideLast = axisSide

	return superFunc( self, axisForward, axisSide, doHandbrake, dt )	
end

--***************************************************************
-- newGetSpeedLimit
--***************************************************************
function trailerAssist:newGetSpeedLimit( superFunc, ... )
	if trailerAssist.isActive( self ) then
		return math.min( superFunc( self, ... ), trailerAssistGlobals.speedLimit )
	end
	return superFunc( self, ... )
end

Drivable.updateVehiclePhysics = Utils.overwrittenFunction( Drivable.updateVehiclePhysics, trailerAssist.newUpdateVehiclePhysics )
Vehicle.getSpeedLimit         = Utils.overwrittenFunction( Vehicle.getSpeedLimit, trailerAssist.newGetSpeedLimit )

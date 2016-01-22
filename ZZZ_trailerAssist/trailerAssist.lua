--
-- trailerAssist
-- This is the specialization for trailerAssist
--

--***************************************************************
source(Utils.getFilename("mogliBase.lua", g_currentModDirectory))
_G[g_currentModName..".mogliBase"].newClass( "trailerAssist" )
--***************************************************************

trailerAssist.defaultMode       = 2
trailerAssist.minMode           = 1
trailerAssist.maxMode           = 2
trailerAssist.minJointRotLimit  = math.rad( 0.1 )
trailerAssist.steeringFactor1   = 2.5 
trailerAssist.steeringFactor2   = 0 --3.5
trailerAssist.rotScale          = 1.0
trailerAssist.worldScale        = math.rad( 30 )
trailerAssist.autoRotateBack    = 0.1
trailerAssist.steeringSpeed     = 2
trailerAssist.minSteeringSpeed  = 0.5
trailerAssist.maxSumDtCalc      = 1000
trailerAssist.maxSumDtDisp      = 200
trailerAssist.speedLimit        = 10
trailerAssist.maxToolDegrees    = 60
trailerAssist.maxWorldRatio     = 1.0
trailerAssist.worldFactor       = 1.0 / math.rad( trailerAssist.maxToolDegrees )
trailerAssist.mathPi2           = 0.5 * math.pi

trailerAssist.debug             = false
function trailerAssist.debugPrint( ... )
	if trailerAssist.debug then
		print( ... )
	end
end

--***************************************************************
-- load
--***************************************************************
function trailerAssist:load(xmlFile)
	self.taLastRatio  = 0
	self.taSumDtCalc  = 0
	self.taSumDtDisp  = 0
	self.isSelectable = true
	self.taWorldAngle = nil
	self.taLastAngle  = 0
	
	trailerAssist.registerState( self, "taMode",         trailerAssist.defaultMode, trailerAssist.onSetMode, true )	
	trailerAssist.registerState( self, "taIsPossible",   false )	
	trailerAssist.registerState( self, "taDisplayAngle", 0 )	
	trailerAssist.registerState( self, "taWorldDispAngle", 0 )	 
end

--***************************************************************
-- draw
--***************************************************************
function trailerAssist:draw()
	if trailerAssist.isActive( self ) then
		setTextColor(1, 1, 0, 1) 
		setTextAlignment(RenderText.ALIGN_CENTER) 
		setTextBold(true)
		
		if self.taMode >= 2 then
			renderText(0.5, 0.9, 0.03, string.format( "%2d° / %2d°", self.taDisplayAngle, self.taWorldDispAngle ) )
		else
			renderText(0.5, 0.9, 0.03, string.format( "%2d°", self.taDisplayAngle ) )
		end

		setTextColor(1, 1, 1, 1) 
		setTextAlignment(RenderText.ALIGN_LEFT) 
		setTextBold(false)
	end	
	
	if self.taIsPossible and InputBinding.taMODE ~= nil then
		local textId = string.format( "taMODE%1d", self.taMode )
		g_currentMission:addHelpButtonText(trailerAssist.getText(textId), InputBinding.taMODE);		
	end
end

--***************************************************************
-- update
--***************************************************************
function trailerAssist:update(dt)
	if self.isServer then
		if self.isEntered and trailerAssist.tableGetN( self.attachedImplements ) > 0 then
			self.taSumDtCalc = self.taSumDtCalc + dt
			if     self.taJoints          == nil 
					or self.taSumDtCalc           >= trailerAssist.maxSumDtCalc then
				trailerAssist.fillTaJoints( self )
			end
		elseif self.taJoints ~= nil then
			trailerAssist.mbSetState( self, "taIsPossible", false )
			self.taJoints = nil
		end
	end
	
	if      self:getIsActiveForInput( false )
			and self.taIsPossible
			and trailerAssist.mbHasInputEvent( "taMODE" ) then
		if     self.taMode == 0 then
			trailerAssist.mbSetState( self, "taMode", trailerAssist.minMode )
		elseif self.taMode <  trailerAssist.maxMode then
			trailerAssist.mbSetState( self, "taMode", self.taMode + 1 )
		else
			trailerAssist.mbSetState( self, "taMode", 0 )
		end	
	end	
end

--***************************************************************
-- updateTick 
--***************************************************************
function trailerAssist:updateTick(dt)
	if self.isServer and self.taMode > 0 then
		if trailerAssist.getMovingDirection( self ) > 0 then
			self.taLastRatio  = 0
			self.taWorldAngle = nil
		end	
		if trailerAssist.isActive( self ) then
			self.taSumDtDisp = self.taSumDtDisp + dt
			if self.taSumDtDisp >= trailerAssist.maxSumDtDisp then
				self.taSumDtDisp = 0
				local degree = 0
				if self.taMode >= 2 then
					if self.taWorldAngle ~= nil then					
						degree = math.deg( trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle ) )
						trailerAssist.mbSetState( self, "taWorldDispAngle", math.floor( 0.5 + math.deg( self.taWorldAngle ) ) )
					else
						trailerAssist.mbSetState( self, "taWorldDispAngle", 0 )
					end
				else
					degree = trailerAssist.maxToolDegrees * self.taLastRatio
				end
				trailerAssist.mbSetState( self, "taDisplayAngle", math.floor( 0.5 + degree ) )
			end
		elseif self.taDisplayAngle ~= 0 then
			self.taSumDtDisp = 0
			trailerAssist.mbSetState( self, "taDisplayAngle", 0 )
		end
	end
end

--***************************************************************
-- onDisplayAngle
--***************************************************************
function trailerAssist:isActive()
	return ( self.isEntered and self.taMode > 0 and self.taIsPossible and ( trailerAssist.getMovingDirection( self ) < 0 ) )
end

--***************************************************************
-- onDisplayAngle
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
	self.taDimensions.radius           = 5;
  self.taDimensions.maxSteeringAngle = math.rad(25);
	self.taDimensions.wheelBase        = self.taDimensions.radius * math.tan( self.taDimensions.maxSteeringAngle )
	self.taDimensions.zOffset          = -0.5 * self.taDimensions.wheelBase;
	
	if      self.articulatedAxis ~= nil 
			and self.articulatedAxis.componentJoint ~= nil
      and self.articulatedAxis.componentJoint.jointNode ~= nil 
			and self.articulatedAxis.rotMax then
		_,_,self.taDimensions.zOffset = AutoSteeringEngine.getRelativeTranslation(self.taRefNode,self.articulatedAxis.componentJoint.jointNode);
		local n=0;
		for _,wheel in pairs(self.wheels) do
			local x,y,z = AutoSteeringEngine.getRelativeTranslation(self.articulatedAxis.componentJoint.jointNode,wheel.driveNode);
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
		for _,wheel in pairs(self.wheels) do
			local temp1 = { getRotation(wheel.driveNode) }
			local temp2 = { getRotation(wheel.repr) }
			setRotation(wheel.driveNode, 0, 0, 0)
			setRotation(wheel.repr, 0, 0, 0)
			local x,y,z = AutoSteeringEngine.getRelativeTranslation(self.taRefNode,wheel.driveNode);
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
	elseif self.aiTractorTurnRadius ~= nil then
		self.taDimensions.radius        = self.aiTractorTurnRadius
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
	
	if     trailerAssist.tableGetN( self.attacherJoints )     < 1
			or trailerAssist.tableGetN( self.attachedImplements ) < 1 then
		return
	end
	
	local taJoints
	
	for _,implement in pairs( self.attachedImplements ) do
		if      implement.object ~= nil 
				and implement.object.steeringAxleNode ~= nil 
				and trailerAssist.getRelativeZTranslation( refNode, implement.object.steeringAxleNode ) < zOffset
				and ( trailerAssist.tableGetN( implement.object.wheels ) > 0
					 or trailerAssist.tableGetN( implement.object.attachedImplements ) > 0 ) then
			trailerAssist.debugPrint( tostring(trailerAssist.getRelativeZTranslation( refNode, implement.object.steeringAxleNode )) .." < "..tostring(zOffset))
			taJoints = trailerAssist.getTaJoints2( self, implement, refNode, zOffset )
			if trailerAssist.tableGetN( taJoints ) > 0 then
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

	if     type( implement )       ~= "table"
			or type( implement.object) ~= "table"
			or refNode                 == nil
			or trailerAssist.tableGetN( self.attacherJoints ) < 1
			or implement.object.steeringAxleNode == nil then
		trailerAssist.debugPrint( "Wrong parameters passed")
		return 
	end
		
	local taJoints
	local trailer  = implement.object

	trailerAssist.debugPrint( "Trailer: "..tostring(trailer.configFileName))
	
	if      trailerAssist.tableGetN( trailer.attacherJoints )     > 0
			and trailerAssist.tableGetN( trailer.attachedImplements ) > 0 then
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
			and implement.jointRotLimit[2] >  trailerAssist.minJointRotLimit then
		trailerAssist.debugPrint("Adding attacher joint")
		table.insert( taJoints, index,
									{ nodeVehicle  = refNode, 
										nodeTrailer  = trailer.attacherJoint.rootNode, 
										targetFactor = 1 } )
	end
	
	if      trailerAssist.tableGetN( trailer.wheels )          > 0
			and trailerAssist.tableGetN( trailer.components )      > 1
			and trailerAssist.tableGetN( trailer.componentJoints ) > 0 then
		
		trailerAssist.debugPrint("trailer is multiple components")
		
		local na = trailerAssist.getComponentOfNode( trailer, trailer.attacherJoint.rootNode )
		
		if na > 0 then		
			local wcn = {}
			
			for _,wheel in pairs( trailer.wheels ) do
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
						if cj.rotLimit[2] > trailerAssist.minJointRotLimit then
							trailerAssist.debugPrint( "Adding inner joint between "..tostring(cj.componentIndices[1]).." and "..tostring(cj.componentIndices[2]))
							table.insert( taJoints, index,
														{ nodeVehicle  = trailer.components[cj.componentIndices[1]].node,
															nodeTrailer  = trailer.components[cj.componentIndices[2]].node, 
															targetFactor = 1 } )
						end
					end
					if thisN[cj.componentIndices[2]] and not ( allN[cj.componentIndices[1]] ) then
						table.insert( nextN, cj.componentIndices[1] )
						if cj.rotLimit[2] > trailerAssist.minJointRotLimit then
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
-- getMovingDirection
--***************************************************************
function trailerAssist:getMovingDirection()
	local movingDirection = 0

	if      self.mrGbMS ~= nil
			and self.mrGbMS.IsOn then
		local rev = self.mrGbMS.ReverseActive
		if self.isReverseDriving then rev = not ( rev ) end
			
		if     rev then 
			movingDirection = -1
		elseif self.mrGbMS.NeutralActive then
			movingDirection = 0 
		else 
			movingDirection = 1
		end
	elseif  self.mrGbMIsOn then
		local rev = self.mrGbMReverseActive
		if self.isReverseDriving then rev = not ( rev ) end

		if     rev then 
			movingDirection = -1
		elseif self.mrGbMNeutralActive then
			movingDirection = 0 
		else 
			movingDirection = 1
		end
		self.ksmShuttleControl = true
	elseif  g_currentMission.driveControl ~= nil
			and g_currentMission.driveControl.useModules ~= nil
			and g_currentMission.driveControl.useModules.shuttle 
			and self.driveControl ~= nil 
			and self.driveControl.shuttle ~= nil 
			and self.driveControl.shuttle.direction ~= nil 
			and self.driveControl.shuttle.isActive then
		movingDirection = self.driveControl.shuttle.direction
	else
		movingDirection = self.movingDirection
	end
		
	return movingDirection
end


--***************************************************************
-- getRelativeYRotation
--***************************************************************
function trailerAssist.getRelativeYRotation(root,node)
	if root == nil or node == nil then
		return 0
	end
	local x, y, z = worldDirectionToLocal(node, localDirectionToWorld(root, 0, 0, 1))
	local dot = z
	dot = dot / Utils.vector2Length(x, z)
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
	return trailerAssist.normalizeAngle( math.atan2(z,x) + trailerAssist.mathPi2 )
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
	if trailerAssist.steeringFactor2 > 0 then	
		local diff = angle - ratio
		
		local sign = 0
		if     diff < -0.01 then
			sign = -1
			diff = -diff
		elseif diff >  0.01 then
			sign = 1
		else
			return target 
		end
		
		if trailerAssist.steeringFactor1 > 0 then	
			local h1 = trailerAssist.steeringFactor1 * diff
			local h2 = ( trailerAssist.steeringFactor2 * diff )^2
			
			return Utils.clamp( target + sign * math.min( h1, h2 ), -1, 1 )
		end
		return Utils.clamp( target + sign * h2, -1, 1 )
	end
	
	return Utils.clamp( target + trailerAssist.steeringFactor1 * ( angle - ratio ), -1, 1 )
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
function trailerAssist:newUpdateVehiclePhysics(superFunc, axisForward, axisForwardIsAnalog, axisSide, axisSideIsAnalog, dt, ...)
	
	local backup = self.rotatedTime
	
	local state,result = pcall( superFunc, self, axisForward, axisForwardIsAnalog, axisSide, axisSideIsAnalog, dt, ... )
	
	if not (state) then
		print("Error in trailerAssist:newUpdateVehiclePhysics : "..tostring(result))
		return 
	end
	
	if trailerAssist.isActive( self ) then
		if self.taMode >= 2 then			
			local yv = trailerAssist.getWorldYRotation( self.taRefNode )
			local yt = trailerAssist.getWorldYRotation( self.taJoints[1].nodeTrailer )

			if self.taWorldAngle == nil then
				self.taWorldAngle = yt
			end

			self.taLastAngle  = yt
			self.taWorldAngle = self.taWorldAngle - dt*0.001*axisSide*trailerAssist.worldScale
			self.taLastRatio  = Utils.clamp( trailerAssist.worldFactor * trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle ), -trailerAssist.maxWorldRatio, trailerAssist.maxWorldRatio )
			
			
			trailerAssist.debugPrint( tostring(math.floor(0.5+math.deg(self.taWorldAngle))).."° "..
																tostring(math.floor(0.5+math.deg(self.taLastAngle))).."° "..
																tostring(math.floor(0.5+math.deg(trailerAssist.normalizeAngle( self.taWorldAngle - self.taLastAngle )))).."° "..
																tostring(math.floor( 0.5 + 100 * self.taLastRatio )).."%" )
			
			if self.taMode == 3 then
				self.taLastRatio = -self.taLastRatio
			end
		else
			if     axisSide < 0 then
				self.taLastRatio = math.min(self.taLastRatio - dt*0.001*axisSide*trailerAssist.rotScale, 1)
			elseif 0 < axisSide then
				self.taLastRatio = math.max(self.taLastRatio - dt*0.001*axisSide*trailerAssist.rotScale, -1)
			else
				if 0 < self.taLastRatio then
					self.taLastRatio = math.max(self.taLastRatio - dt*0.001*trailerAssist.autoRotateBack * math.abs( self.lastSpeedReal ) * 1000, 0)
				else                                                           
					self.taLastRatio = math.min(self.taLastRatio + dt*0.001*trailerAssist.autoRotateBack * math.abs( self.lastSpeedReal ) * 1000, 0)
				end
			end		

		end
		
		local ratio  = self.taLastRatio
		local target = ratio

		local sumTargetFactors = 0
		for _,joint in pairs( self.taJoints ) do
			sumTargetFactors = sumTargetFactors + joint.targetFactor
		end
		
	--local degreeSum = 0
	--local degreeStr = ""
		
		local maxToolDegrees = trailerAssist.maxToolDegrees / sumTargetFactors
		for _,joint in pairs( self.taJoints ) do
			target    = joint.targetFactor * ratio
			degree    = math.deg( trailerAssist.getRelativeYRotation( joint.nodeVehicle, joint.nodeTrailer ) )
		--degreeSum = degreeSum + degree 
		--degreeStr = degreeStr .. tostring(math.floor( 0.5 + degree )) .. "° "
			angle     = Utils.clamp( degree / maxToolDegrees, -1, 1 )	
			ratio     = trailerAssist.steeringFunction( target, angle, ratio )
		end

	--degreeStr = degreeStr .. " => " .. tostring(math.floor( 0.5 + degreeSum )) .. "° => "..tostring(math.floor( 0.5 + 100 * ratio )).."%"
	--trailerAssist.debugPrint(degreeStr)

		local targetRotTime = 0
		if     ratio > 0 then
			targetRotTime =  self.maxRotTime * ratio 
		elseif ratio < 0 then
			targetRotTime = -self.minRotTime * ratio 
		end		
		
		local steeringSpeed = dt * math.max( math.abs( self.lastSpeedReal ) * 1000 * trailerAssist.steeringSpeed, trailerAssist.minSteeringSpeed ) * self.aiSteeringSpeed
		
		if targetRotTime > backup then
			self.rotatedTime = math.min(backup + steeringSpeed, targetRotTime);
		else
			self.rotatedTime = math.max(backup - steeringSpeed, targetRotTime);
		end
	end
	
	return result	
end

--***************************************************************
-- newGetSpeedLimit
--***************************************************************
function trailerAssist:newGetSpeedLimit( superFunc, ... )
	if trailerAssist.isActive( self ) then
		return math.min( superFunc( self, ... ), trailerAssist.speedLimit )
	end
	return superFunc( self, ... )
end

Drivable.updateVehiclePhysics = Utils.overwrittenFunction( Drivable.updateVehiclePhysics, trailerAssist.newUpdateVehiclePhysics )
Vehicle.getSpeedLimit         = Utils.overwrittenFunction( Vehicle.getSpeedLimit, trailerAssist.newGetSpeedLimit )

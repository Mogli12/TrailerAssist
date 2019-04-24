trailerAssist_Register = {};
trailerAssist_Register.g_currentModDirectory = g_currentModDirectory
trailerAssist_Register.specName = "zzzTrailerAssist"

function trailerAssist_Register:beforeFinalizeVehicleTypes()

	if trailerAssist == nil then 
		print("Failed to add specialization trailerAssist")
	else 
		for k, typeDef in pairs(g_vehicleTypeManager.vehicleTypes) do
			if typeDef ~= nil and k ~= "locomotive" then 
				local isDrivable   = false
				local isEnterable  = false
				local hasAttacherJ = false 
				local hasWheels    = false 
				local isAttachable = false 
				local hasNotTA     = true 
				for name, spec in pairs(typeDef.specializationsByName) do
					if     name == "drivable"   then 
						isDrivable = true 
					elseif name == "enterable"  then 
						isEnterable = true 
					elseif name == "wheels"     then 
						hasWheels = true 
					elseif name == "attacherJoints" then 
						hasAttacherJ = true 
					elseif name == "attachable" then 
						isAttachable = true 
					elseif name == trailerAssist_Register.specName then 
						hasNotTA = false 
					end 
				end 
				if hasNotTA and isDrivable and isEnterable and hasAttacherJ and hasWheels and not isAttachable then 
					print("  adding trailerAssist to vehicleType '"..tostring(k).."'")
					typeDef.specializationsByName[trailerAssist_Register.specName] = trailerAssist
					table.insert(typeDef.specializationNames, trailerAssist_Register.specName)
					table.insert(typeDef.specializations, trailerAssist)	
				end 
			end 
		end 	
	end 
end 
VehicleTypeManager.finalizeVehicleTypes = Utils.prependedFunction(VehicleTypeManager.finalizeVehicleTypes, trailerAssist_Register.beforeFinalizeVehicleTypes)

function trailerAssist_Register:loadMap(name)
	print("--- loading "..g_i18n:getText("taVERSION").." by mogli ---")

	g_i18n.texts["taVERSION"] = g_i18n:getText("taVERSION")
end;

function trailerAssist_Register:deleteMap()
  
end;

function trailerAssist_Register:keyEvent(unicode, sym, modifier, isDown)

end;

function trailerAssist_Register:mouseEvent(posX, posY, isDown, isUp, button)

end;

function trailerAssist_Register:update(dt)
	
end;

function trailerAssist_Register:draw()
  
end;

addModEventListener(trailerAssist_Register);
SpecializationUtil.registerSpecialization("trailerAssist", "trailerAssist", g_currentModDirectory.."trailerAssist.lua")

trailerAssist_Register = {};

function trailerAssist_Register:loadMap(name)
	if self.firstRun == nil then
		self.firstRun = false;
		print("--- loading "..g_i18n:getText("taVERSION").." by mogli ---")
		
		for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
			if v ~= nil then
				local allowInsertion = true;
				for i = 1, table.maxn(v.specializations) do
					local vs = v.specializations[i];
					if vs ~= nil and vs == SpecializationUtil.getSpecialization("drivable") then
						local v_name_string = v.name 
						local point_location = string.find(v_name_string, ".", nil, true)
						if point_location ~= nil then
							local _name = string.sub(v_name_string, 1, point_location-1);
							if rawget(SpecializationUtil.specializations, string.format("%s.trailerAssist", _name)) ~= nil then
								allowInsertion = false;								
							end;							
						end;
						if allowInsertion then	
							table.insert(v.specializations, SpecializationUtil.getSpecialization("trailerAssist"));
						end;						
					end;
				end;
			end;	
		end;
		g_i18n.globalI18N.texts["taVERSION"]    = g_i18n:getText("taVERSION");		
		g_i18n.globalI18N.texts["taMODE0"]      = g_i18n:getText("taMODE0");		
		g_i18n.globalI18N.texts["taMODE1"]      = g_i18n:getText("taMODE1");		
		g_i18n.globalI18N.texts["taMODE2"]      = g_i18n:getText("taMODE2");		
	end;
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
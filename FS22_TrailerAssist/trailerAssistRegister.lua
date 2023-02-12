
local directory = g_currentModDirectory
local modName = g_currentModName
local specName = "zzzTrailerAssist"


trailerAssistRegister = {}

local trailerAssistRegister_mt = Class(trailerAssistRegister)

function trailerAssistRegister.new( i18n )
	self = {}
	setmetatable(self, trailerAssistRegister_mt)
	self.taDirectory = directory
	self.taModName = modName 
	self.taSpecName = specName
	self.i18n = i18n

	return self 
end 

local function beforeFinalizeTypes( typeManager )

	if trailerAssist == nil then 
		print("Failed to add specialization trailerAssist")
	else 
		local allTypes = typeManager:getTypes( )
		for k, typeDef in pairs(allTypes) do
			if typeDef ~= nil and k ~= "locomotive" and k ~= "woodCrusherTrailerDrivable" then 
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
					elseif name == trailerAssistRegister.specName then 
						hasNotTA = false 
					end 
				end 
				if hasNotTA and isDrivable and isEnterable and hasAttacherJ and hasWheels and not isAttachable then 
					print("  adding trailerAssist to vehicleType '"..tostring(k).."'")
					typeDef.specializationsByName[specName] = trailerAssist
					table.insert(typeDef.specializationNames, specName)
					table.insert(typeDef.specializations, trailerAssist)	
				end 
			end 
		end 	
	end 
end 

function trailerAssistRegister:loadMap(name)
	if g_server ~= nil then 
		self.isDedi = g_dedicatedServerInfo ~= nil  
		if self.isDedi then 
			self.isMP = true 
		elseif g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer then 
			self.isMP = true 
		else 
			self.isMP = false 
		end 
	else 
		self.isMP   = true 
	end 
end;


function trailerAssistRegister:deleteMap()
  
end;

function trailerAssistRegister:keyEvent(unicode, sym, modifier, isDown)

end;

function trailerAssistRegister:mouseEvent(posX, posY, isDown, isUp, button)

end;

function trailerAssistRegister:update(dt)

end;

local function beforeLoadMission(mission)
	assert( g_trailerAssist == nil )
	local base = trailerAssistRegister.new( g_i18n )
	getfenv(0)["g_trailerAssist"] = base
	addModEventListener(base);
end 

local function postLoadMissionFinished( mission, node )
	local state, result = pcall( trailerAssistRegister.postLoadMission, g_trailerAssist, mission )
	if state then 
		return result 
	else 
		print("Error calling trailerAssistRegister.postLoadMission :"..tostring(result)) 
	end 
end 
	
function trailerAssistRegister:postLoadMission(mission)
	self.postLoadMissionDone = true 
	print("--- loading "..self.i18n:getText("taVERSION").." by mogli ---")

	if g_languageShort ~= "en" then
		l10nXmlFile = loadXMLFile("modL10n", Utils.getFilename("l10n/modDesc_l10n_en.xml",self.taDirectory))

		if l10nXmlFile ~= nil then
			local textI = 0

			while true do
				local key = string.format("l10n.texts.text(%d)", textI)

				if not hasXMLProperty(l10nXmlFile, key) then
					break
				end

				local name = getXMLString(l10nXmlFile, key .. "#name")
				local text = getXMLString(l10nXmlFile, key .. "#text")

				if name ~= nil and text ~= nil then
					if not g_i18n:hasModText(name) then
						print("Info (trailer assist): text "..tostring(name).." is not translated yet. Using English text.")
						g_i18n:setText(name, text:gsub("\r\n", "\n"))
					end
				end

				textI = textI + 1
			end

			delete(l10nXmlFile)
		end 
	end 
end;

local function init()
	Mission00.load = Utils.prependedFunction(Mission00.load, beforeLoadMission)
	Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, postLoadMissionFinished)
	TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, beforeFinalizeTypes)
end 

init()
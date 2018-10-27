local CDGDT = ZO_Object:Subclass()

local Addon =
{
    Name = "CDGDevTools",
    NameSpaced = "CDG Dev Tools",
    Author = "CrazyDutchGuy",
    Version = "0.1",
}

CDGDT.DEFAULTS = {}
CDGDT.SV = {}

local function parseMapLinks()
	local tooltip = WINDOW_MANAGER:GetControlByName("PopupTooltip")
	for i,v in pairs(LOST_TREASURE_DATA) do
		for i,v in pairs(v) do
			--d(v[LOST_TREASURE_INDEX.ITEMID])
			--d("|H3A92FF:item:"..v[LOST_TREASURE_INDEX.ITEMID]..":1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0|hblaat|h")
			--d(ZO_LinkHandler_ParseLink("|H3A92FF:item:"..v[LOST_TREASURE_INDEX.ITEMID]..":1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0|h[]|h"))
			ZO_PopupTooltip_SetLink("|H3A92FF:item:"..v[LOST_TREASURE_INDEX.ITEMID]..":1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0|h|h")
			d(tooltip.lastLink)
			--d(PopupTooltip:GetLink())
			--|H3A92FF:item:44926:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0|h11|h
		end
	end
end

local function stringStartsWith(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

local function processATLASMails()
	--d("EVENT_MAIL_INBOX_UPDATE")

	local nextMailId = GetNextMailId(nil)

	while nextMailId  do
		local subject = select(3,GetMailItemInfo(nextMailId))
		if stringStartsWith(subject,"ATLAS DATA SYNC") or 		   
		   stringStartsWith(subject,"Update location for") then
			
			RequestReadMail(nextMailId)			
			return	
		end
		nextMailId = GetNextMailId(nextMailId)
	end

end

local function saveATLASMails(mailId)
	--d("EVENT_MAIL_READABLE")	
	local subject = select(3,GetMailItemInfo(mailId))
	if stringStartsWith(subject,"ATLAS DATA SYNC") or 
	   stringStartsWith(subject,"Update location for") then
		
		d("Processing ATLAS mail")
		table.insert(CDGDT.SV["ATLAS"], {GetMailItemInfo( mailId )})
		table.insert(CDGDT.SV["ATLAS"], ReadMail( mailId ))	
		DeleteMail(mailId, true)
	end
end

local function processSlashCommands(option)
	local options = {}
    local searchResult = { string.match(option,"^(%S*)%s*(.-)$") }
    for i,v in pairs(searchResult) do
        if (v ~= nil and v ~= "") then
            options[i] = string.lower(v)
        end
    end

    if #options == 0 or options[1] == "help" then
    	d(" /cdgdt reset - Deletes all logged data (causes reloadui)")
       -- Display help
    elseif options[1] == "reset" then
    	for k in pairs (CDGDT.SV["ATLAS"]) do
   			CDGDT.SV["ATLAS"][k] = nil
		end
    	ReloadUI()
    end
end

function CDGDT:EVENT_PLAYER_ACTIVATED()

end

function CDGDT:EVENT_ADD_ON_LOADED(eventCode, addOnName, ...)
	if addOnName == Addon.Name then
		CDGDT.SV = ZO_SavedVars:New("CDGDT_SavedVariables", 1, nil, CDGDT.DEFAULTS)

		SLASH_COMMANDS["/cdgdt"] = processSlashCommands

		if not CDGDT.SV["ATLAS"] then CDGDT.SV["ATLAS"] = {} end				

		--EVENT_MANAGER:UnregisterForEvent( AddOn.Name, EVENT_ADD_ON_LOADED )	

		EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_PLAYER_ACTIVATED, function(...) CDGDT:EVENT_PLAYER_ACTIVATED(...) end )
		EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_MAIL_INBOX_UPDATE, function() processATLASMails() end )		
		EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_MAIL_READABLE, function(_, mailId) saveATLASMails(mailId) end)		
		-- EVENT_MAIL_INBOX_UPDATE
	end
end

function CDGDT_OnInitialized()
	EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED, function(...) CDGDT:EVENT_ADD_ON_LOADED(...) end )		
end

local MAJOR, MINOR = "LibSort-1.0", 3
local LibSort, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibSort then return end	--the same or newer version of this lib is already loaded into memory 

--- Storage variables ---
LibSort.RegisteredCallbacks = {}
LibSort.AddonOrder = {}
LibSort.DefaultOrdersLow = {}
LibSort.DefaultOrdersHigh = {}
LibSort.sortKeys = ZO_Inventory_GetDefaultHeaderSortKeys()

-- Lookup Tables ---
local defaultType = {["isNumeric"] = 0, ["isBoolean"] = false, ["isString"] = ""}
local inventoryTypes = 
{
	[INVENTORY_BACKPACK] = ZO_PlayerInventoryBackpack, 
	[INVENTORY_BANK] = ZO_PlayerBankBackpack, 
	[INVENTORY_GUILD_BANK] = ZO_GuildBankBackpack
}

--- Utility functions ---

local function removeSpaces(name)
	return name:gsub(" ","")
end

local function makePrefix(name)
	return removeSpaces(name) .. "_"
end

function LibSort:Debug(msg)
	if LibSort.isDebugging then	d("[LibSort]: "..msg) 	end
end

function LibSort:Version()
	d("Version:"..MAJOR.."."..MINOR)
end

--- Arrow generation ---
function LibSort:SetupArrows()
	LibSort.ItemSortBank = WINDOW_MANAGER:CreateControlFromVirtual("ItemSortBank", ZO_PlayerBankSortBy, "ZO_SortHeaderIcon")
	LibSort.ItemSortBank:SetDimensions(16, 32)
	LibSort.ItemSortBank:SetAnchor(RIGHT, ZO_PlayerBankSortByName, LEFT, -15)
	ZO_SortHeader_SetTooltip(LibSort.ItemSortBank, "Sort", BOTTOMRIGHT, 0, 32)
    ZO_SortHeader_InitializeArrowHeader(LibSort.ItemSortBank, "age", ZO_SORT_ORDER_DOWN)

    PLAYER_INVENTORY.inventories[INVENTORY_BANK].sortHeaders:AddHeader(ItemSortBank)

    LibSort.ItemSortGuild = WINDOW_MANAGER:CreateControlFromVirtual("ItemSortGuild", ZO_GuildBankSortBy, "ZO_SortHeaderIcon")
	LibSort.ItemSortGuild:SetDimensions(16, 32)
	LibSort.ItemSortGuild:SetAnchor(RIGHT, ZO_GuildBankSortByName, LEFT, -15)
	ZO_SortHeader_SetTooltip(LibSort.ItemSortGuild, "Sort", BOTTOMRIGHT, 0, 32)
    ZO_SortHeader_InitializeArrowHeader(LibSort.ItemSortGuild, "age", ZO_SORT_ORDER_DOWN)
                     
    PLAYER_INVENTORY.inventories[INVENTORY_GUILD_BANK].sortHeaders:AddHeader(ItemSortGuild)
end

--- Main functions ---
function LibSort:InjectKeys()
	for addon, callbacks in pairs(self.RegisteredCallbacks) do
		for name, data in pairs(callbacks) do
			if not self.sortKeys[data.key] then 
				self.sortKeys[data.key] = {} 
				self.sortKeys[data.key][data.dataType] = true
			end	
		end
	end	
	self:ReOrderKeys()
end

function LibSort:ReOrderKeys()
	local first 
	local previous
	for i, addonName in ipairs(self.AddonOrder) do		
		if self.DefaultOrdersLow[addonName] then
			for _, name in ipairs(self.DefaultOrdersLow[addonName]) do
				local data = self.RegisteredCallbacks[addonName][name] 
				if data then -- we skip the ones we haven't registered yet
					first, previous = self:SetKeyOrder(first, previous, data)
				end
			end
		end
	end
	for i, addonName in ipairs(self.AddonOrder) do		
		if self.DefaultOrdersHigh[addonName] then
			for _, name in ipairs(self.DefaultOrdersHigh[addonName]) do
				local data = self.RegisteredCallbacks[addonName][name] 
				if data then -- we skip the ones we haven't registered yet
					first, previous = self:SetKeyOrder(first, previous, data)
				end
			end
		end					
	end
	self.sortKeys[previous].tiebreaker = "name"
	PLAYER_INVENTORY:ChangeSort("age", INVENTORY_BACKPACK, true)
	PLAYER_INVENTORY:ChangeSort("age", INVENTORY_BANK, true)
	PLAYER_INVENTORY:ChangeSort("age", INVENTORY_GUILD_BANK, true)
end

function LibSort:SetKeyOrder(first, previous, data)
	if not first then 
		first = true 
		self.sortKeys["age"].tiebreaker = data.key
		self.sortKeys["age"].reverseTiebreakerSortOrder = nil
	else
		if previous then
			self.sortKeys[previous].tiebreaker = data.key					
		end
	end	
	return first, data.key
end

function LibSort:ProcessInventory(inventoryType)	
	local container = inventoryTypes[inventoryType]
	if not container then return end
	for i, slot in ipairs(container.data) do
		local slotType, bag, index = slot.data.slotType, slot.data.bagId, slot.data.slotIndex
		for addon, callbacks in pairs(self.RegisteredCallbacks) do
			for name, data in pairs(callbacks) do
				if not slot.data[data.key] then
					slot.data[data.key] = data.func(slotType, bag, index) or defaultType[data.dataType]
				end
			end
		end		
	end
end

function LibSort:Loaded(event, name)
    if name ~= "ZO_Ingame" then return end

    self.savedVars = ZO_SavedVars:New("ZO_Ingame_SavedVariables", 1, "LibSort")    

	ZO_PreHook(PLAYER_INVENTORY, "ApplySort", function(self, inventoryType) LibSort:ProcessInventory(inventoryType) end)	
	zo_callLater(function() LIBSORT:SetupArrows() end, 3000)

	--EVENT_MANAGER:UnregisterForEvent("LibSortLoaded", EVENT_ADD_ON_LOADED)
end

--EVENT_MANAGER:RegisterForEvent("LibSortLoaded", EVENT_ADD_ON_LOADED, function(...) LibSort:Loaded(...) end)

--------- API ---------

function LibSort:Unregister(addonName, name)
	if not name then 
		self.RegisteredCallbacks[addonName] = nil
		self.DefaultOrdersHigh[addonName] = nil
		self.DefaultOrdersLow[addonName] = nil
		return
	end

	if self.RegisteredCallbacks[addonName] then
		self.RegisteredCallbacks[addonName][name] = nil
	end
end

function LibSort:Register(addonName, name, desc, key, func, dataType)
	if not dataType then dataType = "isNumeric" end
	if not self.RegisteredCallbacks[addonName] then self.RegisteredCallbacks[addonName] = {} table.insert(self.AddonOrder, addonName) end
	self.RegisteredCallbacks[addonName][name] = {key = makePrefix(addonName)..key, func = func, desc = desc, dataType = dataType}
	if not self.DefaultOrdersHigh[addonName] then self.DefaultOrdersHigh[addonName] = {} end
	table.insert(self.DefaultOrdersHigh[addonName], name)
	self:InjectKeys()
end

function LibSort:RegisterNumeric(addonName, name, desc, key, func)
	self:Register(addonName, name, desc, key, func, "isNumeric")
end

function LibSort:RegisterBoolean(addonName, name, desc, key, func)
	self:Register(addonName, name, desc, key, func, "isBoolean")
end

function LibSort:RegisterString(addonName, name, desc, key, func)
	self:Register(addonName, name, desc, key, func, "isString")
end

function LibSort:RegisterDefaultOrder(addonName, keyTableLow, keyTableHigh)
	self.DefaultOrdersHigh[addonName] = keyTableHigh
	self.DefaultOrdersLow[addonName] = keyTableLow
	self:ReOrderKeys()
end

function LibSort:SetDebugging(flag)
	self.isDebugging = flag
end
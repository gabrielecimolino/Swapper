--Globals
--=======================================================
Swapper = CreateFrame("Frame", "Swapper", UIParent)
AceEvent = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")
DEBUG = false

--General functions
--=============================
function debug(msg)
	if DEBUG then
		message(msg)
	end
end

function foldr(func, val, tbl)
    for i,v in pairs(tbl) do
        val = func(val, v)
    end
    return val
end

function andIt(x, y)
	return (x and y)
end

function stringCat(x, y)
	return x .. y
end

--Event handlers
--========================================================================================
local function handler()
	if event == "ADDON_LOADED" then
		debug("Swapper loaded")
	elseif event == "UI_ERROR_MESSAGE" then
		if arg1 == "You can only do that with empty bags." then
			local frozenItemBag, frozenItemSlot, frozenItemID = findFrozen()
			local frozenBag = findFrozenBag()
			-- If there is a frozen item and a frozen bag then we've got the right error
			if (frozenItemBag and frozenItemSlot and frozenItemID and frozenBag) then
				local freeSlots = allFreeSlots(frozenBag)
				local slotsNeeded = GetContainerNumSlots(frozenBag) - findFreeSlots(frozenBag)
				if freeSlots >= slotsNeeded then
					AceEvent:ScheduleEvent(unequipBag, 1, frozenItemBag, frozenItemSlot, frozenItemID, frozenBag)
				end
			end
		end
	end
end

function unequipBag(frozenItemBag, frozenItemSlot, frozenItemID, frozenBag)
	debug("Unequip event")
	-- Empty the bag and then store it
	emptyBag(frozenBag) 
	PickupBagFromSlot(ContainerIDToInventoryID(frozenBag)) 
	local freeBag, freeSlot = findNextFreeSlot(frozenBag)
	if freeBag == 0 then
		PutItemInBackpack()
	else
		PickupContainerItem(freeBag, freeSlot)
	end
	-- If it doesn't take then try it again
	if CursorHasItem() then
		unequipBag(frozenItemBag, frozenItemSlot, frozenItemID, frozenBag)
	else 
		-- Now equip the new bag
		AceEvent:ScheduleEvent(equipBag, 1, frozenItemBag, frozenItemSlot, frozenItemID, frozenBag)
	end
end

function equipBag(frozenItemBag, frozenItemSlot, frozenItemID, frozenBag)
	debug("Equip event")
	-- Get the new bag and equip it where the old bag was
	PickupContainerItem(frozenItemBag, frozenItemSlot)
	EquipCursorItem(ContainerIDToInventoryID(frozenBag))
	if CursorHasItem() then
		equipBag(frozenItemBag, frozenItemSlot, frozenItemID, frozenBag)
	end
end

--Events
--=======================================
Swapper:RegisterEvent("ADDON_LOADED")
Swapper:RegisterEvent("UI_ERROR_MESSAGE")
Swapper:SetScript("OnEvent", handler)

--Utilities
--===========================================================================================
function findFrozen()
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			-- if the item at this container slot is locked then its our new bag
			local _, _, locked, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
			if locked == 1 then
				link = GetContainerItemLink(bag, slot)
				return bag, slot, linkToItemID(link)
			end
		end
	end
end

function linkToItemID(link)
	local _, _, itemID = strfind(link, 'item:(%d+):(%d*):(%d*):(%d*)')
	itemID = tonumber(itemID)
	return itemID
end

function findFreeSlots(bag)
	local freeSlots = 0
	for slot = 1, GetContainerNumSlots(bag) do
		local filled = GetContainerItemInfo(bag, slot)
		if not filled then
			freeSlots = freeSlots + 1
		end
	end
	return freeSlots
end

function allFreeSlots(locked)
	local freeSlots = 0
	for bag = 0, NUM_BAG_SLOTS do
		if bag ~= locked then
			freeSlots = freeSlots + findFreeSlots(bag)
		end
	end
	return freeSlots
end

function findNextFreeSlot(locked)
	for bag = 0, NUM_BAG_SLOTS do
		if bag ~= locked then
			for slot = 1, GetContainerNumSlots(bag) do
				local filled = GetContainerItemInfo(bag, slot)
				if not filled then
					return bag, slot 
				end
			end
		end
	end
end

function findBagForItem(frozenBag)
	if findFreeSlots(0) > 0 then
		PutItemInBackpack() 
	else
	 	for i = 1, 4 do
	 		if ((findFreeSlots(i) > 0) and (i ~= frozenBag)) then
				PutItemInBag(ContainerIDToInventoryID(i))
			end
		end
	end
end

function emptyBag(bag)
	for slot = 1, GetContainerNumSlots(bag) do
		local filled = GetContainerItemInfo(bag, slot)
		if filled then
			PickupContainerItem(bag, slot)
			findBagForItem(bag)
		end
	end
	return nil
end

function findFrozenBag()
	for bag = 0, NUM_BAG_SLOTS do
		local isLocked = IsInventoryItemLocked(ContainerIDToInventoryID(bag))
		if isLocked then
			if bag ~= 0 then
				return bag
			else
				return nil
			end
		end
	end
end
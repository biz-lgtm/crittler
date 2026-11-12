-- Loot-Angeber: seltene Drops werden mit der Gilde geteilt
local ADDON, ns = ...

local lastID, lastTime = nil, 0

local function ItemInfo(id)
	local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if not fn then return end
	local name, _, quality = fn(id)
	return name, quality
end

local function ItemIcon(id)
	local fn = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
	return fn and fn(id) or "Interface\\Icons\\INV_Misc_Bag_08"
end

local function ColoredLink(id, quality, name)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	local hex = c and c.hex or "|cffffffff"
	return hex .. "|Hitem:" .. id .. "|h[" .. name .. "]|h|r"
end

ns:On("CHAT_MSG_LOOT", function(text, _, _, _, looter)
	if not ns.db or ns.IsSecret(text) or ns.IsSecret(looter) then return end
	if type(text) ~= "string" or type(looter) ~= "string" then return end
	if not ns:IsMe(Ambiguate(looter, "short")) then return end

	local id = tonumber(text:match("|Hitem:(%d+)"))
	if not id then return end
	local linkName = text:match("|Hitem:.-|h%[(.-)%]|h")
	local name, quality = ItemInfo(id)
	name = name or linkName
	if name and ns.CheckWishLoot then ns:CheckWishLoot(id, name) end
	if not name or not quality then return end

	-- Erfolge unabhängig von der Teilen-Schwelle
	if quality >= 3 then ns:Award("blau") end
	if quality >= 4 then ns:Award("lila") end
	if quality < ns.db.settings.lootQuality then return end

	local now = time()
	if id == lastID and now - lastTime < 3 then return end
	lastID, lastTime = id, now

	ns:Send("LO", id, quality, name)
end)

ns:Handle("LO", function(name, isMe, id, quality, itemName)
	if isMe then return end
	id, quality = tonumber(id), tonumber(quality)
	if not id or not quality or not itemName then return end
	ns:Toast(ItemIcon(id), name .. " hat Beute gemacht!", ColoredLink(id, quality, itemName), 120)
end)

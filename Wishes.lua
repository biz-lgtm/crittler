-- Wunschliste: jeder trägt ein, was er sucht. Findet ein anderer Crittler den Gegenstand
-- (oder hat ihn schon in der Tasche), bekommen beide einen Hinweis.
local ADDON, ns = ...

local MAX = 10
ns.MAX_WISHES = MAX

local ICON = "Interface\\Icons\\INV_Misc_Note_01"
local buffers, lootNotified, bagNotified = {}, {}, {}

local function Clean(s)
	return strtrim((tostring(s):gsub("[%^,:|]", " ")))
end

local function ItemIcon(id)
	local fn = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
	return (id and id > 0 and fn and fn(id)) or ICON
end

local function BagCount(id)
	local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
	if not fn or not id or id <= 0 then return 0 end
	local ok, n = pcall(fn, id)
	if not ok or ns.IsSecret(n) then return 0 end
	return tonumber(n) or 0
end

local function Matches(w, id, name)
	if w.id and w.id > 0 then return w.id == id end
	return name ~= nil and strlower(w.n) == strlower(name)
end

---------------------------------------------------------------------------
-- Eigene Liste
---------------------------------------------------------------------------
-- text: Gegenstands-Link (Shift-Klick) oder einfach der Name
function ns:AddWish(text)
	text = strtrim(text or "")
	if text == "" then return false end
	local wishes = ns.cdb.wishes
	if #wishes >= MAX then
		ns:Print(format("Die Wunschliste ist voll (%d Einträge).", MAX))
		return false
	end
	local id = tonumber(text:match("|Hitem:(%d+)")) or 0
	local name = Clean(text:match("|h%[(.-)%]|h") or text)
	if name == "" or #name > 60 then
		ns:Print("Das ist kein gültiger Gegenstand.")
		return false
	end
	for _, w in ipairs(wishes) do
		if Matches(w, id, name) or strlower(w.n) == strlower(name) then
			ns:Print(format("[%s] steht schon auf deiner Wunschliste.", w.n))
			return false
		end
	end
	tinsert(wishes, { id = id, n = name })
	ns:Print(format("[%s] steht jetzt auf deiner Wunschliste.", name))
	ns:SendWishes()
	ns:RefreshUI()
	return true
end

function ns:RemoveWish(index)
	local w = tremove(ns.cdb.wishes, index)
	if not w then return end
	ns:Print(format("[%s] von der Wunschliste entfernt.", w.n))
	ns:SendWishes()
	ns:RefreshUI()
end

function ns:PrintWishes()
	local wishes = ns.cdb.wishes
	if #wishes == 0 then
		ns:Print("Deine Wunschliste ist leer. |cffffffff/crit wunsch <Gegenstand>|r trägt etwas ein.")
		return
	end
	ns:Print("Deine Wunschliste:")
	for i, w in ipairs(wishes) do
		print(format("  %d. [%s]", i, w.n))
	end
end

---------------------------------------------------------------------------
-- Abgleich
---------------------------------------------------------------------------
function ns:SendWishes()
	if not ns.cdb then return end
	local chunks, chunk = {}, ""
	for _, w in ipairs(ns.cdb.wishes) do
		local s = (w.id or 0) .. ":" .. Clean(w.n)
		if #chunk + #s > 200 then
			tinsert(chunks, chunk)
			chunk = ""
		end
		chunk = chunk == "" and s or (chunk .. "," .. s)
	end
	tinsert(chunks, chunk)
	for i, c in ipairs(chunks) do
		ns:Send("WL", i, #chunks, c)
	end
end

-- Habe ich etwas in der Tasche, das dieser Crittler sucht?
local function CheckBags(name, wishes)
	for _, w in ipairs(wishes) do
		local key = name .. "#" .. (w.id or 0) .. "#" .. w.n
		if not bagNotified[key] then
			local n = BagCount(w.id)
			if n > 0 then
				bagNotified[key] = true
				ns:Print(format("|cff66ff66%s|r sucht [%s]. Du hast %d davon in der Tasche.", name, w.n, n))
			end
		end
	end
end

ns:Handle("WL", function(name, isMe, i, n, list)
	if isMe then return end
	i, n = tonumber(i), tonumber(n)
	if not i or not n then return end
	if i == 1 then buffers[name] = {} end
	local buf = buffers[name]
	if not buf then return end
	if list and list ~= "" then
		for _, entry in ipairs({ strsplit(",", list) }) do
			local id, itemName = strsplit(":", entry, 2)
			id = tonumber(id)
			if id and itemName and itemName ~= "" and #buf < MAX then
				tinsert(buf, { id = id, n = itemName })
			end
		end
	end
	if i == n then
		ns:Member(name).wishes = buf
		buffers[name] = nil
		CheckBags(name, buf)
		ns:RefreshUI()
	end
end)

-- Wird von Loot.lua bei jedem eigenen Fund aufgerufen
function ns:CheckWishLoot(id, itemName)
	if not ns:InGuild() then return end
	local now = GetTime()
	if lootNotified[id] and now - lootNotified[id] < 60 then return end
	local names = {}
	for name, m in pairs(ns.db.members) do
		if name ~= ns.me then
			for _, w in ipairs(m.wishes or {}) do
				if Matches(w, id, itemName) then
					tinsert(names, name)
					break
				end
			end
		end
	end
	if #names == 0 then return end
	lootNotified[id] = now
	table.sort(names)
	ns:Toast(ItemIcon(id), "Wunschliste!", format("%s sucht [%s]. Du hast es gerade gefunden!",
		table.concat(names, ", "), itemName), 878)
	for _, name in ipairs(names) do
		ns:Send("WF", name, id, Clean(itemName))
	end
end

ns:Handle("WF", function(name, isMe, target, id, itemName)
	if isMe or not ns:IsMe(target) or not itemName then return end
	ns:Toast(ItemIcon(tonumber(id)), "Wunsch gefunden!",
		format("%s hat [%s] gefunden. Das steht auf deiner Wunschliste!", name, itemName), 878)
end)

-- Liste für das Fenster: was suchen die anderen, und habe ich es?
function ns:OtherWishes()
	local byKey, out = {}, {}
	for name, m in pairs(ns.db.members) do
		if name ~= ns.me then
			for _, w in ipairs(m.wishes or {}) do
				local key = (w.id and w.id > 0) and w.id or strlower(w.n)
				local e = byKey[key]
				if not e then
					e = { n = w.n, id = w.id or 0, names = {}, have = BagCount(w.id) }
					byKey[key] = e
					tinsert(out, e)
				end
				tinsert(e.names, name)
			end
		end
	end
	for _, e in ipairs(out) do
		table.sort(e.names)
	end
	table.sort(out, function(a, b) return a.n < b.n end)
	return out
end

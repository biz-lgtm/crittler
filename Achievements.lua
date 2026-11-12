-- Eigene Gilden-Erfolge
local ADDON, ns = ...

local I = "Interface\\Icons\\"

-- Hier könnt ihr eigene Erfolge ergänzen. "key" muss kurz und eindeutig sein.
ns.achievements = {
	{ key = "lv10", name = "Aus dem Gröbsten raus", desc = "Erreiche Level 10.", icon = I .. "Achievement_Level_10" },
	{ key = "lv20", name = "Halbstark", desc = "Erreiche Level 20.", icon = I .. "Achievement_Level_20" },
	{ key = "lv30", name = "Dreißig und kein bisschen weise", desc = "Erreiche Level 30.", icon = I .. "Achievement_Level_30" },
	{ key = "lv40", name = "Reittier-Reife", desc = "Erreiche Level 40.", icon = I .. "Achievement_Level_40" },
	{ key = "lv50", name = "Fast da", desc = "Erreiche Level 50.", icon = I .. "Achievement_Level_50" },
	{ key = "lv60", name = "Ober-Crittler", desc = "Erreiche Level 60.", icon = I .. "Achievement_Level_60" },
	{ key = "tod1", name = "Erster Fehltritt", desc = "Stirb zum ersten Mal.", icon = I .. "Ability_Rogue_FeignDeath" },
	{ key = "tod10", name = "Stammgast beim Geistheiler", desc = "Stirb 10 Mal.", icon = I .. "Spell_Holy_Resurrection" },
	{ key = "tod50", name = "Friedhofs-Abo", desc = "Stirb 50 Mal.", icon = I .. "INV_Misc_Bone_HumanSkull_01" },
	{ key = "doppel", name = "Doppelt hält besser", desc = "Stirb zweimal innerhalb von 5 Minuten.", icon = I .. "Spell_Shadow_DeathScream" },
	{ key = "zaeh", name = "Zäher Hund", desc = "Steige 10 Level auf, ohne zu sterben.", icon = I .. "Spell_Holy_DivineIntervention" },
	{ key = "blau", name = "Glückspilz", desc = "Erbeute deinen ersten seltenen Gegenstand.", icon = I .. "INV_Misc_Coin_01" },
	{ key = "lila", name = "Lila macht glücklich", desc = "Erbeute deinen ersten epischen Gegenstand.", icon = I .. "INV_Misc_Gem_Amethyst_02" },
	{ key = "laerm", name = "Lärmbelästigung", desc = "Spiele 25 Sounds über das Soundboard ab.", icon = I .. "INV_Misc_Bell_01" },
	{ key = "welt", name = "Weltenbummler", desc = "Besuche 10 verschiedene Gebiete.", icon = I .. "INV_Misc_Map_01" },
	{ key = "rudel", name = "Rudeltier", desc = "Sei mit einem anderen Crittler in einer Gruppe.", icon = I .. "INV_Misc_GroupLooking" },
	{ key = "eule", name = "Nachteule", desc = "Logge dich zwischen 2 und 5 Uhr nachts ein.", icon = I .. "INV_Misc_PocketWatch_01" },
	{ key = "q50", name = "Laufbursche", desc = "Schließe 50 Quests ab.", icon = I .. "INV_Misc_Book_09" },
	{ key = "q250", name = "Questmaschine", desc = "Schließe 250 Quests ab.", icon = I .. "INV_Misc_Book_11" },
}

ns.achByKey = {}
for _, a in ipairs(ns.achievements) do
	ns.achByKey[a.key] = a
end

-- silent = true: ohne Banner und ohne Rundruf (z. B. Nachtragen beim Login)
function ns:Award(key, silent)
	local a = ns.achByKey[key]
	if not a or not ns.cdb or ns.cdb.ach[key] then return end
	ns.cdb.ach[key] = time()
	ns:Member(ns.me).ach[key] = true
	if not silent then
		ns:Send("AC", key)
		ns:Toast(a.icon, "Erfolg errungen!", a.name, 878)
	end
	ns:RefreshUI()
end

function ns:CheckLevelAchievements(level, silent)
	for lv = 10, 60, 10 do
		if level >= lv then ns:Award("lv" .. lv, silent) end
	end
end

-- Kompletten Stand verschicken (ohne Banner bei den anderen)
function ns:SendAchievements()
	if not ns.cdb then return end
	local chunk = ""
	for key in pairs(ns.cdb.ach) do
		if #chunk + #key > 200 then
			ns:Send("AL", chunk)
			chunk = ""
		end
		chunk = chunk == "" and key or (chunk .. "," .. key)
	end
	if chunk ~= "" then ns:Send("AL", chunk) end
end

ns:Handle("AC", function(name, isMe, key)
	if isMe then return end
	local a = ns.achByKey[key]
	if not a then return end
	ns:Member(name).ach[key] = true
	ns:Toast(a.icon, name .. " hat einen Erfolg!", a.name, 878)
	ns:RefreshUI()
end)

ns:Handle("AL", function(name, isMe, list)
	if isMe or not list or list == "" then return end
	local m = ns:Member(name)
	for _, key in ipairs({ strsplit(",", list) }) do
		if ns.achByKey[key] then m.ach[key] = true end
	end
	ns:RefreshUI()
end)

---------------------------------------------------------------------------
-- Auslöser, die zu keinem anderen Modul gehören
---------------------------------------------------------------------------
local function CheckZones()
	if not ns.cdb then return end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID or ns.IsSecret(mapID) then return end
	ns.cdb.zones[mapID] = true
	local n = 0
	for _ in pairs(ns.cdb.zones) do n = n + 1 end
	if n >= 10 then ns:Award("welt") end
end
ns:On("ZONE_CHANGED_NEW_AREA", CheckZones)

ns:On("GROUP_ROSTER_UPDATE", function()
	if not ns.db then return end
	for i = 1, 4 do
		local name = UnitName("party" .. i)
		if name and not ns.IsSecret(name) and ns:FindMember(name) then
			ns:Award("rudel")
			return
		end
	end
end)

ns:On("QUEST_TURNED_IN", function()
	if not ns.cdb then return end
	ns.cdb.questsDone = ns.cdb.questsDone + 1
	if ns.cdb.questsDone >= 50 then ns:Award("q50") end
	if ns.cdb.questsDone >= 250 then ns:Award("q250") end
end)

ns:OnReady(function()
	local me = ns:Member(ns.me)
	for key in pairs(ns.cdb.ach) do
		me.ach[key] = true
	end
	ns:CheckLevelAchievements(UnitLevel("player") or 0, true)
	local hour = tonumber(date("%H")) or 12
	if hour >= 2 and hour < 5 then
		C_Timer.After(8, function() ns:Award("eule") end)
	end
	CheckZones()
end)

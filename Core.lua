-- Die Crittler – Kern: Datenbank, Events, Nachrichten zwischen Gildenmitgliedern
local ADDON, ns = ...

ns.PREFIX = "CRITTLER"
-- Version steht in der .toc; CurseForge setzt dort beim Paketieren den Git-Tag ein.
-- Ohne Paketierung (Ordner direkt kopiert) bleibt der Platzhalter stehen -> "dev".
do
	local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = meta and meta(ADDON, "Version")
	if type(v) ~= "string" or v == "" or v:find("@", 1, true) then v = "dev" end
	ns.VERSION = v
end
ns.live = {} -- Laufzeitdaten pro Mitglied (zuletzt gesehen, Position)

local frame = CreateFrame("Frame")
local events, handlers, readyFns = {}, {}, {}

-- Midnight-Client: manche Werte sind im Kampf "geheim" und dürfen nicht gelesen werden
local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end
ns.IsSecret = IsSecret

function ns:On(event, fn)
	if not events[event] then
		events[event] = {}
		pcall(frame.RegisterEvent, frame, event) -- pcall: Event könnte im Client fehlen
	end
	tinsert(events[event], fn)
end

function ns:Handle(msgType, fn)
	handlers[msgType] = fn
end

function ns:OnReady(fn)
	tinsert(readyFns, fn)
end

function ns:Print(msg)
	print("|cffffd100Crittler:|r " .. tostring(msg))
end

function ns:RefreshUI() end -- wird in UI.lua überschrieben

---------------------------------------------------------------------------
-- Gilden-Sperre: alles nur für Mitglieder der Gilde "Die Crittler"
---------------------------------------------------------------------------
ns.GUILD = "Die Crittler"

-- Name der eigenen Gilde. nil = keine Gilde oder Gildendaten noch nicht geladen.
function ns:GuildName()
	if not IsInGuild() or not GetGuildInfo then return nil end
	local name = GetGuildInfo("player")
	if IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
	return name
end

function ns:InGuild()
	local name = ns:GuildName()
	return name ~= nil and strlower(strtrim(name)) == strlower(ns.GUILD)
end

-- Hinweistext für alle, die nicht in der Gilde sind
function ns:LockText()
	local name = ns:GuildName()
	if name then
		return format("Dieser Charakter ist in der Gilde „%s“. Das Addon zeigt nur Mitgliedern der Gilde „%s“ etwas an.", name, ns.GUILD)
	elseif IsInGuild() then
		return "Deine Gildendaten werden noch geladen. Einen Moment bitte …"
	end
	return format("Dieser Charakter ist in keiner Gilde. Das Addon zeigt nur Mitgliedern der Gilde „%s“ etwas an.", ns.GUILD)
end

-- Gilde betreten, verlassen oder Gildendaten nachgeladen: Fenster und Karte anpassen
local lastGuild
local function GuildChanged()
	local now = ns:InGuild()
	if now == lastGuild then return end
	lastGuild = now
	if ns.UpdatePins then ns.UpdatePins() end
	ns:RefreshUI()
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = events[event]
	if not list then return end
	for i = 1, #list do
		list[i](...)
	end
end)

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
local DB_DEFAULTS = {
	members = {},
	deathLog = {},
	events = {}, eventsGone = {},
	settings = { sound = true, toasts = true, pins = true, sharePos = true, lootQuality = 3,
		soundChannel = "Master", reminders = true, showInfo = true, recap = true,
		minimap = { hide = false, angle = 215 } },
}
local CHAR_DEFAULTS = {
	deaths = 0, lastDeath = 0, levelsNoDeath = 0,
	ach = {}, zones = {}, soundsPlayed = 0, questsDone = 0, wishes = {},
}

local function ApplyDefaults(t, d)
	for k, v in pairs(d) do
		if type(v) == "table" then
			if type(t[k]) ~= "table" then t[k] = {} end
			ApplyDefaults(t[k], v)
		elseif t[k] == nil then
			t[k] = v
		end
	end
end

function ns:Member(name)
	local m = ns.db.members[name]
	if not m then
		m = { name = name, level = 0, xp = 0, zone = "?", class = "NONE", deaths = 0, ach = {}, quests = {} }
		ns.db.members[name] = m
	end
	m.ach = m.ach or {}
	m.quests = m.quests or {}
	return m
end

-- WoW Forever hat Vor- und Nachnamen: UnitName liefert nur den Vornamen, Addon-Nachrichten
-- kommen aber mit vollem Namen an. Deshalb lernen wir den eigenen Namen aus dem Echo
-- einer eigenen Nachricht (siehe "ME" weiter unten).
function ns:IsMe(name)
	return name ~= nil and (name == ns.me or name == ns.unit)
end

-- Findet ein Mitglied auch dann, wenn nur der Vorname bekannt ist
function ns:FindMember(unitName)
	if not unitName or ns:IsMe(unitName) then return end
	local m = ns.db.members[unitName]
	if m and unitName ~= ns.me then return m end
	local prefix = unitName .. " "
	for name, member in pairs(ns.db.members) do
		if name ~= ns.me and name:sub(1, #prefix) == prefix then return member end
	end
end

-- Derselbe Spieler kann als "Clyde" und als "Clyde Zycho" auftauchen.
-- Canon() führt beide Schreibweisen auf einen Eintrag (den mit Nachnamen) zusammen.
local alias = {}

local function Rename(old, new)
	local db = ns.db
	if db.members[old] then
		if not db.members[new] then
			db.members[new] = db.members[old]
			db.members[new].name = new
		end
		db.members[old] = nil
	end
	for _, d in ipairs(db.deathLog) do
		if d.n == old then d.n = new end
	end
	if ns.live[old] then
		ns.live[new] = ns.live[new] or ns.live[old]
		ns.live[old] = nil
	end
	alias[old] = new
end
ns.Rename = Rename

function ns:Canon(name)
	if alias[name] then return alias[name] end
	local members = ns.db.members
	local first = name:match("^(%S+)%s")
	if first then
		-- voller Name: einen alten Eintrag nur mit Vornamen übernehmen
		if members[first] and first ~= ns.me then Rename(first, name) end
		return name
	end
	-- nur Vorname: gibt es genau einen Eintrag mit Nachnamen dazu?
	local prefix, hit, n = name .. " ", nil, 0
	for k in pairs(members) do
		if k:sub(1, #prefix) == prefix then hit, n = k, n + 1 end
	end
	if n == 1 then
		Rename(name, hit)
		return hit
	end
	return name
end

function ns:SetMyName(name)
	local old = ns.me
	ns.cdb.commName = name
	if name == old then return end
	ns.me = name
	local profs = ns.db.members[old] and ns.db.members[old].profs
	ns.db.members[old] = nil
	if ns.unit ~= name then ns.db.members[ns.unit] = nil end
	if profs then ns:Member(name).profs = profs end
	for _, d in ipairs(ns.db.deathLog) do
		if d.n == old then d.n = name end
	end
	ns.live[old] = nil
	local m = ns:Member(name)
	for key in pairs(ns.cdb.ach) do
		m.ach[key] = true
	end
	ns:SendStatus()
end

function ns:IsOnline(name)
	if name == ns.me then return true end
	local l = ns.live[name]
	return l ~= nil and l.seen ~= nil and (time() - l.seen) < 200
end

-- mode "ilvl": nach Gegenstandsstufe, sonst nach Level und XP
function ns:SortedMembers(mode)
	local list = {}
	for _, m in pairs(ns.db.members) do
		tinsert(list, m)
	end
	table.sort(list, function(a, b)
		if mode == "ilvl" and (a.ilvl or 0) ~= (b.ilvl or 0) then return (a.ilvl or 0) > (b.ilvl or 0) end
		if mode == "week" then
			local sa, sb = ns:WeekScore(a), ns:WeekScore(b)
			if sa ~= sb then return sa > sb end
		end
		if a.level ~= b.level then return a.level > b.level end
		if a.xp ~= b.xp then return a.xp > b.xp end
		return a.name < b.name
	end)
	return list
end

---------------------------------------------------------------------------
-- Nachrichten senden (gedrosselt, max. 1 pro Sekunde)
---------------------------------------------------------------------------
local queue, lastSend = {}, 0

function ns:CanSend()
	if not ns:InGuild() then return false end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return false end
	return true
end

local function Pump()
	if #queue == 0 then return end
	if not ns:CanSend() then
		wipe(queue)
		return
	end
	local wait = 1 - (GetTime() - lastSend)
	if wait > 0 then
		C_Timer.After(wait + 0.05, Pump)
		return
	end
	local msg = tremove(queue, 1)
	lastSend = GetTime()
	pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, msg, "GUILD")
	if #queue > 0 then
		C_Timer.After(1.05, Pump)
	end
end

function ns:Send(msgType, ...)
	if not ns:CanSend() then return end
	local msg = msgType
	for i = 1, select("#", ...) do
		msg = msg .. "^" .. tostring((select(i, ...)))
	end
	if #msg > 255 then return end
	if msgType == "PO" and #queue > 4 then return end -- Positionen nie stauen
	tinsert(queue, msg)
	if #queue == 1 then Pump() end
end

ns:On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
	if IsSecret(prefix) or IsSecret(msg) or IsSecret(channel) or IsSecret(sender) then return end
	if prefix ~= ns.PREFIX or channel ~= "GUILD" or not ns.db then return end
	if not ns:InGuild() then return end -- fremde Gilde: nichts annehmen
	local name = ns:Canon(Ambiguate(sender, "guild"))
	msg = msg:gsub("|", "||") -- keine fremden Farb-/Textur-Codes in Bannern und Tooltips
	local msgType, rest = strsplit("^", msg, 2)
	local h = handlers[msgType]
	if not h then return end
	ns.live[name] = ns.live[name] or {}
	ns.live[name].seen = time()
	local known = ns.db.members[name]
	if known then known.seen = time() end
	h(name, name == ns.me, strsplit("^", rest or ""))
end)

---------------------------------------------------------------------------
-- Status (Level, XP, Zone)
---------------------------------------------------------------------------
function ns:MyStatus()
	local level = UnitLevel("player") or 0
	local maxXP = UnitXPMax("player") or 0
	local xp = 0
	if maxXP > 0 then
		xp = floor((UnitXP("player") or 0) / maxXP * 100)
	end
	local _, class = UnitClass("player")
	return level, xp, GetRealZoneText() or "?", class or "NONE"
end

local ROLES = { TANK = true, HEALER = true, DAMAGER = true }
ns.ROLES = ROLES

-- Spezialisierung und Rolle. Die Rolle kann mit /crit rolle von Hand festgelegt werden
-- (z. B. wenn der Client keine Spezialisierungen kennt).
function ns:MySpec()
	local spec, role = "", ""
	local getSpec = GetSpecialization or (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
	local getInfo = GetSpecializationInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
	if getSpec and getInfo then
		pcall(function()
			local index = getSpec()
			if not index or IsSecret(index) then return end
			local _, name, _, _, r = getInfo(index)
			if type(name) == "string" and not IsSecret(name) then spec = name end
			if type(r) == "string" and ROLES[r] then role = r end
		end)
	end
	if ns.cdb and ROLES[ns.cdb.role or ""] then role = ns.cdb.role end
	return spec, role
end

-- Durchschnittliche Stufe der angelegten Ausrüstung (0 = unbekannt)
function ns:MyItemLevel()
	local result = 0
	pcall(function()
		if GetAverageItemLevel then
			local _, equipped = GetAverageItemLevel()
			if equipped and not IsSecret(equipped) then
				result = floor(equipped + 0.5)
				return
			end
		end
		local levelOf = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
		local sum, n = 0, 0
		for slot = 1, 18 do
			local link = slot ~= 4 and GetInventoryItemLink("player", slot) -- 4 = Hemd
			if link then
				local lvl = levelOf and levelOf(link)
				if not lvl and GetItemInfo then lvl = select(4, GetItemInfo(link)) end
				if lvl then sum, n = sum + lvl, n + 1 end
			end
		end
		if n > 0 then result = floor(sum / n + 0.5) end
	end)
	return result
end

function ns:SendStatus()
	if not ns.db then return end
	local level, xp, zone, class = ns:MyStatus()
	local spec, role = ns:MySpec()
	local ilvl = ns:MyItemLevel()
	local m = ns:Member(ns.me)
	m.level, m.xp, m.zone, m.class, m.deaths = level, xp, zone, class, ns.cdb.deaths
	m.spec = spec ~= "" and spec or nil
	m.role = role ~= "" and role or nil
	m.ilvl = ilvl > 0 and ilvl or nil
	ns:Send("ST", level, xp, zone, class, ns.cdb.deaths, ns.VERSION, UnitGUID and UnitGUID("player") or "", spec, role, ilvl)
	ns:RefreshUI()
end

local statusPending, lastStatus = false, 0
function ns:QueueStatus(delay)
	if statusPending then return end
	statusPending = true
	local wait = math.max(delay or 2, 20 - (GetTime() - lastStatus))
	C_Timer.After(wait, function()
		statusPending = false
		lastStatus = GetTime()
		ns:SendStatus()
	end)
end

local function VersionNum(v)
	local a, b, c = tostring(v or ""):match("^v?(%d+)%.(%d+)%.?(%d*)")
	if not a then return 0 end
	return tonumber(a) * 10000 + tonumber(b) * 100 + (tonumber(c) or 0)
end

local versionWarned = false

ns:Handle("ST", function(name, isMe, level, xp, zone, class, deaths, version, guid, spec, role, ilvl)
	if isMe then return end
	-- eigenes Echo unter noch unbekanntem vollen Namen: an der Charakter-ID erkennen
	if guid and guid ~= "" and guid == ns.guid then
		ns:SetMyName(name)
		return
	end
	-- gleiche Charakter-ID unter anderem Namen? Dann zusammenführen (längerer Name gewinnt)
	if guid and guid ~= "" then
		for other, om in pairs(ns.db.members) do
			if other ~= name and other ~= ns.me and om.guid == guid then
				if #other > #name then
					Rename(name, other)
					name = other
				else
					Rename(other, name)
				end
				break
			end
		end
	end
	local m = ns:Member(name)
	if guid and guid ~= "" then m.guid = guid end
	m.level = tonumber(level) or m.level
	m.xp = tonumber(xp) or m.xp
	m.zone = zone or m.zone
	m.class = class or m.class
	m.deaths = tonumber(deaths) or m.deaths
	if spec ~= nil then -- ältere Versionen schicken das Feld nicht
		m.spec = spec ~= "" and spec or nil
		m.role = ROLES[role or ""] and role or nil
	end
	ilvl = tonumber(ilvl)
	if ilvl then m.ilvl = ilvl > 0 and ilvl or nil end
	if version and version ~= "" then
		m.version = version
		if not versionWarned and VersionNum(version) > VersionNum(ns.VERSION) then
			versionWarned = true
			ns:Print(format("%s nutzt Version %s, du hast %s. Bitte aktualisieren.", name, version, ns.VERSION))
		end
	end
	ns:RefreshUI()
end)

-- "HI": jemand ist neu online und möchte den Stand von allen
ns:Handle("HI", function(name, isMe)
	if isMe then return end
	C_Timer.After(1 + random() * 3, function()
		ns:SendStatus()
		if ns.SendQuests then ns:SendQuests() end
		if ns.SendAchievements then ns:SendAchievements() end
		if ns.SendProfessions then ns:SendProfessions(true) end
		if ns.SendWishes then ns:SendWishes() end
		if ns.SendEvents then ns:SendEvents() end
		if ns.SendWeek then ns:SendWeek() end
	end)
end)

-- Eigenen Namen aus dem Echo lernen
local nonce = tostring(random(100000, 999999)) .. tostring(random(100000, 999999))
local helloSent, nameConfirmed = false, false
ns:Handle("ME", function(name, isMe, n)
	if n == nonce then
		nameConfirmed = true
		ns:SetMyName(name)
	end
end)

-- Begrüßung: eigenen Namen lernen und den Stand von allen anfordern.
-- Direkt nach dem Login sind die Gildendaten manchmal noch nicht da, deshalb mit Wiederholung.
local function Hello()
	GuildChanged()
	if not ns:CanSend() then
		C_Timer.After(10, Hello)
		return
	end
	helloSent = true
	ns:Send("ME", nonce)
	ns:Send("HI")
	ns:SendStatus()
	if ns.SendQuests then ns:SendQuests() end
	if ns.SendAchievements then ns:SendAchievements() end
	if ns.SendProfessions then ns:SendProfessions(true) end
	if ns.SendWishes then ns:SendWishes() end
	if ns.SendEvents then ns:SendEvents() end
	if ns.SendWeek then ns:SendWeek() end
	if ns.QueueRecap then ns:QueueRecap() end
end

ns:On("PLAYER_XP_UPDATE", function() ns:QueueStatus(5) end)
ns:On("ZONE_CHANGED_NEW_AREA", function() ns:QueueStatus(2) end)
ns:On("PLAYER_SPECIALIZATION_CHANGED", function() ns:QueueStatus(2) end)
ns:On("PLAYER_EQUIPMENT_CHANGED", function() ns:QueueStatus(5) end)
ns:On("PLAYER_GUILD_UPDATE", GuildChanged)
ns:On("GUILD_ROSTER_UPDATE", GuildChanged)

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
ns:On("PLAYER_LOGIN", function()
	ns.unit = UnitName("player")
	ns.guid = UnitGUID and UnitGUID("player") or nil
	CrittlerDB = CrittlerDB or {}
	CrittlerCharDB = CrittlerCharDB or {}
	ApplyDefaults(CrittlerDB, DB_DEFAULTS)
	ApplyDefaults(CrittlerCharDB, CHAR_DEFAULTS)
	ns.db, ns.cdb = CrittlerDB, CrittlerCharDB
	ns.me = ns.cdb.commName or ns.unit

	-- Doppelte Einträge aus älteren Versionen aufräumen
	local names = {}
	for name in pairs(ns.db.members) do
		tinsert(names, name)
	end
	for _, name in ipairs(names) do
		if ns.db.members[name] then ns:Canon(name) end
	end

	C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)

	for i = 1, #readyFns do
		readyFns[i]()
	end

	C_Timer.After(6, Hello)
	C_Timer.NewTicker(120, function()
		if not helloSent then return end
		if not nameConfirmed then ns:Send("ME", nonce) end
		ns:SendStatus()
	end)

	ns:Print("geladen. |cffffffff/crit|r öffnet das Fenster.")
end)

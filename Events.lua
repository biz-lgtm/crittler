-- Gruppensuche und Termine.
-- Beides ist dasselbe Ding: ein Eintrag mit Titel, Zeitpunkt und Zu-/Absagen.
-- kind = "call": "ich suche jetzt eine Gruppe" (läuft nach 45 Minuten ab)
-- kind = "date": Termin in der Zukunft (mit Erinnerung, verschwindet 2 Stunden danach)
local ADDON, ns = ...

local MAX_EVENTS, MAX_OWN = 12, 4
local CALL_TTL, DATE_TTL = 45 * 60, 2 * 3600
local ICON_CALL = "Interface\\Icons\\INV_Misc_GroupNeedMore"
local ICON_DATE = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local WEEKDAYS = { "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }

local function Clean(s)
	return strtrim((tostring(s):gsub("[%^|]", " ")))
end

---------------------------------------------------------------------------
-- Anzeige-Helfer
---------------------------------------------------------------------------
-- "Heute", "Morgen" oder "Fr 14.11."
function ns:DayLabel(t)
	local today = date("*t")
	local midnight = time({ year = today.year, month = today.month, day = today.day, hour = 0 })
	local diff = floor((t - midnight) / 86400)
	if diff == 0 then return "Heute" end
	if diff == 1 then return "Morgen" end
	return WEEKDAYS[date("*t", t).wday] .. " " .. date("%d.%m.", t)
end

function ns:EventWhen(ev)
	if ev.kind == "call" then return "sucht seit " .. date("%H:%M", ev.t) end
	return ns:DayLabel(ev.t) .. " " .. date("%H:%M", ev.t)
end

-- Zusagen (mit Rolle), Absagen und Rollen-Zähler
function ns:EventSummary(ev)
	local yes, no = {}, {}
	local count = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
	for name, v in pairs(ev.r or {}) do
		if v == "y" then
			local m = ns.db.members[name]
			local role = m and ns.ROLES[m.role or ""] and m.role or "NONE"
			count[role] = count[role] + 1
			tinsert(yes, { name = name, role = role })
		else
			tinsert(no, name)
		end
	end
	table.sort(yes, function(a, b) return a.name < b.name end)
	table.sort(no)
	return yes, no, count
end

---------------------------------------------------------------------------
-- Verwaltung
---------------------------------------------------------------------------
local function Prune()
	local now, changed = time(), false
	for id, ev in pairs(ns.db.events) do
		local ttl = ev.kind == "call" and CALL_TTL or DATE_TTL
		if type(ev.t) ~= "number" or now > ev.t + ttl then
			ns.db.events[id] = nil
			changed = true
		end
	end
	for id, expires in pairs(ns.db.eventsGone) do
		if now > expires then ns.db.eventsGone[id] = nil end
	end
	return changed
end

-- Gruppensuchen zuerst (neueste oben), dann Termine nach Zeitpunkt
function ns:SortedEvents()
	Prune()
	local list = {}
	for _, ev in pairs(ns.db.events) do
		tinsert(list, ev)
	end
	table.sort(list, function(a, b)
		if a.kind ~= b.kind then return a.kind == "call" end
		if a.t ~= b.t then
			if a.kind == "call" then return a.t > b.t end
			return a.t < b.t
		end
		return a.id < b.id
	end)
	return list
end

local function Announce(ev, from)
	if ev.kind == "call" then
		ns:Toast(ICON_CALL, from .. " sucht eine Gruppe!", ev.title, 8960)
	else
		ns:Toast(ICON_DATE, "Neuer Termin von " .. from, ns:EventWhen(ev) .. ": " .. ev.title, 878)
	end
end

-- kind "call": sofort. kind "date": dayOffset Tage ab heute, um hour:minute.
function ns:CreateEvent(kind, title, dayOffset, hour, minute)
	title = Clean(title or "")
	if title == "" then
		ns:Print("Bitte erst eintragen, worum es geht.")
		return false
	end
	if #title > 60 then
		ns:Print("Der Titel ist zu lang.")
		return false
	end
	Prune()
	local total, own = 0, 0
	for _, ev in pairs(ns.db.events) do
		total = total + 1
		if ns:IsMe(ev.by) then own = own + 1 end
	end
	if total >= MAX_EVENTS or own >= MAX_OWN then
		ns:Print("Es gibt schon zu viele offene Einträge. Erst alte absagen.")
		return false
	end

	local now = time()
	local t = now
	if kind == "date" then
		if not hour or hour > 23 or not minute or minute > 59 then
			ns:Print("Uhrzeit bitte so angeben: 20:00")
			return false
		end
		local d = date("*t")
		t = time({ year = d.year, month = d.month, day = d.day + (dayOffset or 0), hour = hour, min = minute, sec = 0 })
		if t <= now then
			ns:Print("Der Zeitpunkt liegt in der Vergangenheit.")
			return false
		end
	else
		kind = "call"
	end

	local id = tostring(now) .. tostring(random(100, 999))
	local ev = { id = id, t = t, kind = kind, title = title, by = ns.me, r = { [ns.me] = "y" } }
	ns.db.events[id] = ev
	ns:Send("EV", id, t, kind, 1, ns.me, title)
	if kind == "call" then
		ns:Print(format("Gruppensuche gestartet: %s", title))
	else
		ns:Print(format("Termin angelegt: %s, %s", ns:EventWhen(ev), title))
	end
	ns:RefreshUI()
	return true
end

function ns:ReplyEvent(id, answer)
	local ev = ns.db.events[id]
	if not ev then return end
	ev.r[ns.me] = answer == "y" and "y" or "n"
	ns:Send("ER", id, ev.r[ns.me])
	ns:RefreshUI()
end

function ns:CancelEvent(id)
	local ev = ns.db.events[id]
	if not ev or not ns:IsMe(ev.by) then return end
	ns.db.events[id] = nil
	ns.db.eventsGone[id] = time() + 7 * 86400
	ns:Send("EX", id)
	ns:Print(format("Abgesagt: %s", ev.title))
	ns:RefreshUI()
end

---------------------------------------------------------------------------
-- Abgleich
---------------------------------------------------------------------------
-- Antwort auf "HI": eigene Einträge, Einträge von Leuten die offline sind, und eigene Antworten
function ns:SendEvents()
	if not ns.db then return end
	Prune()
	for id, ev in pairs(ns.db.events) do
		if ns:IsMe(ev.by) or not ns:IsOnline(ev.by) then
			ns:Send("EV", id, ev.t, ev.kind, 0, ev.by, ev.title)
		end
		if ev.r[ns.me] then ns:Send("ER", id, ev.r[ns.me]) end
	end
end

-- isNew = "1": frisch angelegt (mit Banner), sonst Abgleich für später Eingeloggte
ns:Handle("EV", function(name, isMe, id, t, kind, isNew, by, title)
	if isMe then return end
	t = tonumber(t)
	if not id or id == "" or not t or not title or title == "" then return end
	if ns.db.events[id] or ns.db.eventsGone[id] then return end
	kind = kind == "call" and "call" or "date"
	local now = time()
	if now > t + (kind == "call" and CALL_TTL or DATE_TTL) or t > now + 60 * 86400 then return end
	local fresh = isNew == "1"
	if fresh or not by or by == "" then by = name end
	if ns:IsMe(by) then return end -- eigener Eintrag, den ich nicht mehr habe: wurde abgesagt

	local total = 0
	for _ in pairs(ns.db.events) do total = total + 1 end
	if total >= MAX_EVENTS then return end

	local ev = { id = id, t = t, kind = kind, title = title, by = by, r = { [by] = "y" } }
	ns.db.events[id] = ev
	if fresh then Announce(ev, name) end
	ns:RefreshUI()
end)

ns:Handle("ER", function(name, isMe, id, answer)
	if isMe then return end
	local ev = id and ns.db.events[id]
	if not ev then return end
	local before = ev.r[name]
	ev.r[name] = answer == "y" and "y" or "n"
	if ns:IsMe(ev.by) and before ~= ev.r[name] then
		ns:Print(format("|cff66ff66%s|r %s: %s", name, ev.r[name] == "y" and "ist dabei" or "hat abgesagt", ev.title))
	end
	ns:RefreshUI()
end)

ns:Handle("EX", function(name, isMe, id)
	if isMe then return end
	local ev = id and ns.db.events[id]
	if not ev or ev.by ~= name then return end
	ns.db.events[id] = nil
	ns.db.eventsGone[id] = time() + 7 * 86400
	ns:Print(format("%s hat abgesagt: %s", name, ev.title))
	ns:RefreshUI()
end)

---------------------------------------------------------------------------
-- Erinnerungen
---------------------------------------------------------------------------
local function Tick()
	if not ns.db then return end
	local changed = Prune()
	if ns.db.settings.reminders and ns:InGuild() then
		local now = time()
		for _, ev in pairs(ns.db.events) do
			if ev.kind == "date" and ev.r[ns.me] ~= "n" then
				local left = ev.t - now
				if left <= 0 and left > -600 and not ev.remStart then
					ev.remStart, ev.rem15 = true, true
					ns:Toast(ICON_DATE, "Es geht los!", ev.title, 8960)
				elseif left > 0 and left <= 900 and not ev.rem15 then
					ev.rem15 = true
					ns:Toast(ICON_DATE, format("In %d Minuten", ceil(left / 60)), ev.title, 8959)
				end
			end
		end
	end
	if changed then ns:RefreshUI() end
end

local function LoginSummary()
	if not ns.db or not ns.db.settings.reminders or not ns:InGuild() then return end
	local list = ns:SortedEvents()
	if #list == 0 then return end
	ns:Print("Offene Termine:")
	for _, ev in ipairs(list) do
		local mine = ev.r[ns.me]
		local state = mine == "y" and "|cff66ff66dabei|r" or mine == "n" and "|cffff6666abgesagt|r" or "|cffffd100noch offen|r"
		print(format("  %s – %s (%s)", ns:EventWhen(ev), ev.title, state))
	end
end

ns:OnReady(function()
	Prune()
	C_Timer.NewTicker(30, Tick)
	C_Timer.After(12, LoginSummary)
end)

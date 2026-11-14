-- Rückblick beim Einloggen: was hat sich seit dem letzten Besuch getan?
-- Beim Start wird der gespeicherte Stand aller Mitglieder festgehalten. Nach der Begrüßung
-- schicken alle, die online sind, ihren aktuellen Stand; der Unterschied landet im Chat.
local ADDON, ns = ...

local MAX_LINES = 8
local WAIT = 20 -- Sekunden nach der Begrüßung, bis die Antworten da sind

local snap, snapByGuid = {}, {}
local lastVisit, queued = nil, false

local function TakeSnapshot()
	lastVisit = ns.db.lastLogout
	for name, m in pairs(ns.db.members) do
		local ach = {}
		for key in pairs(m.ach or {}) do
			ach[key] = true
		end
		local s = { level = m.level or 0, deaths = m.deaths or 0, ach = ach }
		snap[name] = s
		if m.guid then snapByGuid[m.guid] = s end
	end
end

-- Stand vom letzten Besuch; Namen können inzwischen einen Nachnamen bekommen haben
local function Before(m)
	local s = snap[m.name] or (m.guid and snapByGuid[m.guid])
	if s then return s end
	local first = m.name:match("^(%S+)%s")
	return first and snap[first] or nil
end

local function Ago(seconds)
	if seconds < 3600 then
		local n = math.max(1, floor(seconds / 60))
		return format("vor %d %s", n, n == 1 and "Minute" or "Minuten")
	elseif seconds < 172800 then
		local n = floor(seconds / 3600)
		return format("vor %d %s", n, n == 1 and "Stunde" or "Stunden")
	end
	return format("vor %d Tagen", floor(seconds / 86400))
end

local function Collect()
	local out = {}
	for name, m in pairs(ns.db.members) do
		if name ~= ns.me and not ns:IsMe(name) then
			local s = Before(m)
			local level = m.level or 0
			if not s then
				if level > 0 then
					tinsert(out, { score = 1000 + level, text = format("|cff66ff66%s|r ist neu dabei (Level %d)", name, level) })
				end
			else
				local parts, score = {}, 0
				if s.level > 0 and level > s.level then
					tinsert(parts, format("von Level %d auf %d gestiegen", s.level, level))
					score = score + (level - s.level) * 10
				end
				local died = (m.deaths or 0) - s.deaths
				if died > 0 then
					tinsert(parts, format("%d-mal gestorben", died))
					score = score + died
				end
				local names = {}
				for key in pairs(m.ach or {}) do
					local a = ns.achByKey[key]
					if a and not s.ach[key] then tinsert(names, a.name) end
				end
				if #names > 2 then
					tinsert(parts, #names .. " neue Erfolge")
				elseif #names > 0 then
					table.sort(names)
					tinsert(parts, (#names == 1 and "neuer Erfolg: " or "neue Erfolge: ") .. table.concat(names, ", "))
				end
				score = score + #names * 3
				if #parts > 0 then
					tinsert(out, { score = score, text = format("|cff66ff66%s|r: %s", name, table.concat(parts, ", ")) })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.text < b.text
	end)
	return out
end

local function Show()
	if not ns.db or not ns.db.settings.recap or not ns:InGuild() then return end
	local away = time() - lastVisit
	local list = Collect()
	if #list == 0 then
		-- nach einem /reload oder kurzem Umloggen nicht stören
		if away >= 600 then
			ns:Print(format("Nichts Neues seit deinem letzten Besuch (%s).", Ago(away)))
		end
		return
	end
	ns:Print(format("Seit deinem letzten Besuch (%s):", Ago(away)))
	for i = 1, math.min(#list, MAX_LINES) do
		print("  " .. list[i].text)
	end
	if #list > MAX_LINES then
		print(format("  … und %d weitere. Alles Weitere steht im Fenster (/crit).", #list - MAX_LINES))
	end
end

-- Wird von Core.lua aufgerufen, sobald die Begrüßung verschickt ist
function ns:QueueRecap()
	if queued or not lastVisit then return end -- erster Start: noch kein Vergleich möglich
	queued = true
	C_Timer.After(WAIT, Show)
end

ns:OnReady(TakeSnapshot)

ns:On("PLAYER_LOGOUT", function()
	if ns.db then ns.db.lastLogout = time() end
end)

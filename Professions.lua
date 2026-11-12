-- Berufe: wer hat welchen Beruf auf welcher Stufe?
local ADDON, ns = ...

local MAX_ENTRIES = 8

-- Liefert die eigenen Berufe als Liste { n = Name, l = Stufe, m = Maximum, i = Icon }
-- oder nil, wenn die Werte gerade nicht lesbar sind.
local function Collect()
	local out = {}

	-- Moderner Client: bis zu zwei Hauptberufe + Archäologie, Angeln, Kochen
	if GetProfessions and GetProfessionInfo then
		local a, b, c, d, e = GetProfessions()
		for _, index in pairs({ a = a, b = b, c = c, d = d, e = e }) do
			local name, icon, level, max = GetProfessionInfo(index)
			if ns.IsSecret(name) or ns.IsSecret(level) or ns.IsSecret(max) then return nil end
			if name and level then
				tinsert(out, { n = name, l = level, m = max or 0, i = type(icon) == "number" and icon or nil })
			end
		end
		return out
	end

	-- Classic-Client: Fertigkeiten-Liste, nur die Abschnitte mit Berufen
	if GetNumSkillLines and GetSkillLineInfo then
		local secondary = SECONDARY_SKILLS and (SECONDARY_SKILLS:gsub(":%s*$", ""))
		local inProfessions = false
		for i = 1, GetNumSkillLines() do
			local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
			if isHeader then
				inProfessions = name ~= nil and (name == TRADE_SKILLS or name == secondary)
			elseif inProfessions and name and rank and #out < MAX_ENTRIES then
				tinsert(out, { n = name, l = rank, m = maxRank or 0 })
			end
		end
		return out
	end

	return out
end

local function Encode(list)
	local parts = {}
	for _, p in ipairs(list) do
		local name = tostring(p.n):gsub("[%^,:]", " ")
		tinsert(parts, format("%s:%d:%d:%d", name, p.l or 0, p.m or 0, p.i or 0))
	end
	return table.concat(parts, ",")
end

local lastSent

-- force = true: auch senden, wenn sich nichts geändert hat (z. B. Antwort auf "HI")
function ns:SendProfessions(force)
	if not ns.db then return end
	local list = Collect()
	if not list then return end
	table.sort(list, function(x, y) return x.n < y.n end)
	ns:Member(ns.me).profs = list
	local msg = Encode(list)
	if not force and msg == lastSent then return end
	if not ns:CanSend() then return end
	lastSent = msg
	ns:Send("PR", msg)
	ns:RefreshUI()
end

ns:Handle("PR", function(name, isMe, list)
	if isMe then return end
	local profs = {}
	if list and list ~= "" then
		for _, entry in ipairs({ strsplit(",", list) }) do
			local n, l, m, i = strsplit(":", entry)
			l, m, i = tonumber(l), tonumber(m), tonumber(i)
			if n and n ~= "" and l and #profs < MAX_ENTRIES then
				tinsert(profs, { n = n, l = l, m = m or 0, i = (i and i > 0) and i or nil })
			end
		end
	end
	ns:Member(name).profs = profs
	ns:RefreshUI()
end)

-- Liste für das Fenster: pro Beruf alle Mitglieder, höchste Stufe zuerst
-- filter (optional): Teil eines Berufs- oder Spielernamens
function ns:ProfessionGroups(filter)
	filter = (filter and filter ~= "") and strlower(filter) or nil
	local groups, order = {}, {}
	for _, member in pairs(ns.db.members) do
		for _, p in ipairs(member.profs or {}) do
			if not filter or strlower(p.n):find(filter, 1, true) or strlower(member.name):find(filter, 1, true) then
				local g = groups[p.n]
				if not g then
					g = { name = p.n, list = {} }
					groups[p.n] = g
					tinsert(order, g)
				end
				g.icon = g.icon or p.i
				tinsert(g.list, { member = member, level = p.l or 0, max = p.m or 0 })
			end
		end
	end
	table.sort(order, function(x, y) return x.name < y.name end)
	for _, g in ipairs(order) do
		table.sort(g.list, function(x, y)
			if x.level ~= y.level then return x.level > y.level end
			return x.member.name < y.member.name
		end)
	end
	return order
end

-- /crit beruf <text>: wer kann das?
function ns:PrintProfessions(filter)
	local groups = ns:ProfessionGroups(filter)
	if #groups == 0 then
		ns:Print("Kein Crittler mit passendem Beruf gefunden.")
		return
	end
	ns:Print("Berufe:")
	for _, g in ipairs(groups) do
		local parts = {}
		for _, e in ipairs(g.list) do
			local color = ns:IsOnline(e.member.name) and "|cff66ff66" or "|cff999999"
			local level = e.max > 0 and (e.level .. "/" .. e.max) or tostring(e.level)
			tinsert(parts, color .. e.member.name .. "|r " .. level)
		end
		print("  |cffffd100" .. g.name .. ":|r " .. table.concat(parts, ", "))
	end
end

local pending = false
local function QueueSend()
	if pending then return end
	pending = true
	C_Timer.After(5, function()
		pending = false
		ns:SendProfessions()
	end)
end

ns:On("SKILL_LINES_CHANGED", QueueSend)
ns:On("CHAT_MSG_SKILL", QueueSend)

ns:OnReady(function()
	local list = Collect()
	if list then
		table.sort(list, function(x, y) return x.n < y.n end)
		ns:Member(ns.me).profs = list
	end
end)

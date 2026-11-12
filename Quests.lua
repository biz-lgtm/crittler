-- Gemeinsame Quests: wer hat dieselbe Quest im Log?
local ADDON, ns = ...

local buffers = {}

-- Liefert eigene Quest-IDs und deren Titel
function ns:MyQuests()
	local ids, titles = {}, {}
	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
		return ids, titles
	end
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
			tinsert(ids, info.questID)
			titles[info.questID] = info.title or ("Quest " .. info.questID)
		end
	end
	return ids, titles
end

function ns:SendQuests()
	local ids = ns:MyQuests()
	local chunks, chunk = {}, ""
	for _, id in ipairs(ids) do
		local s = tostring(id)
		if #chunk + #s > 200 then
			tinsert(chunks, chunk)
			chunk = ""
		end
		chunk = chunk == "" and s or (chunk .. "," .. s)
	end
	tinsert(chunks, chunk)
	for i, c in ipairs(chunks) do
		ns:Send("QS", i, #chunks, c)
	end
end

local pending = false
local function QueueSend()
	if pending then return end
	pending = true
	C_Timer.After(3, function()
		pending = false
		ns:SendQuests()
		ns:RefreshUI()
	end)
end

ns:Handle("QS", function(name, isMe, i, n, list)
	if isMe then return end
	i, n = tonumber(i), tonumber(n)
	if not i or not n then return end
	if i == 1 then buffers[name] = {} end
	local buf = buffers[name]
	if not buf then return end
	if list and list ~= "" then
		for _, s in ipairs({ strsplit(",", list) }) do
			local id = tonumber(s)
			if id then buf[id] = true end
		end
	end
	if i == n then
		ns:Member(name).quests = buf
		buffers[name] = nil
		ns:RefreshUI()
	end
end)

-- Wer (online) hat diese Quest ebenfalls?
function ns:WhoHasQuest(questID)
	local names = {}
	for name, m in pairs(ns.db.members) do
		if name ~= ns.me and m.quests and m.quests[questID] and ns:IsOnline(name) then
			tinsert(names, name)
		end
	end
	table.sort(names)
	return names
end

-- Liste für das Fenster: eigene Quests, die auch andere haben
function ns:SharedQuests()
	local ids, titles = ns:MyQuests()
	local out = {}
	for _, id in ipairs(ids) do
		local names = ns:WhoHasQuest(id)
		if #names > 0 then
			tinsert(out, { id = id, title = titles[id], names = names })
		end
	end
	table.sort(out, function(a, b) return a.title < b.title end)
	return out
end

ns:On("QUEST_ACCEPTED", function(a, b)
	if not ns.db then return end
	local questID = b or a -- je nach Client (Index, ID) oder nur (ID)
	if type(questID) == "number" then
		local names = ns:WhoHasQuest(questID)
		if #names > 0 then
			local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
			ns:Print(format("|cff66ff66%s|r hat die Quest „%s“ auch. Tut euch zusammen!",
				table.concat(names, ", "), title or "?"))
		end
	end
	QueueSend()
end)
ns:On("QUEST_REMOVED", QueueSend)
ns:On("QUEST_TURNED_IN", QueueSend)

-- Wochenstatistik: was hat jeder seit Montag geschafft?
-- Jeder zählt für sich selbst und schickt seinen Stand an die Gilde.
local ADDON, ns = ...

-- Punkte für den "Crittler der Woche"
local POINTS = { l = 10, q = 1, o = 3, d = -2 } -- Level, Quest, seltene Beute, Tod
local ZERO = { l = 0, q = 0, o = 0, d = 0 }

-- Montag 00:00 der laufenden Woche (Ortszeit)
local function WeekStart()
	local d = date("*t")
	local sinceMonday = (d.wday + 5) % 7 -- wday: 1 = Sonntag
	return time({ year = d.year, month = d.month, day = d.day - sinceMonday, hour = 0 })
end

-- Eigener Wochenstand; wird am Montag automatisch geleert
function ns:Week()
	local w = ns.cdb.week
	local start = WeekStart()
	if type(w) ~= "table" or w.s ~= start then
		w = { s = start, l = 0, q = 0, o = 0, d = 0 }
		ns.cdb.week = w
	end
	return w
end

-- Wochenstand eines Mitglieds (Nullen, wenn nichts aus dieser Woche bekannt ist)
function ns:WeekOf(m)
	if m.name == ns.me then return ns:Week() end
	local w = m.week
	if type(w) ~= "table" or not w.s or math.abs(w.s - WeekStart()) > 86400 then return ZERO end
	return w
end

function ns:WeekScore(m)
	local w = ns:WeekOf(m)
	return (w.l or 0) * POINTS.l + (w.q or 0) * POINTS.q + (w.o or 0) * POINTS.o + (w.d or 0) * POINTS.d
end

function ns:SendWeek()
	if not ns.cdb then return end
	local w = ns:Week()
	ns:Send("WK", w.s, w.l, w.q, w.o, w.d)
end

local pending = false
-- key: "l" Level, "q" Quest, "o" seltene Beute, "d" Tod
function ns:WeekAdd(key)
	if not ns.cdb then return end
	local w = ns:Week()
	w[key] = (w[key] or 0) + 1
	ns:RefreshUI()
	if pending then return end
	pending = true
	C_Timer.After(5, function()
		pending = false
		ns:SendWeek()
	end)
end

ns:Handle("WK", function(name, isMe, s, l, q, o, d)
	if isMe then return end
	s = tonumber(s)
	if not s then return end
	ns:Member(name).week = {
		s = s, l = tonumber(l) or 0, q = tonumber(q) or 0, o = tonumber(o) or 0, d = tonumber(d) or 0,
	}
	ns:RefreshUI()
end)

ns:OnReady(function() ns:Week() end)

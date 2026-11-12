-- Hauptfenster mit Reitern + Slash-Befehle
local ADDON, ns = ...

local WIDTH, HEIGHT = 540, 500
local PAD, HEADER_H, TABS_H, FOOTER_H = 14, 46, 30, 38
local W = WIDTH - PAD * 2 - 8
local VIEW_H = HEIGHT - HEADER_H - TABS_H - 10 - FOOTER_H - 6
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TABS = { "Rennen", "Tode", "Quests", "Berufe", "Erfolge", "Sounds" }
local RANK = { { 1, 0.82, 0 }, { 0.8, 0.8, 0.85 }, { 0.8, 0.5, 0.25 }, [0] = { 0.5, 0.5, 0.5 } }
local current = "Rennen"

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
local function Skin(frame, r, g, b, a)
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	frame:SetBackdropColor(r, g, b, a)
	frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function FS(parent, font, width, justify)
	local s = parent:CreateFontString(nil, "OVERLAY", font)
	if width then s:SetWidth(width) end
	s:SetJustifyH(justify or "LEFT")
	s:SetWordWrap(false)
	return s
end

local function Bar(parent, w, h, r, g, b)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(w, h)
	bar:SetStatusBarTexture(WHITE)
	bar:SetStatusBarColor(r, g, b)
	bar:SetMinMaxValues(0, 100)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(1, 1, 1, 0.08)
	bar.text = FS(bar, "GameFontHighlightSmall", nil, "CENTER")
	bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	return bar
end

local function FlatButton(parent, w, h, label)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w, h)
	Skin(b, 0.14, 0.14, 0.18, 1)
	b.text = FS(b, "GameFontHighlight", nil, "CENTER")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetText(label or "")
	b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.24, 0.22, 0.14, 1) end)
	b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.14, 0.18, 1) end)
	return b
end

local function ClassColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function AchCount(m)
	local n = 0
	for key in pairs(m.ach or {}) do
		if ns.achByKey[key] then n = n + 1 end
	end
	return n
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local f = CreateFrame("Frame", "CrittlerFrame", UIParent, "BackdropTemplate")
f:SetSize(WIDTH, HEIGHT)
f:SetPoint("CENTER")
f:SetFrameStrata("MEDIUM")
f:SetToplevel(true)
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
Skin(f, 0.05, 0.05, 0.07, 0.97)
f:Hide()
tinsert(UISpecialFrames, "CrittlerFrame") -- schließt mit ESC

local headBg = f:CreateTexture(nil, "BORDER")
headBg:SetColorTexture(0.1, 0.1, 0.13, 1)
headBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
headBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
headBg:SetHeight(HEADER_H + TABS_H)

local accent = f:CreateTexture(nil, "ARTWORK")
accent:SetColorTexture(1, 0.82, 0, 1)
accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
accent:SetHeight(2)

local logo = f:CreateTexture(nil, "ARTWORK")
logo:SetSize(28, 28)
logo:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -11)
logo:SetTexture("Interface\\Icons\\Ability_CriticalStrike")
logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local title = FS(f, "GameFontNormalLarge")
title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
title:SetText("Die Crittler")

local summary = FS(f, "GameFontDisableSmall", 220, "RIGHT")
summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -20)

local close = FlatButton(f, 22, 22, "X")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -13)
close:SetScript("OnClick", function() f:Hide() end)

-- Scrollbereich (Mausrad) mit schmalem Balken
local scroll = CreateFrame("ScrollFrame", nil, f)
scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + TABS_H + 10))
scroll:SetSize(W, VIEW_H)
local child = CreateFrame("Frame", nil, scroll)
child:SetSize(W, 1)
scroll:SetScrollChild(child)

local thumb = f:CreateTexture(nil, "OVERLAY")
thumb:SetColorTexture(1, 0.82, 0, 0.5)
thumb:SetWidth(3)

local contentH, scrollPos = 1, 0
local function UpdateScroll()
	local range = math.max(0, contentH - VIEW_H)
	scrollPos = math.max(0, math.min(scrollPos, range))
	scroll:SetVerticalScroll(scrollPos)
	if range <= 0 then
		thumb:Hide()
		return
	end
	local th = math.max(24, VIEW_H * VIEW_H / contentH)
	thumb:SetHeight(th)
	thumb:ClearAllPoints()
	thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 7, -(VIEW_H - th) * scrollPos / range)
	thumb:Show()
end
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(_, delta)
	scrollPos = scrollPos - (delta or 0) * 44
	UpdateScroll()
end)

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
local pools = {}

local function HideAll()
	for _, pool in pairs(pools) do
		for _, r in ipairs(pool) do
			r:Hide()
		end
	end
end

local function Acquire(kind, i, factory, y, height)
	pools[kind] = pools[kind] or {}
	local r = pools[kind][i]
	if not r then
		r = factory()
		pools[kind][i] = r
	end
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
	r:SetAlpha(1)
	r:Show()
	return r, y + height
end

local function BaseRow(h)
	local r = CreateFrame("Frame", nil, child)
	r:SetSize(W, h)
	r.bg = r:CreateTexture(nil, "BACKGROUND")
	r.bg:SetAllPoints()
	r.bg:SetColorTexture(1, 1, 1, 0.035)
	r.hl = r:CreateTexture(nil, "BORDER")
	r.hl:SetAllPoints()
	r.hl:SetColorTexture(1, 0.82, 0, 0.09)
	r.hl:Hide()
	r:EnableMouse(true)
	r:SetScript("OnEnter", function(self)
		self.hl:Show()
		if self.tip then self.tip(self) end
	end)
	r:SetScript("OnLeave", function(self)
		self.hl:Hide()
		GameTooltip:Hide()
	end)
	return r
end

local function MemberTip(self)
	local m = self.member
	if not m then return end
	local online = ns:IsOnline(m.name)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(m.name, ClassColor(m.class))
	GameTooltip:AddDoubleLine("Level", format("%d (%d%%)", m.level or 0, m.xp or 0), 0.7, 0.7, 0.7, 1, 1, 1)
	GameTooltip:AddDoubleLine("Zone", m.zone or "?", 0.7, 0.7, 0.7, 1, 1, 1)
	GameTooltip:AddDoubleLine("Tode", tostring(m.deaths or 0), 0.7, 0.7, 0.7, 1, 1, 1)
	GameTooltip:AddDoubleLine("Erfolge", AchCount(m) .. " / " .. #ns.achievements, 0.7, 0.7, 0.7, 1, 1, 1)
	for _, p in ipairs(m.profs or {}) do
		GameTooltip:AddDoubleLine(p.n, (p.m or 0) > 0 and (p.l .. " / " .. p.m) or tostring(p.l), 0.7, 0.7, 0.7, 0.5, 0.75, 1)
	end
	local version = m.name == ns.me and ns.VERSION or m.version
	if version then
		GameTooltip:AddDoubleLine("Version", version, 0.7, 0.7, 0.7, 1, 1, 1)
	end
	if online then
		GameTooltip:AddLine("Online", 0.3, 0.9, 0.3)
	elseif m.seen then
		GameTooltip:AddLine("Zuletzt gesehen: " .. date("%d.%m. %H:%M", m.seen), 0.6, 0.6, 0.6)
	else
		GameTooltip:AddLine("Offline", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local function RaceRow()
	local r = BaseRow(36)
	r.me = r:CreateTexture(nil, "ARTWORK")
	r.me:SetColorTexture(1, 0.82, 0, 1)
	r.me:SetSize(2, 36)
	r.me:SetPoint("LEFT", r, "LEFT", 0, 0)
	r.rank = FS(r, "GameFontNormalLarge", 24, "CENTER")
	r.rank:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.dot = r:CreateTexture(nil, "ARTWORK")
	r.dot:SetSize(8, 8)
	r.dot:SetPoint("LEFT", r, "LEFT", 42, 0)
	r.name = FS(r, "GameFontHighlight", 150)
	r.name:SetPoint("LEFT", r, "LEFT", 58, 0)
	r.level = FS(r, "GameFontNormalLarge", 36, "RIGHT")
	r.level:SetPoint("LEFT", r, "LEFT", 210, 0)
	r.bar = Bar(r, 110, 14, 0.55, 0.3, 0.9)
	r.bar:SetPoint("LEFT", r, "LEFT", 258, 0)
	r.zone = FS(r, "GameFontHighlightSmall", W - 258 - 110 - 20, "RIGHT")
	r.zone:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	r.tip = MemberTip
	return r
end

local function HeadRow()
	local r = CreateFrame("Frame", nil, child)
	r:SetSize(W, 30)
	r.text = FS(r, "GameFontNormal", W - 8)
	r.text:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 4, 7)
	r.line = r:CreateTexture(nil, "ARTWORK")
	r.line:SetColorTexture(1, 0.82, 0, 0.35)
	r.line:SetSize(W, 1)
	r.line:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 2)
	return r
end

local function BarRow()
	local r = BaseRow(26)
	r.name = FS(r, "GameFontHighlight", 160)
	r.name:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.bar = Bar(r, 230, 12, 0.8, 0.2, 0.2)
	r.bar:SetPoint("LEFT", r, "LEFT", 176, 0)
	r.value = FS(r, "GameFontHighlight", 80, "RIGHT")
	r.value:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	r.tip = MemberTip
	return r
end

local function LineRow()
	local r = BaseRow(24)
	r.left = FS(r, "GameFontHighlight", W - 200)
	r.left:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.right = FS(r, "GameFontHighlightSmall", 170, "RIGHT")
	r.right:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	return r
end

local function AchRow()
	local r = BaseRow(52)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(36, 36)
	r.icon:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.name = FS(r, "GameFontNormal", W - 150)
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, 1)
	r.desc = FS(r, "GameFontHighlightSmall", W - 70)
	r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
	r.who = FS(r, "GameFontDisableSmall", W - 70)
	r.who:SetPoint("TOPLEFT", r.desc, "BOTTOMLEFT", 0, -2)
	r.when = FS(r, "GameFontDisableSmall", 80, "RIGHT")
	r.when:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -9)
	return r
end

local function SoundButton()
	local b = FlatButton(child, (W - 16) / 3, 34)
	b:SetScript("OnClick", function(self)
		if self.key then ns:PlayBoard(self.key) end
	end)
	return b
end

local function Head(i, y, text)
	local r
	r, y = Acquire("head", i, HeadRow, y, 34)
	r.text:SetText(text)
	return y
end

local function Line(i, y, left, right)
	local r
	r, y = Acquire("line", i, LineRow, y, 25)
	r.bg:SetShown(i % 2 == 1)
	r.left:SetText(left or "")
	r.right:SetText(right or "")
	return y
end

---------------------------------------------------------------------------
-- Reiter-Inhalte
---------------------------------------------------------------------------
local render = {}

render["Rennen"] = function()
	local y = 0
	for i, m in ipairs(ns:SortedMembers()) do
		local r
		r, y = Acquire("race", i, RaceRow, y, 38)
		local online = ns:IsOnline(m.name)
		local rc = RANK[i] or RANK[0]
		r.member = m
		r.bg:SetShown(i % 2 == 1)
		r.me:SetShown(m.name == ns.me)
		r.rank:SetText(i)
		r.rank:SetTextColor(rc[1], rc[2], rc[3])
		if online then
			r.dot:SetColorTexture(0.25, 0.9, 0.3, 1)
		else
			r.dot:SetColorTexture(0.4, 0.4, 0.4, 1)
		end
		r.name:SetText(m.name)
		r.name:SetTextColor(ClassColor(m.class))
		r.level:SetText(m.level or 0)
		r.bar:SetValue(m.xp or 0)
		r.bar.text:SetText((m.xp or 0) .. "%")
		r.zone:SetText(m.zone or "?")
		if not online then r:SetAlpha(0.5) end
	end
	return y
end

render["Tode"] = function()
	local list = ns:SortedMembers()
	table.sort(list, function(a, b)
		if (a.deaths or 0) ~= (b.deaths or 0) then return (a.deaths or 0) > (b.deaths or 0) end
		return a.name < b.name
	end)
	local most = math.max(1, list[1] and list[1].deaths or 0)

	local y = Head(1, 0, "Wall of Shame")
	for i, m in ipairs(list) do
		local r
		r, y = Acquire("bar", i, BarRow, y, 27)
		local d = m.deaths or 0
		r.member = m
		r.bg:SetShown(i % 2 == 1)
		r.name:SetText(m.name)
		r.name:SetTextColor(ClassColor(m.class))
		r.bar:SetStatusBarColor(0.8, 0.2, 0.2)
		r.bar:SetValue(d / most * 100)
		r.bar.text:SetText("")
		r.value:SetText(d .. (d == 1 and " Tod" or " Tode"))
	end

	y = Head(2, y + 8, "Letzte Tode")
	if #ns.db.deathLog == 0 then
		y = Line(1, y, "|cff888888Noch niemand gestorben. Respekt.|r")
	end
	for i, d in ipairs(ns.db.deathLog) do
		y = Line(i, y, d.n .. "  |cff888888" .. (d.z or "?") .. "|r", date("%d.%m. %H:%M", d.t))
	end
	return y
end

render["Quests"] = function()
	local y = Head(1, 0, "Diese Quests habt ihr gemeinsam")
	local shared = ns:SharedQuests()
	if #shared == 0 then
		return Line(1, y, "|cff888888Gerade teilt niemand online eine Quest mit dir.|r")
	end
	for i, q in ipairs(shared) do
		y = Line(i, y, q.title, "|cff66ff66" .. table.concat(q.names, ", ") .. "|r")
	end
	return y
end

render["Berufe"] = function()
	local groups = ns:ProfessionGroups()
	if #groups == 0 then
		local y = Head(1, 0, "Berufe der Crittler")
		return Line(1, y, "|cff888888Noch keine Berufe bekannt.|r")
	end
	local y, n = 0, 0
	for gi, g in ipairs(groups) do
		local icon = g.icon and ("|T" .. g.icon .. ":16:16:0:0:64:64:5:59:5:59|t ") or ""
		y = Head(gi, y + (gi > 1 and 8 or 0), icon .. g.name)
		for _, e in ipairs(g.list) do
			n = n + 1
			local r
			r, y = Acquire("bar", n, BarRow, y, 27)
			r.member = e.member
			r.bg:SetShown(n % 2 == 1)
			r.name:SetText(e.member.name)
			r.name:SetTextColor(ClassColor(e.member.class))
			r.bar:SetStatusBarColor(0.3, 0.6, 0.9)
			r.bar:SetValue(e.max > 0 and (e.level / e.max * 100) or 0)
			r.bar.text:SetText("")
			r.value:SetText(e.max > 0 and (e.level .. " / " .. e.max) or tostring(e.level))
		end
	end
	return y
end

render["Erfolge"] = function()
	local total, mine = #ns.achievements, 0
	for _, a in ipairs(ns.achievements) do
		if ns.cdb.ach[a.key] then mine = mine + 1 end
	end
	local r, y = Acquire("bar", 1, BarRow, 0, 34)
	r.member = nil
	r.bg:SetShown(true)
	r.name:SetText("Dein Fortschritt")
	r.name:SetTextColor(1, 0.82, 0)
	r.bar:SetStatusBarColor(1, 0.82, 0)
	r.bar:SetValue(mine / math.max(1, total) * 100)
	r.bar.text:SetText("")
	r.value:SetText(mine .. " / " .. total)

	for i, a in ipairs(ns.achievements) do
		r, y = Acquire("ach", i, AchRow, y, 54)
		local got = ns.cdb.ach[a.key]
		r.bg:SetShown(i % 2 == 1)
		r.icon:SetTexture(a.icon)
		r.icon:SetDesaturated(not got)
		r.icon:SetAlpha(got and 1 or 0.5)
		r.name:SetText(a.name)
		if got then
			r.name:SetTextColor(1, 0.82, 0)
		else
			r.name:SetTextColor(0.55, 0.55, 0.55)
		end
		r.desc:SetText(a.desc)
		r.when:SetText(type(got) == "number" and date("%d.%m.%y", got) or "")
		local who = {}
		for name, m in pairs(ns.db.members) do
			if name ~= ns.me and m.ach and m.ach[a.key] then tinsert(who, name) end
		end
		table.sort(who)
		r.who:SetText(#who > 0 and ("Auch geschafft: " .. table.concat(who, ", ")) or "")
	end
	return y
end

render["Sounds"] = function()
	local y = Head(1, 0, "Ein Klick spielt den Sound bei allen Crittlern ab")
	local top, bw = y, (W - 16) / 3
	for i, s in ipairs(ns.sounds) do
		local col = (i - 1) % 3
		local row = floor((i - 1) / 3)
		local b = Acquire("sound", i, SoundButton, 0, 0)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", child, "TOPLEFT", col * (bw + 8), -(top + row * 42))
		b.text:SetText(s.label)
		b.key = s.key
		y = top + (row + 1) * 42
	end
	return y
end

---------------------------------------------------------------------------
-- Reiter
---------------------------------------------------------------------------
local tabButtons = {}

local function Render()
	if not ns.db then return end
	HideAll()
	contentH = math.max(render[current]() or 1, 1)
	child:SetHeight(contentH)
	UpdateScroll()

	for name, b in pairs(tabButtons) do
		if name == current then
			b.text:SetTextColor(1, 0.82, 0)
			b.line:Show()
		else
			b.text:SetTextColor(0.6, 0.6, 0.6)
			b.line:Hide()
		end
	end

	local total, online = 0, 0
	for name in pairs(ns.db.members) do
		total = total + 1
		if ns:IsOnline(name) then online = online + 1 end
	end
	summary:SetText(format("%d Crittler  |cff40e050%d online|r", total, online))
end

local tabW = (WIDTH - 2) / #TABS
for i, name in ipairs(TABS) do
	local b = CreateFrame("Button", nil, f)
	b:SetSize(tabW, TABS_H)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + (i - 1) * tabW, -HEADER_H)
	b.text = FS(b, "GameFontNormal", nil, "CENTER")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
	b.text:SetText(name)
	b.line = b:CreateTexture(nil, "ARTWORK")
	b.line:SetColorTexture(1, 0.82, 0, 1)
	b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 0)
	b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 0)
	b.line:SetHeight(2)
	b.hover = b:CreateTexture(nil, "BACKGROUND")
	b.hover:SetAllPoints()
	b.hover:SetColorTexture(1, 1, 1, 0.05)
	b.hover:Hide()
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	b:SetScript("OnClick", function()
		current = name
		scrollPos = 0
		Render()
	end)
	tabButtons[name] = b
end

---------------------------------------------------------------------------
-- Fußzeile mit Optionen
---------------------------------------------------------------------------
local footLine = f:CreateTexture(nil, "ARTWORK")
footLine:SetColorTexture(1, 1, 1, 0.08)
footLine:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, FOOTER_H)
footLine:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, FOOTER_H)
footLine:SetHeight(1)

local OPTIONS = {
	{ key = "sound", label = "Sounds" },
	{ key = "toasts", label = "Banner" },
	{ key = "pins", label = "Karten-Pins" },
	{ key = "sharePos", label = "Position teilen" },
}
local checks = {}
for i, o in ipairs(OPTIONS) do
	local c = CreateFrame("Button", nil, f)
	c:SetSize(120, 22)
	c:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + (i - 1) * 128, 8)
	c.box = CreateFrame("Frame", nil, c, "BackdropTemplate")
	c.box:SetSize(14, 14)
	c.box:SetPoint("LEFT", c, "LEFT", 0, 0)
	Skin(c.box, 0.14, 0.14, 0.18, 1)
	c.box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	c.fill = c.box:CreateTexture(nil, "ARTWORK")
	c.fill:SetColorTexture(1, 0.82, 0, 1)
	c.fill:SetPoint("TOPLEFT", c.box, "TOPLEFT", 3, -3)
	c.fill:SetPoint("BOTTOMRIGHT", c.box, "BOTTOMRIGHT", -3, 3)
	c.label = FS(c, "GameFontHighlightSmall")
	c.label:SetPoint("LEFT", c.box, "RIGHT", 6, 0)
	c.label:SetText(o.label)
	c:SetScript("OnClick", function(self)
		ns.db.settings[o.key] = not ns.db.settings[o.key]
		self.fill:SetShown(ns.db.settings[o.key])
		if ns.UpdatePins then ns.UpdatePins() end
	end)
	checks[o.key] = c
end

f:SetScript("OnShow", function()
	if not ns.db then return end
	for key, c in pairs(checks) do
		c.fill:SetShown(ns.db.settings[key])
	end
	Render()
end)

---------------------------------------------------------------------------
-- Öffentliche Funktionen
---------------------------------------------------------------------------
function ns:RefreshUI()
	if f:IsShown() then Render() end
end

function ns:ToggleUI()
	if f:IsShown() then f:Hide() else f:Show() end
end

function ns:PrintRanking()
	ns:Print("Level-Rennen:")
	for i, m in ipairs(ns:SortedMembers()) do
		print(format("  %d. %s – Level %d (%d%%), %s", i, m.name, m.level or 0, m.xp or 0, m.zone or "?"))
	end
end

function Crittler_OnAddonCompartmentClick()
	ns:ToggleUI()
end

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_CRITTLER1 = "/crit"
SLASH_CRITTLER2 = "/crittler"
SlashCmdList["CRITTLER"] = function(input)
	local cmd, arg = strsplit(" ", strtrim(input or ""), 2)
	cmd = strlower(cmd or "")
	if cmd == "" then
		ns:ToggleUI()
	elseif cmd == "test" then
		ns:Toast("Interface\\Icons\\Spell_Holy_SurgeOfLight", "Level-Up!", "Testi ist jetzt Level 42!", 888)
	elseif cmd == "play" and arg then
		ns:PlayBoard(strlower(arg))
	elseif cmd == "minimap" then
		local mm = ns.db.settings.minimap
		mm.hide = not mm.hide
		ns:UpdateMinimapButton()
		ns:Print(mm.hide and "Minimap-Button ausgeblendet." or "Minimap-Button eingeblendet.")
	elseif cmd == "reset" then
		wipe(ns.db.members)
		wipe(ns.db.deathLog)
		local me = ns:Member(ns.me)
		for key in pairs(ns.cdb.ach) do
			me.ach[key] = true
		end
		ns:SendStatus()
		if ns.SendProfessions then ns:SendProfessions(true) end
		ns:Send("HI") -- alle anderen schicken ihren Stand neu
		ns:Print("Mitgliederliste und Todesliste geleert.")
	else
		ns:Print("Befehle:")
		print("  /crit – Fenster öffnen/schließen")
		print("  /crit test – Test-Banner anzeigen")
		print("  /crit play <name> – Sound abspielen (z. B. murloc)")
		print("  /crit minimap – Minimap-Button ein-/ausblenden")
		print("  /crit reset – gespeicherte Mitglieder und Tode löschen")
	end
end

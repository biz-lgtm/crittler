-- Hauptfenster mit Reitern + Slash-Befehle
local ADDON, ns = ...

local WIDTH, HEIGHT = 640, 520
local PAD, HEADER_H, TABS_H, FOOTER_H = 14, 46, 30, 8
local W = WIDTH - PAD * 2 - 8
local VIEW_H = HEIGHT - HEADER_H - TABS_H - 10 - FOOTER_H - 6
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TABS = { "Statistiken", "Termine", "Quests", "Berufe", "Wünsche", "Tode", "Erfolge", "Sounds", "Optionen" }
local ROLE = {
	TANK = { label = "Tank", hex = "|cff5a99ff", r = 0.35, g = 0.6, b = 1 },
	HEALER = { label = "Heiler", hex = "|cff4de666", r = 0.3, g = 0.9, b = 0.4 },
	DAMAGER = { label = "DD", hex = "|cfff26659", r = 0.95, g = 0.4, b = 0.35 },
}
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local Render -- wird weiter unten definiert
local RANK = { { 1, 0.82, 0 }, { 0.8, 0.8, 0.85 }, { 0.8, 0.5, 0.25 }, [0] = { 0.5, 0.5, 0.5 } }
local current = "Statistiken"

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

local function ClassName(class)
	return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class or ""]) or ""
end

-- "Krieger · Schutz"
local function ClassLine(m)
	local class = ClassName(m.class)
	if m.spec and class ~= "" then return class .. " · " .. m.spec end
	return m.spec or class
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
f:SetBackdropBorderColor(0.34, 0.28, 0.08, 1)
f:Hide()
tinsert(UISpecialFrames, "CrittlerFrame") -- schließt mit ESC

-- Kopf mit leichtem Farbverlauf (fällt auf einfarbig zurück, falls der Client das nicht kann)
local headBg = f:CreateTexture(nil, "BORDER")
headBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
headBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
headBg:SetHeight(HEADER_H + TABS_H)
headBg:SetColorTexture(1, 1, 1, 1)
if not (CreateColor and pcall(headBg.SetGradient, headBg, "VERTICAL",
		CreateColor(0.08, 0.08, 0.1, 1), CreateColor(0.17, 0.15, 0.1, 1))) then
	headBg:SetColorTexture(0.1, 0.1, 0.13, 1)
end

local headLine = f:CreateTexture(nil, "ARTWORK")
headLine:SetColorTexture(1, 0.82, 0, 0.18)
headLine:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(HEADER_H + TABS_H))
headLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -(HEADER_H + TABS_H))
headLine:SetHeight(1)

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
title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 1)
title:SetText("Die Crittler")

local subtitle = FS(f, "GameFontDisableSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
subtitle:SetText("Statistiken, Termine, Berufe und Unfug")

local summary = FS(f, "GameFontDisableSmall", 220, "RIGHT")
summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -72, -20)

local close = FlatButton(f, 22, 22, "X")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -13)
close:SetScript("OnClick", function() f:Hide() end)

-- "?" blendet die Erklärungen oben in jedem Reiter ein und aus
local help = FlatButton(f, 22, 22, "?")
help:SetPoint("RIGHT", close, "LEFT", -6, 0)
help:SetScript("OnClick", function()
	ns.db.settings.showInfo = not ns.db.settings.showInfo
	Render()
end)
help:HookScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:AddLine("Erklärungen ein- oder ausblenden", 1, 1, 1)
	GameTooltip:Show()
end)
help:HookScript("OnLeave", function() GameTooltip:Hide() end)

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
	local classLine = ClassLine(m)
	if classLine ~= "" then GameTooltip:AddLine(classLine, 0.8, 0.8, 0.8) end
	local role = ROLE[m.role or ""]
	if role then GameTooltip:AddDoubleLine("Rolle", role.label, 0.7, 0.7, 0.7, role.r, role.g, role.b) end
	GameTooltip:AddDoubleLine("Level", format("%d (%d%%)", m.level or 0, m.xp or 0), 0.7, 0.7, 0.7, 1, 1, 1)
	if m.ilvl then GameTooltip:AddDoubleLine("Ausrüstung", "Stufe " .. m.ilvl, 0.7, 0.7, 0.7, 1, 1, 1) end
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
	local r = BaseRow(42)
	r.me = r:CreateTexture(nil, "ARTWORK")
	r.me:SetColorTexture(1, 0.82, 0, 1)
	r.me:SetSize(2, 42)
	r.me:SetPoint("LEFT", r, "LEFT", 0, 0)
	r.rank = FS(r, "GameFontNormalLarge", 24, "CENTER")
	r.rank:SetPoint("LEFT", r, "LEFT", 8, 0)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(26, 26)
	r.icon:SetPoint("LEFT", r, "LEFT", 38, 0)
	r.dot = r:CreateTexture(nil, "OVERLAY")
	r.dot:SetSize(8, 8)
	r.dot:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 3, -3)
	r.name = FS(r, "GameFontHighlight", 150)
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 74, -7)
	r.sub = FS(r, "GameFontDisableSmall", 150)
	r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.role = FS(r, "GameFontHighlightSmall", 44, "CENTER")
	r.role:SetPoint("LEFT", r, "LEFT", 226, 0)
	r.level = FS(r, "GameFontNormalLarge", 30, "RIGHT")
	r.level:SetPoint("LEFT", r, "LEFT", 272, 0)
	r.bar = Bar(r, 80, 14, 0.55, 0.3, 0.9)
	r.bar:SetPoint("LEFT", r, "LEFT", 312, 0)
	r.zone = FS(r, "GameFontHighlightSmall", W - 312 - 80 - 18, "RIGHT")
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

local function WishRow()
	local r = BaseRow(24)
	r.left = FS(r, "GameFontHighlight", W - 60)
	r.left:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.del = FlatButton(r, 18, 18, "x")
	r.del:SetPoint("RIGHT", r, "RIGHT", -6, 0)
	r.del:SetScript("OnClick", function()
		if r.index then ns:RemoveWish(r.index) end
	end)
	return r
end

-- Eingabefeld oben im Reiter (Suche, Wunschliste)
local function Input(width, hint, maxLetters)
	local e = CreateFrame("EditBox", nil, child, "BackdropTemplate")
	e:SetSize(width, 24)
	e:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
	Skin(e, 0.1, 0.1, 0.13, 1)
	e:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
	e:SetAutoFocus(false)
	e:SetFontObject("ChatFontNormal")
	e:SetTextInsets(8, 8, 0, 0)
	e:SetMaxLetters(maxLetters)
	e.hint = FS(e, "GameFontDisable")
	e.hint:SetPoint("LEFT", e, "LEFT", 8, 0)
	e.hint:SetText(hint)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:Hide()
	return e
end

local profFilter = ""
local searchBox = Input(W, "Beruf oder Name suchen …", 40)
searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)
searchBox:SetScript("OnTextChanged", function(self)
	local text = strtrim(self:GetText() or "")
	self.hint:SetShown(text == "")
	if text ~= profFilter then
		profFilter = text
		scrollPos = 0
		if Render then Render() end
	end
end)

local wishBox = Input(W - 118, "Gegenstand: Shift-Klick oder Name, dann Enter", 300)
local function SubmitWish()
	if ns:AddWish(wishBox:GetText()) then wishBox:SetText("") end
	wishBox:ClearFocus()
end
wishBox:SetScript("OnEnterPressed", SubmitWish)
wishBox:SetScript("OnTextChanged", function(self)
	self.hint:SetShown((self:GetText() or "") == "")
end)
local wishAdd = FlatButton(wishBox, 110, 24, "Hinzufügen")
wishAdd:SetPoint("LEFT", wishBox, "RIGHT", 8, 0)
wishAdd:SetScript("OnClick", SubmitWish)

-- Shift-Klick auf einen Gegenstand fügt den Link ins Wunsch-Feld ein
local lastLink, lastLinkTime = nil, 0
local function InsertLink(link)
	if type(link) ~= "string" or not wishBox:IsVisible() or not wishBox:HasFocus() then return end
	local now = GetTime()
	if link == lastLink and now - lastLinkTime < 0.2 then return end
	lastLink, lastLinkTime = link, now
	wishBox:SetText(link)
end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", InsertLink) end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", InsertLink) end

---------------------------------------------------------------------------
-- Statistiken: Umschalter Level / Ausrüstung / Woche
---------------------------------------------------------------------------
local raceSort = "level"
local sortButtons = {}
local SORTS = { { key = "level", label = "Level" }, { key = "ilvl", label = "Ausrüstung" }, { key = "week", label = "Diese Woche" } }
for i, o in ipairs(SORTS) do
	local b = FlatButton(child, 110, 22, o.label)
	b:SetPoint("TOPLEFT", child, "TOPLEFT", (i - 1) * 116, 0)
	b:SetScript("OnClick", function()
		raceSort = o.key
		scrollPos = 0
		Render()
	end)
	b:Hide()
	sortButtons[o.key] = b
end

---------------------------------------------------------------------------
-- Termine: Eingabe oben, Zeilen mit Zusage-Knöpfen
---------------------------------------------------------------------------
local evDay = 0
local evTitle = Input(W, "Was? z. B. Todesminen, Angelabend …", 60)
evTitle:SetScript("OnEnterPressed", evTitle.ClearFocus)
evTitle:SetScript("OnTextChanged", function(self)
	self.hint:SetShown((self:GetText() or "") == "")
end)

local evCall = FlatButton(child, 180, 24, "Jetzt Gruppe suchen")
evCall:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -30)
evCall:Hide()

local evCreate = FlatButton(child, 150, 24, "Termin anlegen")
evCreate:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -30)
evCreate:Hide()

local evTime = Input(70, "20:00", 5)
evTime:ClearAllPoints()
evTime:SetPoint("RIGHT", evCreate, "LEFT", -8, 0)
evTime:SetScript("OnEnterPressed", evTime.ClearFocus)
evTime:SetScript("OnTextChanged", function(self)
	self.hint:SetShown((self:GetText() or "") == "")
end)

local evDayBtn = FlatButton(child, 120, 24, "Heute")
evDayBtn:SetPoint("RIGHT", evTime, "LEFT", -8, 0)
evDayBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
evDayBtn:SetScript("OnClick", function(self, button)
	evDay = (evDay + (button == "RightButton" and -1 or 1)) % 14
	self.text:SetText(ns:DayLabel(time() + evDay * 86400))
end)
evDayBtn:Hide()

evCall:SetScript("OnClick", function()
	if ns:CreateEvent("call", evTitle:GetText()) then evTitle:SetText("") end
	evTitle:ClearFocus()
end)
evCreate:SetScript("OnClick", function()
	local text = strtrim(evTime:GetText() or "")
	if text == "" then text = "20:00" end
	local h, m = text:match("^(%d%d?)[:.](%d%d)$")
	if not h then h = text:match("^(%d%d?)$") m = "0" end
	if ns:CreateEvent("date", evTitle:GetText(), evDay, tonumber(h), tonumber(m)) then
		evTitle:SetText("")
	end
	evTitle:ClearFocus()
	evTime:ClearFocus()
end)

local function EventTip(self)
	local ev = self.id and ns.db.events[self.id]
	if not ev then return end
	local yes, no = ns:EventSummary(ev)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(ev.title, 1, 0.82, 0)
	GameTooltip:AddLine(ns:EventWhen(ev) .. ", von " .. ev.by, 0.8, 0.8, 0.8)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Dabei (" .. #yes .. ")", 0.4, 1, 0.4)
	for _, e in ipairs(yes) do
		local role = ROLE[e.role]
		GameTooltip:AddDoubleLine("  " .. e.name, role and role.label or "", 1, 1, 1,
			role and role.r or 0.6, role and role.g or 0.6, role and role.b or 0.6)
	end
	if #no > 0 then
		GameTooltip:AddLine("Abgesagt (" .. #no .. ")", 1, 0.4, 0.4)
		for _, name in ipairs(no) do
			GameTooltip:AddLine("  " .. name, 0.7, 0.7, 0.7)
		end
	end
	GameTooltip:Show()
end

local function EventRow()
	local r = BaseRow(60)
	r.title = FS(r, "GameFontNormal", W - 200)
	r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -7)
	r.when = FS(r, "GameFontHighlightSmall", 170, "RIGHT")
	r.when:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -8)
	r.who = FS(r, "GameFontHighlightSmall", W - 20)
	r.who:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
	r.roles = FS(r, "GameFontHighlightSmall", W - 200)
	r.roles:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 10, 8)
	r.del = FlatButton(r, 22, 20, "x")
	r.del:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -8, 5)
	r.no = FlatButton(r, 64, 20, "Nein")
	r.no:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
	r.yes = FlatButton(r, 64, 20, "Dabei")
	r.yes:SetPoint("RIGHT", r.no, "LEFT", -6, 0)
	r.yes:SetScript("OnClick", function() if r.id then ns:ReplyEvent(r.id, "y") end end)
	r.no:SetScript("OnClick", function() if r.id then ns:ReplyEvent(r.id, "n") end end)
	r.del:SetScript("OnClick", function() if r.id then ns:CancelEvent(r.id) end end)
	r.tip = EventTip
	return r
end

---------------------------------------------------------------------------
-- Optionen: Häkchen- und Auswahl-Zeilen
---------------------------------------------------------------------------
local function CheckRow()
	local r = BaseRow(26)
	r.box = CreateFrame("Frame", nil, r, "BackdropTemplate")
	r.box:SetSize(14, 14)
	r.box:SetPoint("LEFT", r, "LEFT", 10, 0)
	Skin(r.box, 0.14, 0.14, 0.18, 1)
	r.box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	r.fill = r.box:CreateTexture(nil, "ARTWORK")
	r.fill:SetColorTexture(1, 0.82, 0, 1)
	r.fill:SetPoint("TOPLEFT", r.box, "TOPLEFT", 3, -3)
	r.fill:SetPoint("BOTTOMRIGHT", r.box, "BOTTOMRIGHT", -3, 3)
	r.label = FS(r, "GameFontHighlight", W - 60)
	r.label:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
	r:SetScript("OnMouseUp", function(self)
		if self.onClick then self.onClick() end
	end)
	return r
end

local function ChoiceRow()
	local r = BaseRow(30)
	r.label = FS(r, "GameFontHighlight", 170)
	r.label:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.buttons = {}
	for i = 1, 4 do
		local b = FlatButton(r, 96, 22)
		b:SetPoint("LEFT", r, "LEFT", 186 + (i - 1) * 102, 0)
		b:SetScript("OnClick", function(self)
			if self.pick then self.pick() end
		end)
		r.buttons[i] = b
	end
	return r
end

-- options: { { wert, "Beschriftung" }, ... }; onPick(wert) wird beim Klick aufgerufen
local function Choice(i, y, label, options, currentValue, onPick)
	local r
	r, y = Acquire("choice", i, ChoiceRow, y, 31)
	r.bg:SetShown(i % 2 == 1)
	r.label:SetText(label)
	for bi, b in ipairs(r.buttons) do
		local o = options[bi]
		b:SetShown(o ~= nil)
		if o then
			b.text:SetText(o[2])
			if o[1] == currentValue then
				b.text:SetTextColor(1, 0.82, 0)
			else
				b.text:SetTextColor(0.75, 0.75, 0.75)
			end
			b.pick = function()
				onPick(o[1])
				Render()
			end
		end
	end
	return y
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

render["Statistiken"] = function(top)
	local list = ns:SortedMembers(raceSort)
	local byGear, bestGear = raceSort == "ilvl", 1
	for key, b in pairs(sortButtons) do
		if key == raceSort then
			b.text:SetTextColor(1, 0.82, 0)
		else
			b.text:SetTextColor(0.75, 0.75, 0.75)
		end
	end
	for _, m in ipairs(list) do
		bestGear = math.max(bestGear, m.ilvl or 0)
	end

	-- Wer ist gerade online, nach Rolle
	local count, known = { TANK = 0, HEALER = 0, DAMAGER = 0 }, false
	for _, m in ipairs(list) do
		if ROLE[m.role or ""] and ns:IsOnline(m.name) then
			count[m.role] = count[m.role] + 1
			known = true
		end
	end
	local byWeek, bestWeek = raceSort == "week", 1
	for _, m in ipairs(list) do
		bestWeek = math.max(bestWeek, ns:WeekScore(m))
	end

	local y = top + 28
	if byWeek then
		local first = list[1]
		local leader = (first and ns:WeekScore(first) > 0)
			and format("%s (%d Punkte)", first.name, ns:WeekScore(first)) or "noch offen"
		y = Head(1, top + 22, "Crittler der Woche: |cffffffff" .. leader .. "|r")
	elseif known then
		y = Head(1, top + 22, format("Online:  %s%d Tank|r   %s%d Heiler|r   %s%d DD|r",
			ROLE.TANK.hex, count.TANK, ROLE.HEALER.hex, count.HEALER, ROLE.DAMAGER.hex, count.DAMAGER))
	end

	for i, m in ipairs(list) do
		local r
		r, y = Acquire("race", i, RaceRow, y, 44)
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
		local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class or ""]
		if coords then
			r.icon:SetTexture(CLASS_ICONS)
			r.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local sub = ClassLine(m)
		r.sub:SetText(sub)
		r.name:ClearAllPoints()
		if sub ~= "" then
			r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 74, -7)
		else
			r.name:SetPoint("LEFT", r, "LEFT", 74, 0)
		end
		local role = ROLE[m.role or ""]
		r.role:SetText(role and (role.hex .. role.label .. "|r") or "")
		r.name:SetText(m.name)
		r.name:SetTextColor(ClassColor(m.class))
		if byGear then
			r.level:SetText(m.ilvl or "–")
			r.bar:SetStatusBarColor(0.9, 0.6, 0.2)
			r.bar:SetValue((m.ilvl or 0) / bestGear * 100)
			r.bar.text:SetText("Lvl " .. (m.level or 0))
		elseif byWeek then
			local score = ns:WeekScore(m)
			r.level:SetText(score)
			r.bar:SetStatusBarColor(0.25, 0.7, 0.75)
			r.bar:SetValue(math.max(0, score) / bestWeek * 100)
			r.bar.text:SetText("")
		else
			r.level:SetText(m.level or 0)
			r.bar:SetStatusBarColor(0.55, 0.3, 0.9)
			r.bar:SetValue(m.xp or 0)
			r.bar.text:SetText((m.xp or 0) .. "%")
		end
		if byWeek then
			local w = ns:WeekOf(m)
			r.zone:SetText(format("+%d Lvl  %d Quests  %d Beute  %d %s",
				w.l or 0, w.q or 0, w.o or 0, w.d or 0, (w.d or 0) == 1 and "Tod" or "Tode"))
		else
			r.zone:SetText(m.zone or "?")
		end
		if not online then r:SetAlpha(0.5) end
	end
	return y
end

render["Tode"] = function(top)
	local list = ns:SortedMembers()
	table.sort(list, function(a, b)
		if (a.deaths or 0) ~= (b.deaths or 0) then return (a.deaths or 0) > (b.deaths or 0) end
		return a.name < b.name
	end)
	local most = math.max(1, list[1] and list[1].deaths or 0)

	local y = Head(1, top, "Wall of Shame")
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

render["Quests"] = function(top)
	local y = Head(1, top, "Diese Quests habt ihr gemeinsam")
	local shared = ns:SharedQuests()
	if #shared == 0 then
		return Line(1, y, "|cff888888Gerade teilt niemand online eine Quest mit dir.|r")
	end
	for i, q in ipairs(shared) do
		y = Line(i, y, q.title, "|cff66ff66" .. table.concat(q.names, ", ") .. "|r")
	end
	return y
end

render["Berufe"] = function(top)
	local groups = ns:ProfessionGroups(profFilter)
	if #groups == 0 then
		local y = Head(1, top + 28, "Berufe der Crittler")
		return Line(1, y, profFilter ~= "" and "|cff888888Niemand gefunden.|r" or "|cff888888Noch keine Berufe bekannt.|r")
	end
	local y, n = top + 28, 0
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

render["Wünsche"] = function(top)
	local mine = ns.cdb.wishes
	local lines = 0
	local y = Head(1, top + 28, format("Deine Wunschliste (%d/%d)", #mine, ns.MAX_WISHES))
	if #mine == 0 then
		lines = lines + 1
		y = Line(lines, y, "|cff888888Noch nichts eingetragen.|r")
	end
	for i, w in ipairs(mine) do
		local r
		r, y = Acquire("wish", i, WishRow, y, 25)
		r.index = i
		r.bg:SetShown(i % 2 == 1)
		r.left:SetText("[" .. w.n .. "]")
	end

	y = Head(2, y + 8, "Das suchen die anderen")
	local others = ns:OtherWishes()
	if #others == 0 then
		lines = lines + 1
		return Line(lines, y, "|cff888888Gerade sucht niemand etwas.|r")
	end
	for _, e in ipairs(others) do
		lines = lines + 1
		local have = e.have > 0 and format("  |cffffd100hast du (%d)|r", e.have) or ""
		y = Line(lines, y, "[" .. e.n .. "]" .. have, "|cff66ff66" .. table.concat(e.names, ", ") .. "|r")
	end
	return y
end

render["Termine"] = function(top)
	local list = ns:SortedEvents()
	local y = top + 60
	if #list == 0 then
		y = Head(1, y, "Gruppensuche und Termine")
		return Line(1, y, "|cff888888Nichts geplant. Oben eintragen und loslegen.|r")
	end
	local heads, lastKind = 0, nil
	for i, ev in ipairs(list) do
		if ev.kind ~= lastKind then
			heads = heads + 1
			y = Head(heads, y + (heads > 1 and 8 or 0), ev.kind == "call" and "Jetzt gesucht" or "Termine")
			lastKind = ev.kind
		end
		local r
		r, y = Acquire("event", i, EventRow, y, 62)
		local yes, no, count = ns:EventSummary(ev)
		local mine = ev.r[ns.me]
		r.id = ev.id
		r.bg:SetShown(i % 2 == 1)
		r.title:SetText(ev.title)
		r.when:SetText(ns:EventWhen(ev))

		local names = {}
		for _, e in ipairs(yes) do
			tinsert(names, e.name)
		end
		r.who:SetText(format("|cff888888von %s|r   Dabei: |cff66ff66%s|r", ev.by, #names > 0 and table.concat(names, ", ") or "noch niemand"))

		local parts = {
			ROLE.TANK.hex .. count.TANK .. " Tank|r",
			ROLE.HEALER.hex .. count.HEALER .. " Heiler|r",
			ROLE.DAMAGER.hex .. count.DAMAGER .. " DD|r",
		}
		if count.NONE > 0 then tinsert(parts, "|cffaaaaaa" .. count.NONE .. " ohne Rolle|r") end
		if #no > 0 then tinsert(parts, "|cffff6666" .. #no .. " abgesagt|r") end
		r.roles:SetText(table.concat(parts, "   "))

		if mine == "y" then r.yes.text:SetTextColor(0.4, 1, 0.4) else r.yes.text:SetTextColor(0.8, 0.8, 0.8) end
		if mine == "n" then r.no.text:SetTextColor(1, 0.4, 0.4) else r.no.text:SetTextColor(0.8, 0.8, 0.8) end
		r.del:SetShown(ns:IsMe(ev.by))
	end
	return y
end

local CHECK_OPTIONS = {
	{ label = "Sounds abspielen", key = "sound" },
	{ label = "Banner anzeigen", key = "toasts" },
	{ label = "Freunde auf der Weltkarte anzeigen", key = "pins" },
	{ label = "Eigene Position mit der Gilde teilen", key = "sharePos" },
	{ label = "Erinnerungen an Termine", key = "reminders" },
	{ label = "Erklärungen oben in jedem Reiter anzeigen", key = "showInfo" },
}

render["Optionen"] = function(top)
	local s = ns.db.settings
	local y = Head(1, top, "Anzeige und Ton")
	local n = 0
	for _, o in ipairs(CHECK_OPTIONS) do
		n = n + 1
		local r
		r, y = Acquire("check", n, CheckRow, y, 27)
		r.bg:SetShown(n % 2 == 1)
		r.label:SetText(o.label)
		r.fill:SetShown(s[o.key] and true or false)
		r.onClick = function()
			s[o.key] = not s[o.key]
			if ns.UpdatePins then ns.UpdatePins() end
			Render()
		end
	end
	n = n + 1
	local r
	r, y = Acquire("check", n, CheckRow, y, 27)
	r.bg:SetShown(n % 2 == 1)
	r.label:SetText("Knopf an der Minimap anzeigen")
	r.fill:SetShown(not s.minimap.hide)
	r.onClick = function()
		s.minimap.hide = not s.minimap.hide
		ns:UpdateMinimapButton()
		Render()
	end

	y = Head(2, y + 8, "Auswahl")
	y = Choice(1, y, "Loot teilen ab", { { 2, "Ungewöhnlich" }, { 3, "Selten" }, { 4, "Episch" } },
		s.lootQuality, function(v) s.lootQuality = v end)
	y = Choice(2, y, "Meine Rolle", { { false, "Automatisch" }, { "TANK", "Tank" }, { "HEALER", "Heiler" }, { "DAMAGER", "DD" } },
		ns.cdb.role or false, function(v)
			ns.cdb.role = v or nil
			ns:SendStatus()
		end)
	y = Choice(3, y, "Ton-Kanal", { { "Master", "Gesamt" }, { "SFX", "Effekte" }, { "Dialog", "Dialog" } },
		s.soundChannel or "Master", function(v) s.soundChannel = v end)
	y = Choice(4, y, "Banner", { { "test", "Testen" } }, nil, function()
		ns:Toast("Interface\\Icons\\Spell_Holy_SurgeOfLight", "Level-Up!", "Testi ist jetzt Level 42!", 888)
	end)

	y = Head(3, y + 8, "Über")
	y = Line(1, y, "Die Crittler", "Version " .. ns.VERSION)
	return y
end

render["Erfolge"] = function(top)
	local total, mine = #ns.achievements, 0
	for _, a in ipairs(ns.achievements) do
		if ns.cdb.ach[a.key] then mine = mine + 1 end
	end
	local r, y = Acquire("bar", 1, BarRow, top, 34)
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

render["Sounds"] = function(top)
	local y = Head(1, top, "Soundboard")
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
-- Erklärung oben in jedem Reiter
---------------------------------------------------------------------------
local INFO = {
	["Statistiken"] = { "Wer liegt vorn?",
		"Die Rangliste aller Crittler. Mit den Knöpfen wechselst du die Ansicht: Level (Balken = Fortschritt zum nächsten Level), "
		.. "Ausrüstung (durchschnittliche Gegenstandsstufe) oder Diese Woche (Punkte seit Montag: 10 pro Level, 1 pro Quest, "
		.. "3 pro seltener Beute, minus 2 pro Tod).\n"
		.. "Grüner Punkt am Klassen-Icon heißt online, grauer offline. Der goldene Strich links markiert dich. "
		.. "Tank, Heiler oder DD kommt aus der Spezialisierung oder aus deinen Optionen. Mit der Maus über einer Zeile siehst du alle Details." },
	["Termine"] = { "Verabreden und Gruppe finden",
		"„Jetzt Gruppe suchen“ ruft sofort alle zusammen und läuft nach 45 Minuten ab. „Termin anlegen“ plant etwas für später: "
		.. "den Tag mit dem Knopf wählen (Linksklick vor, Rechtsklick zurück) und die Uhrzeit eintragen.\n"
		.. "Mit „Dabei“ oder „Nein“ sagst du zu oder ab. Die farbigen Zahlen zeigen, wie viele Tanks, Heiler und DDs zugesagt haben. "
		.. "Das „x“ sagt einen eigenen Eintrag wieder ab. An Termine wirst du 15 Minuten vorher und zum Start erinnert." },
	["Quests"] = { "Gemeinsame Quests",
		"Quests aus deinem Questlog, die gerade auch ein anderer Crittler hat. Rechts steht, wer das ist. "
		.. "Angezeigt werden nur Leute, die online sind. Beim Annehmen einer Quest bekommst du außerdem einen Hinweis im Chat." },
	["Berufe"] = { "Wer kann was?",
		"Alle Berufe der Gilde, pro Beruf sortiert nach Stufe. Die Zahl rechts bedeutet: aktuelle Stufe / höchste Stufe, "
		.. "die derzeit erreichbar ist. Im Suchfeld filterst du nach einem Beruf oder einem Namen." },
	["Wünsche"] = { "Was suchst du?",
		"Feld anklicken, dann einen Gegenstand mit Shift-Klick einfügen oder den Namen tippen und Enter drücken. "
		.. "Findet ein anderer Crittler so einen Gegenstand, bekommt ihr beide ein Banner.\n"
		.. "„hast du“ bedeutet: Der Gegenstand liegt schon in deiner Tasche. Das „x“ entfernt einen Wunsch wieder." },
	["Tode"] = { "Wall of Shame",
		"Gezählt wird jeder Tod pro Charakter. Der rote Balken vergleicht mit dem Spitzenreiter. "
		.. "Darunter stehen die letzten 50 Tode der Gilde mit Ort und Uhrzeit." },
	["Erfolge"] = { "Eigene Erfolge der Gilde",
		"Farbige Icons hast du geschafft, graue fehlen dir noch. Rechts steht das Datum, an dem du den Erfolg bekommen hast, "
		.. "darunter, welche Crittler ihn auch schon haben." },
	["Sounds"] = { "Krach für alle",
		"Ein Klick spielt den Sound bei dir und bei allen Crittlern ab, die online sind. Zwischen zwei Sounds liegen "
		.. "mindestens 5 Sekunden. Wer nichts hören will, schaltet Sounds in den Optionen ab." },
	["Optionen"] = { "Einstellungen",
		"Alles hier gilt nur für dich. Die Häkchen schalten einzelne Funktionen ein oder aus. „Loot teilen ab“ legt fest, "
		.. "ab welcher Qualität deine Beute als Banner an alle geht. „Meine Rolle“ überschreibt die automatisch erkannte Rolle." },
}

local info = CreateFrame("Frame", nil, child, "BackdropTemplate")
info:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
info:SetWidth(W)
info:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
info:SetBackdropColor(1, 0.82, 0, 0.05)
info:SetBackdropBorderColor(1, 0.82, 0, 0.2)
info.bar = info:CreateTexture(nil, "ARTWORK")
info.bar:SetColorTexture(1, 0.82, 0, 0.9)
info.bar:SetPoint("TOPLEFT", info, "TOPLEFT", 1, -1)
info.bar:SetPoint("BOTTOMLEFT", info, "BOTTOMLEFT", 1, 1)
info.bar:SetWidth(3)
info.title = FS(info, "GameFontNormal", W - 30)
info.title:SetPoint("TOPLEFT", info, "TOPLEFT", 14, -9)
info.text = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
info.text:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -5)
info.text:SetWidth(W - 30)
info.text:SetJustifyH("LEFT")
info.text:SetJustifyV("TOP")
info.text:SetWordWrap(true)
info.text:SetSpacing(3)
info.text:SetTextColor(0.85, 0.85, 0.85)
info:Hide()

-- Zeigt die Erklärung (falls eingeschaltet), rückt die Eingabefelder darunter
-- und liefert die Höhe, ab der der eigentliche Inhalt beginnt.
local function PlaceTop()
	local top = 0
	local entry = INFO[current]
	if entry and ns.db.settings.showInfo then
		info.title:SetText(entry[1])
		info.text:SetText(entry[2])
		info:SetHeight(9 + (info.title:GetStringHeight() or 12) + 5 + (info.text:GetStringHeight() or 40) + 11)
		info:Show()
		top = info:GetHeight() + 10
	else
		info:Hide()
	end
	help.text:SetTextColor(ns.db.settings.showInfo and 1 or 0.6, ns.db.settings.showInfo and 0.82 or 0.6, ns.db.settings.showInfo and 0 or 0.6)

	for _, box in ipairs({ searchBox, wishBox, evTitle }) do
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -top)
	end
	evCall:ClearAllPoints()
	evCall:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(top + 30))
	evCreate:ClearAllPoints()
	evCreate:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(top + 30))
	for i, o in ipairs(SORTS) do
		local b = sortButtons[o.key]
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", child, "TOPLEFT", (i - 1) * 116, -top)
	end
	return top
end

---------------------------------------------------------------------------
-- Reiter
---------------------------------------------------------------------------
local tabButtons = {}

Render = function()
	if not ns.db then return end
	HideAll()
	searchBox:SetShown(current == "Berufe")
	wishBox:SetShown(current == "Wünsche")
	for _, b in pairs(sortButtons) do
		b:SetShown(current == "Statistiken")
	end
	local onEvents = current == "Termine"
	evTitle:SetShown(onEvents)
	evTime:SetShown(onEvents)
	evCall:SetShown(onEvents)
	evCreate:SetShown(onEvents)
	evDayBtn:SetShown(onEvents)
	contentH = math.max(render[current](PlaceTop()) or 1, 1)
	child:SetHeight(contentH)
	UpdateScroll()

	for name, b in pairs(tabButtons) do
		if name == current then
			b.text:SetTextColor(1, 0.82, 0)
			b.line:Show()
			b.active:Show()
		else
			b.text:SetTextColor(0.6, 0.6, 0.6)
			b.line:Hide()
			b.active:Hide()
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
	b.text = FS(b, "GameFontNormalSmall", nil, "CENTER")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
	b.text:SetText(name)
	b.line = b:CreateTexture(nil, "ARTWORK")
	b.line:SetColorTexture(1, 0.82, 0, 1)
	b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 0)
	b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 0)
	b.line:SetHeight(2)
	b.active = b:CreateTexture(nil, "BACKGROUND")
	b.active:SetAllPoints()
	b.active:SetColorTexture(1, 0.82, 0, 0.08)
	b.active:Hide()
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

f:SetScript("OnShow", function()
	if ns.db then Render() end
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
	ns:Print("Rangliste:")
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
	elseif cmd == "suche" then
		ns:CreateEvent("call", arg or "")
	elseif cmd == "beruf" or cmd == "berufe" then
		ns:PrintProfessions(arg and strtrim(arg) or nil)
	elseif cmd == "wunsch" then
		if arg and strtrim(arg) ~= "" then ns:AddWish(arg) else ns:PrintWishes() end
	elseif cmd == "rolle" then
		local pick = ({ tank = "TANK", heal = "HEALER", heiler = "HEALER", dd = "DAMAGER", auto = false })[strlower(strtrim(arg or ""))]
		if pick == nil then
			ns:Print("Benutzung: /crit rolle tank | heal | dd | auto")
		else
			ns.cdb.role = pick or nil
			ns:SendStatus()
			ns:Print(pick and ("Deine Rolle: " .. ROLE[pick].label) or "Rolle wird wieder automatisch aus der Spezialisierung gelesen.")
		end
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
		if ns.SendWishes then ns:SendWishes() end
		ns:Send("HI") -- alle anderen schicken ihren Stand neu
		ns:Print("Mitgliederliste und Todesliste geleert.")
	else
		ns:Print("Befehle:")
		print("  /crit – Fenster öffnen/schließen")
		print("  /crit test – Test-Banner anzeigen")
		print("  /crit play <name> – Sound abspielen (z. B. murloc)")
		print("  /crit suche <text> – Gruppensuche starten (z. B. Todesminen)")
		print("  /crit beruf <text> – wer hat welchen Beruf (z. B. schmied)")
		print("  /crit wunsch <Gegenstand> – auf die Wunschliste setzen")
		print("  /crit rolle tank | heal | dd | auto – eigene Rolle festlegen")
		print("  /crit minimap – Minimap-Button ein-/ausblenden")
		print("  /crit reset – gespeicherte Mitglieder und Tode löschen")
	end
end

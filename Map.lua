-- Freunde auf der Weltkarte
local ADDON, ns = ...

local pins = {}
local hooked = false
local lastX, lastY, lastMap, lastSent = 0, 0, 0, 0

---------------------------------------------------------------------------
-- Eigene Position verschicken
---------------------------------------------------------------------------
local function SharePosition()
	if not ns.db or not ns.db.settings.sharePos then return end
	if IsInInstance() then return end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID or ns.IsSecret(mapID) then return end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return end
	local x, y = pos:GetXY()
	if not x or ns.IsSecret(x) or ns.IsSecret(y) then return end

	local now = GetTime()
	local moved = mapID ~= lastMap or abs(x - lastX) > 0.002 or abs(y - lastY) > 0.002
	if moved or now - lastSent >= 30 then
		lastX, lastY, lastMap, lastSent = x, y, mapID, now
		ns:Send("PO", mapID, format("%.4f", x), format("%.4f", y))
	end
end

ns:Handle("PO", function(name, isMe, mapID, x, y)
	if isMe then return end
	mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
	if not mapID or not x or not y then return end
	local l = ns.live[name]
	l.mapID, l.x, l.y, l.posTime = mapID, x, y, time()
end)

---------------------------------------------------------------------------
-- Pins anzeigen
---------------------------------------------------------------------------
local function GetPin(name, canvas)
	local pin = pins[name]
	if pin then return pin end
	pin = CreateFrame("Frame", nil, canvas)
	pin:SetSize(16, 16)
	pin.tex = pin:CreateTexture(nil, "OVERLAY")
	pin.tex:SetAllPoints()
	pin.tex:SetTexture("Interface\\COMMON\\Indicator-Yellow")
	pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pin.label:SetPoint("BOTTOM", pin, "TOP", 0, 1)
	pin.label:SetText(name)
	pin:EnableMouse(true)
	pin:SetScript("OnEnter", function(self)
		local m = ns.db.members[name]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(name, 1, 0.82, 0)
		if m then
			GameTooltip:AddLine(format("Level %d – %s", m.level or 0, m.zone or "?"), 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
	pins[name] = pin
	return pin
end

-- Rechnet eine Position auf die gerade angezeigte Karte um (z. B. Kontinentansicht)
local function Translate(mapID, x, y, viewed)
	if mapID == viewed then return x, y end
	local ok, rx, ry = pcall(function()
		local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
		if not continent or not world then return end
		local _, pos = C_Map.GetMapPosFromWorldPos(continent, world, viewed)
		if not pos then return end
		return pos:GetXY()
	end)
	if ok then return rx, ry end
end

local function UpdatePins()
	if not WorldMapFrame or not WorldMapFrame:IsShown() or not ns.db then return end
	for _, pin in pairs(pins) do
		pin:Hide()
	end
	if not ns.db.settings.pins then return end

	local viewed = WorldMapFrame:GetMapID()
	local canvas = WorldMapFrame:GetCanvas()
	if not viewed or not canvas then return end
	local w, h = canvas:GetSize()
	local scale = UIParent:GetEffectiveScale() / canvas:GetEffectiveScale()
	local now = time()

	for name, l in pairs(ns.live) do
		if name ~= ns.me and l.mapID and l.posTime and now - l.posTime < 90 then
			local x, y = Translate(l.mapID, l.x, l.y, viewed)
			if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
				local pin = GetPin(name, canvas)
				pin:SetScale(scale)
				pin:SetFrameLevel(math.min(9000, canvas:GetFrameLevel() + 3000))
				pin:ClearAllPoints()
				pin:SetPoint("CENTER", canvas, "TOPLEFT", x * w / scale, -y * h / scale)
				pin:Show()
			end
		end
	end
end
ns.UpdatePins = UpdatePins

local function Setup()
	if hooked or not WorldMapFrame then return end
	hooked = true
	WorldMapFrame:HookScript("OnShow", UpdatePins)
	if WorldMapFrame.OnMapChanged then
		hooksecurefunc(WorldMapFrame, "OnMapChanged", UpdatePins)
	end
end

ns:On("ADDON_LOADED", Setup)

ns:OnReady(function()
	Setup()
	C_Timer.NewTicker(5, SharePosition)
	C_Timer.NewTicker(2, UpdatePins)
end)

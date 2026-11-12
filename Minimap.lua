-- Knopf an der Minimap
local ADDON, ns = ...

local b = CreateFrame("Button", "CrittlerMinimapButton", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = b:CreateTexture(nil, "BACKGROUND")
bg:SetSize(20, 20)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)

local icon = b:CreateTexture(nil, "ARTWORK")
icon:SetSize(17, 17)
icon:SetTexture("Interface\\Icons\\Ability_CriticalStrike")
icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -6)

local border = b:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

local function Position()
	local a = math.rad(ns.db.settings.minimap.angle or 215)
	local r = (Minimap:GetWidth() or 140) / 2 + 5
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function Drag()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not mx or not cx or not scale then return end
	ns.db.settings.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	Position()
end

b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Drag) end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

b:SetScript("OnClick", function(_, button)
	if button == "RightButton" then
		ns:PrintRanking()
	else
		ns:ToggleUI()
	end
end)

b:SetScript("OnEnter", function(self)
	local total, online = 0, 0
	for name in pairs(ns.db.members) do
		total = total + 1
		if ns:IsOnline(name) then online = online + 1 end
	end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Die Crittler", 1, 0.82, 0)
	GameTooltip:AddLine(format("%d Crittler, %d online", total, online), 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Linksklick: Fenster öffnen", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Rechtsklick: Level-Rennen im Chat", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Ziehen: Knopf verschieben", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
b:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns:UpdateMinimapButton()
	if ns.db.settings.minimap.hide then
		b:Hide()
	else
		Position()
		b:Show()
	end
end

ns:OnReady(function() ns:UpdateMinimapButton() end)

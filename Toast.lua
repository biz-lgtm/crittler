-- Banner, die oben am Bildschirm aufpoppen
local ADDON, ns = ...

local DURATION = 4.5
local queue, elapsed = {}, 0

local toast = CreateFrame("Frame", "CrittlerToast", UIParent, "BackdropTemplate")
toast:SetSize(360, 64)
toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
toast:SetFrameStrata("HIGH")
toast:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
toast:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
toast:SetBackdropBorderColor(0, 0, 0, 1)
toast:Hide()

local accent = toast:CreateTexture(nil, "ARTWORK")
accent:SetColorTexture(1, 0.82, 0, 1)
accent:SetPoint("TOPLEFT", toast, "TOPLEFT", 1, -1)
accent:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 1, 1)
accent:SetWidth(3)

local icon = toast:CreateTexture(nil, "ARTWORK")
icon:SetSize(44, 44)
icon:SetPoint("LEFT", toast, "LEFT", 14, 0)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
title:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
text:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
text:SetJustifyH("LEFT")
text:SetWordWrap(false)

function ns:PlaySound(sound)
	if not sound or not ns.db or not ns.db.settings.sound then return end
	local channel = ns.db.settings.soundChannel or "Master"
	if type(sound) == "number" then
		pcall(PlaySound, sound, channel)
	else
		pcall(PlaySoundFile, sound, channel)
	end
end

local function ShowNext()
	local t = tremove(queue, 1)
	if not t then
		toast:Hide()
		return
	end
	icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	title:SetText(t.title or "")
	text:SetText(t.text or "")
	elapsed = 0
	toast:SetAlpha(0)
	toast:Show()
	ns:PlaySound(t.sound)
end

toast:SetScript("OnUpdate", function(self, dt)
	elapsed = elapsed + dt
	if elapsed >= DURATION then
		ShowNext()
	elseif elapsed < 0.3 then
		self:SetAlpha(elapsed / 0.3)
	elseif elapsed > DURATION - 0.6 then
		self:SetAlpha((DURATION - elapsed) / 0.6)
	else
		self:SetAlpha(1)
	end
end)

-- iconTex: Texturpfad oder FileID, sound: SoundKit-ID oder Dateipfad
function ns:Toast(iconTex, titleText, bodyText, sound)
	ns:Print(bodyText)
	if not ns.db or not ns.db.settings.toasts then
		ns:PlaySound(sound)
		return
	end
	if #queue >= 6 then return end
	tinsert(queue, { icon = iconTex, title = titleText, text = bodyText, sound = sound })
	if not toast:IsShown() then ShowNext() end
end

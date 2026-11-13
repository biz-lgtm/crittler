-- Level-Up-Feier
local ADDON, ns = ...

local ICON = "Interface\\Icons\\Spell_Holy_SurgeOfLight"

local CHEERS = {
	"%s ist jetzt Level %d!",
	"Ding! %s hat Level %d erreicht!",
	"%s wird erwachsen: Level %d!",
	"Glückwunsch, %s! Level %d. Wer hält da noch mit?",
}

ns:On("PLAYER_LEVEL_UP", function(level)
	if not ns.cdb then return end
	level = tonumber(level) or UnitLevel("player") or 0
	ns:Send("LV", level)
	if ns.WeekAdd then ns:WeekAdd("l") end
	ns.cdb.levelsNoDeath = ns.cdb.levelsNoDeath + 1
	if ns.cdb.levelsNoDeath >= 10 then ns:Award("zaeh") end
	ns:CheckLevelAchievements(level)
	C_Timer.After(1.5, function() ns:SendStatus() end)
end)

ns:Handle("LV", function(name, isMe, level)
	if isMe then return end -- das eigene Level-Up feiert das Spiel schon selbst
	level = tonumber(level)
	if not level then return end
	local m = ns:Member(name)
	m.level, m.xp = level, 0
	ns:Toast(ICON, "Level-Up!", format(CHEERS[random(#CHEERS)], name, level), 888)
	ns:RefreshUI()
end)

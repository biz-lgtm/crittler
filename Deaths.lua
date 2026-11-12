-- Todeszähler / Wall of Shame
local ADDON, ns = ...

local ICON = "Interface\\Icons\\Ability_Rogue_FeignDeath"

local LINES = {
	"%s ist in %s gestorben. Schon wieder.",
	"%s hat in %s ins Gras gebissen.",
	"%s besucht den Geistheiler in %s.",
	"%s wollte in %s nur kurz was ausprobieren.",
	"R.I.P. %s (%s). Tod Nummer %d.",
}

local function LogDeath(name, zone)
	local log = ns.db.deathLog
	tinsert(log, 1, { n = name, z = zone, t = time() })
	while #log > 50 do
		tremove(log)
	end
end

ns:On("PLAYER_DEAD", function()
	if not ns.cdb then return end
	local now = time()
	if now - ns.cdb.lastDeath < 5 then return end -- Event kann doppelt feuern
	local c = ns.cdb
	c.deaths = c.deaths + 1
	local zone = GetRealZoneText() or "?"

	ns:Send("DE", zone, c.deaths)
	LogDeath(ns.me, zone)
	ns:Member(ns.me).deaths = c.deaths
	ns:Print(format("Das war Tod Nummer %d.", c.deaths))

	ns:Award("tod1")
	if c.deaths >= 10 then ns:Award("tod10") end
	if c.deaths >= 50 then ns:Award("tod50") end
	if c.lastDeath > 0 and now - c.lastDeath <= 300 then ns:Award("doppel") end

	c.lastDeath = now
	c.levelsNoDeath = 0
	ns:RefreshUI()
end)

ns:Handle("DE", function(name, isMe, zone, count)
	if isMe then return end
	zone = zone or "?"
	count = tonumber(count) or 0
	ns:Member(name).deaths = count
	LogDeath(name, zone)
	ns:Toast(ICON, "Crittler gefallen!", format(LINES[random(#LINES)], name, zone, count), 847)
	ns:RefreshUI()
end)

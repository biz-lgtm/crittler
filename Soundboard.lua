-- Soundboard: Sounds bei allen Crittlern abspielen
local ADDON, ns = ...

local PATH = "Interface\\AddOns\\Crittler\\Sounds\\"

-- id   = Sound aus dem Spiel (SoundKit-ID)
-- file = eigene Datei im Ordner Crittler/Sounds (.ogg oder .mp3)
-- Eigene Sounds: Datei in den Ordner legen, hier eine Zeile ergänzen, Spiel neu starten.
ns.sounds = {
	{ key = "murloc", label = "Mrglglgl!", id = 416 },
	{ key = "fanfare", label = "Fanfare", id = 888 },
	{ key = "fertig", label = "Quest fertig", id = 878 },
	{ key = "fail", label = "Fail", id = 847 },
	{ key = "alarm", label = "Alarm!", id = 12889 },
	{ key = "warnung", label = "Raidwarnung", id = 8959 },
	{ key = "check", label = "Bereit?", id = 8960 },
	{ key = "horn", label = "Kriegshorn", id = 8459 },
	{ key = "sicko", label = "Sicko Mode", file = "sicko-mode.mp3" },
	-- { key = "airhorn", label = "Airhorn", file = "airhorn.ogg" },
}

local byKey = {}
for _, s in ipairs(ns.sounds) do
	byKey[s.key] = s
end

local lastOwn, lastFrom = 0, {}

local function Play(s)
	ns:PlaySound(s.id or (PATH .. s.file))
end

function ns:PlayBoard(key)
	if not ns:InGuild() then
		ns:Print(ns:LockText())
		return
	end
	local s = byKey[key]
	if not s then
		ns:Print("Unbekannter Sound: " .. tostring(key))
		return
	end
	local now = GetTime()
	if now - lastOwn < 5 then
		ns:Print("Nicht so hastig – kurz warten.")
		return
	end
	lastOwn = now
	Play(s)
	ns:Send("SB", key)
	ns.cdb.soundsPlayed = ns.cdb.soundsPlayed + 1
	if ns.cdb.soundsPlayed >= 25 then ns:Award("laerm") end
end

ns:Handle("SB", function(name, isMe, key)
	if isMe then return end
	local s = byKey[key]
	if not s then return end
	local now = GetTime()
	if lastFrom[name] and now - lastFrom[name] < 3 then return end
	lastFrom[name] = now
	Play(s)
	ns:Print(format("%s spielt: %s", name, s.label))
end)

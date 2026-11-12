# Die Crittler – Gilden-Addon für WoW Forever

## Installation
1. Den Ordner `Crittler` nach `World of Warcraft/<Forever-Ordner>/Interface/AddOns/` kopieren.
2. Spiel starten, in der Charakterauswahl unter „AddOns“ aktivieren.
3. Im Spiel `/crit` eingeben.

Jeder in der Gilde braucht das Addon. Daten werden nur zwischen Leuten ausgetauscht,
die gleichzeitig online sind.

Falls das Addon als „veraltet“ markiert ist: in `Crittler.toc` die Zahl hinter
`## Interface:` auf die aktuelle Client-Version setzen (`/dump (select(4, GetBuildInfo()))`).

## Funktionen
- **Level-Up-Feier** – Banner und Fanfare bei allen, wenn jemand aufsteigt.
- **Level-Rennen** – Rangliste mit Level, XP-Balken und Zone (Reiter „Rennen“).
- **Todeszähler** – Wall of Shame und die letzten 50 Tode (Reiter „Tode“).
- **Freunde auf der Karte** – gelbe Punkte auf der Weltkarte, auch ohne Gruppe. Nicht in Dungeons.
- **Gemeinsame Quests** – Hinweis im Chat beim Annehmen, Übersicht im Reiter „Quests“.
- **Berufe** – wer welchen Beruf auf welcher Stufe hat, nach Beruf gruppiert (Reiter „Berufe“).
- **Soundboard** – Sounds bei allen abspielen (Reiter „Sounds“).
- **Erfolge** – 19 eigene Gilden-Erfolge (Reiter „Erfolge“).
- **Loot-Angeber** – seltene und bessere Drops werden als Banner geteilt.

## Minimap-Button
Linksklick öffnet das Fenster, Rechtsklick schreibt das Level-Rennen in den Chat,
mit gedrückter Maustaste lässt er sich um die Minimap ziehen.

## Befehle
- `/crit` – Fenster öffnen/schließen
- `/crit test` – Test-Banner
- `/crit play murloc` – Sound abspielen
- `/crit minimap` – Minimap-Button ein-/ausblenden
- `/crit reset` – gespeicherte Mitglieder und Tode löschen

Unten im Fenster lassen sich Sounds, Banner, Karten-Pins und das Teilen der eigenen
Position einzeln abschalten.

## Neue Version veröffentlichen (CurseForge)
Die Versionsnummer steht nirgends im Code, sie kommt aus dem Git-Tag.

```bash
git add -A
git commit -m "Kurze Beschreibung der Änderung"
git tag 1.2.1
git push origin main --tags
```

CurseForge baut aus dem Tag automatisch das Zip. Ein Tag mit `beta` oder `alpha` im Namen
(z. B. `1.3.0-beta1`) wird als Beta bzw. Alpha markiert, alles andere als Release.
Die Commit-Nachrichten seit dem letzten Tag werden zum Changelog.

## Anpassen
- **Eigene Sounds:** `.ogg` oder `.mp3` in `Crittler/Sounds/` legen und in `Soundboard.lua`
  eine Zeile ergänzen, z. B. `{ key = "airhorn", label = "Airhorn", file = "airhorn.ogg" },`.
  Alle brauchen dieselbe Datei. Danach das Spiel neu starten.
- **Eigene Erfolge:** Liste oben in `Achievements.lua`. Vergeben wird mit `ns:Award("key")`.
- **Sprüche:** Level-Sprüche in `LevelUp.lua`, Todes-Sprüche in `Deaths.lua`.
- **Loot-Schwelle:** `/run CrittlerDB.settings.lootQuality = 4` teilt nur noch Episches (3 = selten).

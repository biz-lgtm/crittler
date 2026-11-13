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
- **Statistiken** – Rangliste mit Level, XP-Balken und Zone (Reiter „Statistiken“).
- **Todeszähler** – Wall of Shame und die letzten 50 Tode (Reiter „Tode“).
- **Freunde auf der Karte** – gelbe Punkte auf der Weltkarte, auch ohne Gruppe. Nicht in Dungeons.
- **Gemeinsame Quests** – Hinweis im Chat beim Annehmen, Übersicht im Reiter „Quests“.
- **Klasse, Spezialisierung, Rolle** – im Reiter „Statistiken“ mit Klassen-Icon und Tank/Heiler/DD,
  oben die Übersicht, welche Rollen gerade online sind.
- **Gruppensuche und Termine** – „Jetzt Gruppe suchen“ oder einen Termin mit Tag und Uhrzeit anlegen.
  Alle bekommen ein Banner, sagen per Klick zu oder ab, und man sieht, ob Tank, Heiler und DDs
  dabei sind. Termine erinnern 15 Minuten vorher und zum Start (Reiter „Termine“).
- **Ausrüstungs-Rangliste** – im Reiter „Statistiken“ zwischen Level und Ausrüstung (Gegenstandsstufe) umschalten.
- **Wochenstatistik** – im Reiter „Statistiken“ unter „Diese Woche“: Level, Quests, seltene Beute und Tode
  seit Montag, mit Punkten und dem „Crittler der Woche“.
- **Erklärungen** – oben in jedem Reiter steht, wofür er da ist. Das „?“ oben rechts blendet sie aus.
- **Berufe** – wer welchen Beruf auf welcher Stufe hat, nach Beruf gruppiert, mit Suchfeld (Reiter „Berufe“).
- **Wunschliste** – bis zu 10 Gegenstände eintragen (Shift-Klick oder Name). Findet ein anderer
  Crittler so etwas oder hat es in der Tasche, bekommen beide einen Hinweis (Reiter „Wünsche“).
- **Soundboard** – Sounds bei allen abspielen (Reiter „Sounds“).
- **Erfolge** – 19 eigene Gilden-Erfolge (Reiter „Erfolge“).
- **Loot-Angeber** – seltene und bessere Drops werden als Banner geteilt.

## Minimap-Button
Linksklick öffnet das Fenster, Rechtsklick schreibt die Rangliste in den Chat,
mit gedrückter Maustaste lässt er sich um die Minimap ziehen.

## Befehle
- `/crit` – Fenster öffnen/schließen
- `/crit test` – Test-Banner
- `/crit play murloc` – Sound abspielen
- `/crit suche Todesminen` – Gruppensuche starten
- `/crit beruf schmied` – wer hat diesen Beruf, mit Stufe
- `/crit wunsch <Gegenstand>` – auf die Wunschliste setzen (ohne Angabe: Liste anzeigen)
- `/crit rolle tank|heal|dd|auto` – eigene Rolle von Hand festlegen
- `/crit minimap` – Minimap-Button ein-/ausblenden
- `/crit reset` – gespeicherte Mitglieder und Tode löschen

Im Reiter „Optionen“ lassen sich Sounds, Banner, Karten-Pins, das Teilen der eigenen Position,
Termin-Erinnerungen und der Minimap-Knopf abschalten sowie Loot-Schwelle, eigene Rolle und
Ton-Kanal einstellen.

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
- **Loot-Schwelle:** im Reiter „Optionen“ unter „Loot teilen ab“.

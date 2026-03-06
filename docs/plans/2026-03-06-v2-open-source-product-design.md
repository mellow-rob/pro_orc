# Pro Orc v2.0 — Open Source Public Release

## Produktvision

**Tagline**: Der visuelle Einstieg in Claude Code — Projekte verwalten, Sessions starten, Tools ueberblicken.

**Vision**: Claude Code ist extrem maechtig — aber der Einstieg ist eine Huerde. Welches Projekt hat welche Skills? Wo starte ich eine Session? Was ist der aktuelle Stand? Pro Orc beantwortet diese Fragen mit einer nativen macOS App: Alle Projekte auf einen Blick, Claude Code Session per Klick starten, Tools und Fortschritt visuell erfassen. Das Terminal bleibt die Arbeitsumgebung — Pro Orc macht den Weg dorthin einfacher.

**Core Value Proposition**: Pro Orc zeigt dir auf einen Blick wo jedes Projekt steht, welche Tools verfuegbar sind, und startet Claude Code im Terminal mit einem Klick. Die Power bleibt im Terminal — Pro Orc gibt dir den Ueberblick und den schnellen Einstieg.

**Zielgruppe**: Technisch versierte Nicht-Entwickler (Gruender, Berater, Designer) die Claude Code nutzen (wollen). Leute die wissen was sie bauen wollen, aber nicht jeden CLI-Befehl auswendig kennen.

**Abgrenzung**: Pro Orc ist keine IDE und kein Terminal-Ersatz. Es ist das Dashboard das dir zeigt was du hast, und der Launcher der dich mit einem Klick in die richtige Claude Code Session bringt.

## Personas

### Lisa, die Gruenderin
Tech-affine Startup-Gruenderin, 34. Nutzt Claude Code um ihren MVP zu bauen. Kennt sich mit Produktmanagement aus, aber `cd ~/code/my-app && claude` ist schon die Grenze ihrer Terminal-Komfort-Zone. Will sehen welche Projekte sie hat, wo sie zuletzt war, und mit einem Klick weitermachen.

### Markus, der Berater
Management-Berater, 42. Hat 8 Kundenprojekte parallel, nutzt Claude Code fuer Analysen, Dokumente, Automatisierung. Braucht den Ueberblick: Welches Projekt hat welche Skills? Was war der letzte Stand? Will nicht 8 Terminal-Tabs managen sondern ein Dashboard das ihm zeigt wo er einsteigen soll.

### Tom, der Side-Project-Junkie
Produktdesigner, 28. Baut nebenbei 3 Side-Projects mit Claude Code. Vergisst staendig wo er aufgehoert hat, welche Tools er installiert hat, ob GSD noch aktuell ist. Pro Orc ist sein "Wo war ich?"-Dashboard das ihn in 2 Sekunden zurueck in den Flow bringt.

## Feature-Scope v2.0

### Vorhanden (aufpolieren)
- Projekt-Dashboard mit GSD-Status, Git-Activity, Beschreibungen
- Projekt erstellen & importieren (Folder Picker, Auto-Scaffold)
- Claude Tools Inventory (Skills, Plugins, MCP Server)
- Quick Actions (Finder, GitHub, Notion)
- Memory Indicator (rem-sleep Status)

### Neu

| Phase | Feature | Beschreibung |
|-------|---------|-------------|
| 22 | Claude-Button | Terminal-Button wird prominenter Claude-Button (Cyan, groesser). Startet `claude` im Terminal im Projektverzeichnis. |
| 23 | Settings GUI | Grafische Oberflaeche fuer `~/.claude/settings.json` — erlaubte Tools, MCP Server, Modell-Auswahl. |
| 24 | Skill/Plugin Browser Upgrade | Pro Projekt zeigen welche Skills/Plugins aktiv sind, Status, Quick Actions (Editor, Docs). |
| 25 | Onboarding & First Run | Claude Code Installation erkennen, Setup-Wizard, erster Projekt-Import guided. |
| 26 | Open Source Polish | README, Screenshots, Contributing Guide, LICENSE, GitHub Repo aufraeumen, Homebrew Cask aktualisieren. |

### Explizit nicht in v2.0
- Embedded Terminal / Chat UI
- Multi-User / Cloud Sync
- Auto-Update Mechanismus
- Skill/Plugin Installation (nur Browse)

## Architektur-Impact

Keine fundamentalen Aenderungen an der 3-Layer-Architektur noetig. Neue Features sind additive Erweiterungen:
- **Phase 22**: Aenderung an Quick Actions (osascript Command aendern)
- **Phase 23**: Neuer Service `settings_reader.dart` + neue Settings-UI-Sektion
- **Phase 24**: Erweiterung des bestehenden Claude Tools Tab
- **Phase 25**: Neues Onboarding-Widget + Claude Code Detection Service
- **Phase 26**: Keine Code-Aenderungen, nur Docs + Distribution

## Milestone-Definition

**Name**: v2.0 — Open Source Public Release
**Phasen**: 22-26
**Abhaengigkeit**: v1.5 (abgeschlossen)
**Ziel**: Pro Orc als vollwertiges Open Source Produkt veroeffentlichen mit Claude-Button, Settings GUI, erweitertem Tool-Browser, Onboarding und professioneller Dokumentation.

---
*Erstellt: 2026-03-06 | Status: Approved*

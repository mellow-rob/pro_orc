# Phase 20: Folder Import - Context

**Gathered:** 2026-03-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Existierenden Projektordner per macOS Folder Picker ins Dashboard importieren. Automatische Typ-Erkennung, optionales Scaffolding fuer fehlende Dateien, Scan-Dir Handling und sofortiges Erscheinen im richtigen Tab. Kein Drag-and-Drop, kein Batch-Import — single folder, explizite Auswahl.

</domain>

<decisions>
## Implementation Decisions

### Import-Einstieg
- Klick auf Add+ Karte zeigt Popup-Menue mit zwei Optionen: "Neues Projekt" und "Ordner importieren"
- "Neues Projekt" oeffnet bestehenden CreateProjectDialog
- "Ordner importieren" oeffnet sofort den nativen macOS Folder Picker (getDirectoryPath)
- Eigener Import-Dialog (nicht Tab im CreateProjectDialog) — saubere Trennung
- Folder Picker Cancel: stiller Abbruch, kein Feedback, zurueck zum Dashboard

### Vorschau-Dialog (Import-Dialog)
- Kompakte Vorschau: Erkannter Typ (Code/Research) mit Icon, Ordnername, Checkliste der geplanten Aktionen
- Projektname = Ordnername (kein extra Textfeld, kein Rename)
- Typ-Override per Toggle/Segmented Button: Auto-erkannter Typ vorselektiert, User kann umschalten
- Keine Post-Import Aktionen (Terminal, rem-sleep) — nur Scaffolding. Terminal/rem-sleep spaeter via Quick Actions

### Scaffold-Verhalten
- Smart Defaults: Nur fehlende Dateien als aktive Toggles. Vorhandene Dateien ausgegraut mit Haekchen "Vorhanden"
- Gleiche Scaffold-Optionen wie CreateProjectDialog: GSD Skeleton, CLAUDE.md, .gitignore (mit Template), git init
- git init Toggle: ausgegraut mit "Git vorhanden" wenn .git existiert. Sonst aktiv, fuehrt git init + initial commit aus
- Nach Scaffolding: automatischer git commit mit neuen Dateien (nur wenn git vorhanden und Dateien hinzugefuegt)

### Scan-Dir Logik
- Ordner ausserhalb Scan-Dirs: Dialog zeigt Info-Banner mit Frage "Parent als Scan-Dir hinzufuegen?" mit Checkbox zum Abwaehlen
- Scan-Dir Frage erscheint im Import-Dialog selbst, kein separater Schritt
- Ordner innerhalb bestehendem Scan-Dir: Warnung "Ordner wird bereits gescannt" als Info-Banner, Scaffold trotzdem moeglich
- Nach Scan-Dir Aenderung: `ref.invalidate(watcherProvider)` fuer sofortiges Live-Update

### Erfolgs-Feedback
- Dialog schliesst nach Import, Snackbar "Projekt importiert"
- Projekt erscheint sofort im Grid via Watcher-Invalidierung
- Konsistent mit CreateProjectDialog-Verhalten (kein Glow-Effekt)

### Claude's Discretion
- Import-Dialog Stil (GlassDialog Variante — passend zum n3urala1 Theme)
- Popup-Menue Design fuer Add+ Karte (PopupMenuButton oder Custom)
- Checklisten-Layout im Import-Dialog (CheckboxListTile oder Custom)
- Snackbar-Design und -Dauer
- Commit-Message Format fuer Scaffold-Dateien
- .gitignore Template-Auswahl UI (Dropdown wie bei Create oder anders)
- Fehlermeldungen bei Scaffold-Problemen

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `file_selector` package mit `getDirectoryPath()` — bereits in pubspec, genutzt in settings_tab und code_tab
- `CreateProjectDialog` — Vorlage fuer Dialog-Struktur, Tab-Design, Toggle-Styling
- `project_creator_service.dart` / `createProject()` — Scaffold-Logik (GSD, CLAUDE.md, .gitignore, git init) kann teilweise wiederverwendet werden
- `GlassDialog` — shared Dialog-Wrapper fuer konsistentes Glassmorphism-Design
- `_inferType()` in project_scanner.dart — content-basierte Typ-Erkennung (build files -> code, else -> research)
- `AppDatabase.getScanDirs()` / `setScanDirs()` — DB Zugriff fuer Scan-Dir Verwaltung

### Established Patterns
- `osascript` fuer Terminal.app Integration (nicht relevant hier — keine Terminal-Aktion)
- Watcher-Invalidierung nach Scan-Dir Aenderungen: `ref.invalidate(watcherProvider)` (KRITISCHER Gotcha aus MEMORY.md)
- Kebab-case Ordnernamen bei Create — Import nutzt bestehende Ordnernamen as-is
- ProjectCreationResult Pattern fuer Erfolg + Warnings

### Integration Points
- Add+ Karte in `code_tab.dart` und `research_tab.dart` — muss Popup-Menue statt direkten Dialog-Aufruf erhalten
- `watcher_provider.dart` — Invalidierung nach Scan-Dir Aenderung
- `settings_tab.dart` — `_addScanDir()` Pattern als Vorlage fuer programmatisches Scan-Dir Hinzufuegen

</code_context>

<specifics>
## Specific Ideas

- Flow: Add+ Klick -> Popup ("Neu" / "Importieren") -> Folder Picker -> Import-Dialog mit Vorschau -> Bestaetigen -> Snackbar
- Smart Defaults Visualisierung: Vorhandene Dateien als ausgegraut + Haekchen, fehlende als aktive Toggles
- Scan-Dir Banner im Dialog: Info-Ton (nicht Fehler), mit Checkbox "Parent als Scan-Dir hinzufuegen"
- `createProject()` Service kann fuer Scaffolding wiederverwendet werden, braucht aber Import-Modus (kein Directory-Create, nur Datei-Scaffolding)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 20-folder-import*
*Context gathered: 2026-03-05*

# Phase 24: Onboarding - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Erstbenutzer werden beim ersten Start durch einen 3-Schritt Setup-Wizard gefuehrt: Claude Code CLI Detection, Scan-Verzeichnisse konfigurieren, und Projekt-Vorschau. Erfahrene User mit existierenden Scan-Dirs werden nicht belaestigt. Der Wizard ist ueberspringbar und ueber Settings erneut startbar.

</domain>

<decisions>
## Implementation Decisions

### Wizard Flow & Schritte
- 3-Schritt Stepper: 1. Claude Code Check → 2. Scan-Verzeichnisse waehlen → 3. Projekt-Vorschau
- Nummerierte Schritte mit Dot-Indicator oben (aktiver Punkt in Cyan)
- Jeder Schritt hat 'Weiter' + 'Ueberspringen' Buttons
- Bestehender `_checkFirstLaunch()` Autostart-Dialog wird durch den Wizard ERSETZT (Autostart als Toggle im Wizard integrieren)
- Slide-Animation horizontal beim Schrittwechsel (PageView oder AnimatedSwitcher)

### Claude Code Detection (Schritt 1)
- Detection via `Process.run('which', ['claude'])` mit `runInShell: true`
- Wenn NICHT gefunden: Kurze Erklaerung was Claude Code ist + Link zur Installationsseite + `npm install -g @anthropic-ai/claude-code` als kopierbarer Befehl
- 'Erneut pruefen'-Button nach Installation, wiederholt den which-Check sofort
- Schritt ist ueberspringbar — App funktioniert auch ohne Claude CLI (nur Claude-Button deaktiviert)

### Claude Code Detection — Claude's Discretion
- Detailgrad wenn Claude CLI GEFUNDEN wird (gruener Check reicht, optional Version anzeigen)

### Scan-Verzeichnisse (Schritt 2)
- Nativer macOS Folder Picker via file_selector (bestehendes Package)
- Nutzt bestehende Settings-Logik fuer Scan-Dir-Verwaltung
- Wizard-Auswahl ERSETZT den Default ~/project_orchestration (kein Muell in der Liste)

### Projekt-Vorschau (Schritt 3)
- Nach Scan-Dir-Auswahl zeigt der letzte Schritt automatisch gefundene Projekte als Preview-Liste
- 'Fertig'-Button startet den normalen Scan-Zyklus
- Kein manueller Import noetig — Auto-Scan uebernimmt

### Smart Skip Logik
- Wizard wird NICHT angezeigt wenn die DB bereits konfigurierte Scan-Verzeichnisse hat
- Signal: `db.getScanDirs()` liefert nicht-leere Liste → kein Wizard
- 'Setup-Wizard erneut starten'-Button im Settings Tab zum manuellen Re-Run

### Visuelles Design
- Grosser zentrierter GlassCard im Hauptfenster (OrbBackground bleibt sichtbar dahinter)
- Dot-Indicator: 3 kleine Punkte oben, aktiver Punkt in Cyan — minimalistisch
- Lucide Icons pro Schritt (Terminal fuer Claude Check, Folder fuer Scan-Dirs, Rocket fuer Fertig)
- Konsistent mit n3urala1 Theme und bestehendem GlassCard-Pattern

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GlassDialog`: Bestehendes glassmorphism Dialog-Pattern — Wizard-GlassCard kann aehnlich strukturiert werden
- `_checkFirstLaunch()` in ShellScreen: SharedPreferences-basierter First-Run-Check — wird durch Wizard ersetzt
- `QuickActionsService.buildClaudeScript()`: Claude CLI Aufruf — gleicher Pattern fuer Detection nutzbar
- `file_selector` Package: Bereits in pubspec, fuer Folder Picker im Schritt 2
- `ImportProjectDialog`: Bestehendes Import-Pattern aus Phase 20 als Referenz
- Settings Tab: Hat bereits Scan-Dir-Verwaltung + Autostart-Toggle — Wizard nutzt gleiche DB-Methoden

### Established Patterns
- `SharedPreferences` fuer App-State Flags (launch_at_login_asked) — Wizard-Flag gleicher Mechanismus
- `db.getScanDirs()` fuer Scan-Verzeichnis-Abfrage — Smart Skip nutzt dieses
- `Process.run` mit `runInShell: true` fuer CLI-Checks — Claude Detection gleicher Pattern
- `AppColors` ThemeExtension fuer konsistente Farbgebung (cyan, fuchsia, textSec)

### Integration Points
- `ShellScreen.initState()`: Wizard-Check ersetzt `_checkFirstLaunch()`
- `AppDatabase.getScanDirs()` / `updateConfig()`: Scan-Dir Persistenz
- Settings Tab: 'Wizard erneut starten' Button einfuegen
- `WatcherService`: Nach Wizard muss ref.invalidate(watcherProvider) fuer neue Scan-Dirs

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-onboarding*
*Context gathered: 2026-03-09*

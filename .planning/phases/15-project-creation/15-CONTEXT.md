# Phase 15: Project Creation - Context

**Gathered:** 2026-02-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Filesystem-Operationen ausgeloest durch den CreateProjectDialog: Ordner anlegen, optionales git/GSD/CLAUDE.md/.gitignore Scaffolding, Terminal starten, rem-sleep ausfuehren. Dialog-UI selbst ist Phase 14 — hier geht es um die Service-Logik und die Verdrahtung mit dem Dialog.

</domain>

<decisions>
## Implementation Decisions

### Datei-Scaffolding
- CLAUDE.md Template-Inhalt: Claude's Discretion (sinnvoller Inhalt basierend auf Projekttyp)
- PROJECT.md (GSD Skeleton) Inhalt: Claude's Discretion (passende Struktur)
- .gitignore Templates: Minimal (10-20 Zeilen pro Template, nur die wichtigsten Eintraege)
- GSD Skeleton Umfang: Voller Skeleton — PROJECT.md + STATE.md + leere ROADMAP.md + REQUIREMENTS.md
- Initialer git commit: Ja — `git add` + `commit` nach Scaffolding mit allen erstellten Dateien
- Commit Message: Claude's Discretion
- REQUIREMENTS.md Struktur: Claude's Discretion
- Research-Projekte Dateien: Claude's Discretion (ob leerer Ordner oder minimale README.md)

### Ordner-Auswahl
- Zielordner bei mehreren Scan-Dirs: Dropdown im Dialog (bereits als UI-Element in Phase 14 geplant)
- Bei nur einem Scan-Directory: Dropdown verstecken, automatisch waehlen
- Projektname-Validierung: Streng kebab-case (nur Kleinbuchstaben, Zahlen, Bindestriche) — automatische Konvertierung
- Live-Vorschau unter Textfeld: "Ordnername: mein-projekt" zeigt kebab-case Konvertierung
- Vollstaendiger Pfad sichtbar: Ja — z.B. "~/code/mein-projekt" als Vorschau im Dialog
- Pfad-Vorschau: Live-Update bei jedem Tastendruck
- Scan-Dir Labels im Dropdown: Claude's Discretion
- Nicht-beschreibbare Scan-Dirs: Aus Dropdown entfernen (nicht anzeigen)

### Nach-Erstellung
- Dialog-Verhalten nach Erfolg: Kurze Erfolgsmeldung (1-2 Sekunden), dann auto-schliessen
- Spinner waehrend Erstellung: Claude's Discretion
- Terminal: Neues Terminal.app Fenster (nicht Tab)
- rem-sleep Ausfuehrung: Im selben Terminal — cd zum Projektordner, dann Claude starten, dann rem-sleep
- rem-sleep aktiviert Terminal-Toggle automatisch (kann nicht separat deaktiviert werden)
- Wenn beide aktiv (Terminal + rem-sleep): cd -> claude starten -> rem-sleep Prompt ausfuehren
- Claude Start fuer rem-sleep: Claude's Discretion (mit oder ohne Prompt-Argument)
- Nur Terminal (ohne rem-sleep): Claude's Discretion (nur cd oder cd + ls)

### Fehlerbehandlung
- Ordner existiert bereits: Live-Validierung beim Tippen (Warnung bevor Erstellen gedrueckt wird)
- git init Fehler: Ordner trotzdem erstellen, git-Fehler als Warnung anzeigen
- Erstellen-Button: Deaktiviert bis Name gueltig und Ordner nicht existiert
- Warnungs-Anzeige (git fail, Terminal fail): Claude's Discretion
- Debounce fuer Live-Validierung: Claude's Discretion
- Leerer Projektname: Nur Button deaktiviert, kein extra Hinweis

### Claude's Discretion
- CLAUDE.md Template-Inhalt
- PROJECT.md Skeleton-Struktur
- REQUIREMENTS.md Sektionen
- Commit Message fuer Initial Commit
- Research-Projekte Datei-Erstellung
- Scan-Dir Label-Format im Dropdown
- Spinner-Variante waehrend Erstellung
- Claude-Startmodus fuer rem-sleep
- Terminal-Verhalten bei nur-Terminal (ohne rem-sleep)
- Warnungs-Anzeige bei Teilfehlern
- Debounce-Strategie fuer Filesystem-Validierung

</decisions>

<specifics>
## Specific Ideas

- rem-sleep Ablauf: Terminal oeffnen -> cd zum Projekt -> Claude starten -> rem-sleep ausfuehren (genau diese Reihenfolge)
- rem-sleep Toggle erzwingt Terminal-Toggle (Abhaengigkeit)
- Pfad-Vorschau kombiniert Dropdown-Auswahl + kebab-case Name live: "~/code/mein-projekt"
- osascript fuer Terminal.app (bewaehrtes Pattern aus Memory: `osascript -e 'tell application "Terminal" to do script ...'`)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 15-project-creation*
*Context gathered: 2026-02-25*

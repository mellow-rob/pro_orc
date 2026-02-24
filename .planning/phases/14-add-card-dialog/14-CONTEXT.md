# Phase 14: Add Card + Dialog - Context

**Gathered:** 2026-02-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Add+ Karte als letzte Karte im Code- und Research-Grid, plus Erstellungs-Dialog mit Tab-Switcher (Code/Research) und allen Feldern/Toggles. Nur UI — die eigentliche Projekt-Erstellung (Filesystem-Operationen) ist Phase 15, Notion via Claude ist Phase 16.

</domain>

<decisions>
## Implementation Decisions

### Add+ Karten-Design
- Gleiche Groesse wie CodeProjectCard/ResearchProjectCard — fuegt sich nahtlos ins Grid ein
- Ghost GlassCard: wie bestehende GlassCards aber mit reduzierter Opazitaet (~30%) und zentriertem + Icon
- Text: "+ Neu" (kompakt)
- Tab-Akzentfarbe: + Icon und Text in Cyan (Code-Tab) bzw. Fuchsia (Research-Tab)
- Position: Letzte Karte im gesamten Grid (nach allen Projekt-Karten, auch nach Hidden-Section falls expanded)
- Nur im oeffentlichen Grid, nicht im Hidden/Privat-Bereich
- Hover-Animation: Opazitaet erhoeht sich auf volles GlassCard-Level + leichter Scale (~1.02)
- Hover-Glow: Subtiler Glow in Tab-Akzentfarbe (Cyan/Fuchsia)

### Dialog-Layout
- Mittelgrosser Dialog (~480px breit)
- TabBar-Style Tab-Switcher mit Underline-Indikator (animiert beim Wechsel)
- Tab-Underline-Farbe dynamisch: Cyan fuer Code, Fuchsia fuer Research
- Titel dynamisch: "Neues Code-Projekt" oder "Neues Research-Projekt" je nach aktivem Tab
- Buttons (Abbrechen/Erstellen) unten rechts, Standard Material-Position
- Erstellen-Button in Tab-Akzentfarbe (Cyan/Fuchsia je nach aktivem Tab)
- Schliessen via: Klick ausserhalb (Overlay), X-Button oben rechts, Abbrechen-Button

### Formular-Felder & Toggles
- **Code-Tab:**
  - Namensfeld (Pflicht)
  - Toggle: git init (Default: ON)
  - Toggle: GSD Skeleton (Default: ON)
  - Toggle: rem-sleep (Default: OFF — kein expliziter Default genannt, aber Post-Creation Action)
  - Dropdown: Zielordner (alle konfigurierten Code-Scan-Dirs aus DB)
- **Research-Tab:**
  - Namensfeld (Pflicht)
  - Toggle: Notion-Seite erstellen (Default: ON)
  - Toggle: rem-sleep (Default: ON)
  - Dropdown: Zielordner (alle konfigurierten Research-Scan-Dirs aus DB)
- **Namensfeld-Validierung:**
  - Echtzeit-Pruefung waehrend der Eingabe
  - Auto-Konvertierung zum Ordnernamen: Leerzeichen -> _, lowercase, Sonderzeichen entfernt
  - Abgeleiteter Ordnername als Vorschau unter dem Namensfeld angezeigt ("Ordner: my_cool_project")
  - Prueft ob Ordner bereits existiert
- Erstellen-Button disabled solange Name leer oder ungueltig

### Interaktions-Verhalten
- Autofocus auf Namensfeld bei Dialog-Oeffnung
- Enter im Namensfeld submitted NICHT den Dialog (nur Button-Klick)
- Dialog startet immer frisch mit Defaults (kein gespeicherter Zustand)
- Nach Klick auf Erstellen: Button zeigt Loading-Spinner, dann Dialog schliesst, Snackbar "Projekt erstellt"
- Bei Fehler (z.B. Ordner existiert): Dialog bleibt offen, Fehlermeldung inline
- Nach erfolgreicher Erstellung: neue Karte im Grid leuchtet kurz in Akzentfarbe auf (~1-2 Sek Glow)

### Claude's Discretion
- Dialog-Stil (Glassmorphism vs Standard Material) — passend zum n3urala1 Theme waehlen
- Tab-Wechsel-Animation (Fade/Slide) fuer Felder
- Toggle-Stil (Switch vs Checkbox)
- Snackbar-Design und -Dauer

</decisions>

<specifics>
## Specific Ideas

- Ghost GlassCard-Stil fuer Add+ Karte: reduzierte Opazitaet die bei Hover auf normal steigt — "einladend aber nicht aufdringlich"
- Ordnername-Vorschau wie ein Live-Preview: User tippt "My Cool Project", darunter erscheint "Ordner: my_cool_project"
- Tab-Switcher mit dynamischer Akzentfarbe: Cyan-Underline wechselt zu Fuchsia beim Tab-Switch — visuelles Feedback welcher Typ erstellt wird
- Kurzer Glow-Effekt auf neuer Karte nach Erstellung hilft dem User sie im Grid zu finden

</specifics>

<deferred>
## Deferred Ideas

- CLAUDE.md und .gitignore-Dropdown wurden aus den Code-Toggles entfernt (bewusste Entscheidung, nicht vergessen)
- Terminal-oeffnen Toggle war im Roadmap vorgesehen, wurde nicht als Toggle gewuenscht — rem-sleep impliziert Terminal

</deferred>

---

*Phase: 14-add-card-dialog*
*Context gathered: 2026-02-24*

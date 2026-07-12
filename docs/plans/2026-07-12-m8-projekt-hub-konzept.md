# Pro Orc M8 — Konzept „Projekt-Hub"

> Erstellt 2026-07-12. Status: **Vorschlag** (zur Abnahme durch Robert).
> Baut auf Spec `002-project-organization` (Vault, Status discovering) auf und erweitert sie
> um Roberts Input vom 2026-07-12: Aufräumen/Löschen inkl. Git-Repo, Git-Details,
> Roadmap-Visualisierung mit Gantt + Recommended Next Step.

## Ausgangslage

- **Spec 002** (2026-07-10) definiert: Grid/Listen-Toggle, benutzerdefinierte Gruppen
  (tab-übergreifend, 1:1-Mitgliedschaft, Sektionen), Drag&Drop + Kontextmenü-Zuweisung,
  Seed-Gruppen („Vodafone", „Neural AI Produkte", „Kundenprojekte" mit 16 Kundenordnern),
  a1-Badge. Noch nichts implementiert, offene `[NEEDS CLARIFICATION]`-Marker.
- **Im Code vorhanden:** Löschen → Projektordner in macOS-Papierkorb (inkl. lokalem `.git`),
  aber kein Remote-Repo-Löschen. GitHub-URL nur als Quick-Action-Button. Roadmap-Tab im
  Detail-Panel (Baum, Specs, What's-next), aber keine Zeitachse/Gantt.

## Das Konzept in einem Satz

Pro Orc bekommt **eine** Projektansicht, die nach *Kontext* gruppiert (Kunde, Produktlinie,
Arbeitgeber) statt nach *Technik* (Code vs. Research), plus einen Aufräum-Workflow bis zum
vollständigen Löschen inkl. GitHub-Repo, und ein Detail-Panel, das echtes Projekt-Insight
liefert: Git-Status, Roadmap als Gantt-Timeline und den empfohlenen nächsten Schritt.

## Baustein A — Eine Projektansicht, Gruppen als primäre Struktur

**Änderung gegenüber Spec 002:** Die Tabs „Code" und „Research" werden zu **einem Tab
„Projekte"** zusammengeführt. Begründung: Spec 002 hatte Gruppen bereits als tab-übergreifend
definiert — damit wäre dieselbe Gruppe in zwei Tabs sichtbar, jeweils nur mit einem Teil ihrer
Projekte. Das widerspricht dem Ziel „Übersicht". Der Projekt-Typ bleibt als Information
erhalten, wandert aber vom Tab in die Karte/Zeile:

- **Typ-Badge** pro Projekt (Code = Cyan, Research = Fuchsia) — Farben wie bisher.
- **Filter-Chips** im Header: „Alle · Code · Research" (ersetzt die Tab-Trennung).
- NavigationRail behält: Projekte, Claude Tools, (Agents/Skills/etc. wie gehabt), Settings.

**Unverändert aus Spec 002 übernommen:**
- Grid/Listen-Toggle, global, persistiert (FR-001/002)
- Gruppen-CRUD: anlegen („+ Gruppe" im Header), umbenennen/auflösen (Rechtsklick auf
  Sektions-Überschrift), auflösen ohne Rückfrage → Mitglieder zu „Ohne Gruppe" (FR-003–005)
- 1:1-Mitgliedschaft, Zuweisung per Drag&Drop auf Sektion + Kontextmenü-Submenü
  („Neue Gruppe…", „Aus Gruppe entfernen") (FR-006–010)
- Sektionen alphabetisch, „Ohne Gruppe" immer zuletzt; Listen-Zeile = volle Information
  (Name, Status, Fortschritt, Beschreibung) (FR-011/012)
- a1-SpecForge-Badge binär: `project.a1 != null && !project.a1!.isEmpty` (FR-013)
- Seed einmalig + idempotent: „Vodafone" (leer), „Neural AI Produkte" (leer),
  „Kundenprojekte" (16 Ordner, fehlende werden übersprungen) (FR-014–016)
- Einklappbare Sektionen, Zustand persistiert (FR-018)

**Neu: Systemgruppe „Archiv".** Nicht löschbar, rendert immer zuletzt (nach „Ohne Gruppe"),
standardmäßig eingeklappt, Projekte darin gedimmt. „Archivieren" ist die sanfte Stufe des
Aufräumens — Projekt bleibt auf der Platte, verschwindet aber aus dem Blickfeld.
(Ersetzt nicht „Privat/Verbergen" — das bleibt unabhängig davon bestehen.)

## Baustein B — Aufräum-Assistent

Robert will „viele aussortieren und rausschmeißen". Statt jedes Projekt einzeln anzufassen:

- Einstiegspunkt: Besen-Icon im Header der Projektansicht („Aufräumen").
- Zeigt **Kandidaten** nach Inaktivitäts-Heuristik: letzter Git-Commit älter als 6 Monate
  (konfigurierbar), keine aktive Claude-Session, kein a1-Fortschritt seit > 6 Monaten.
- Pro Kandidat eine Zeile mit: Name, letzter Commit (relativ), Größe auf Platte, GitHub-Repo
  vorhanden ja/nein.
- Bulk-Aktionen per Checkbox: **Archivieren** (Standard) · **Behalten** (aus Liste entfernen)
  · **Löschen…** (öffnet den Lösch-Dialog, Baustein C).

## Baustein C — Löschen bis zum Git-Repo + Git-Sektion im Detail

**Lösch-Dialog mit drei Stufen** (ersetzt den bisherigen einfachen Dialog):

| Stufe | Was passiert | Sicherung |
|---|---|---|
| 1 · Nur aus Pro Orc entfernen | Projekt wird ignoriert (bestehende Ignore-Funktion) | keine — reversibel |
| 2 · Ordner in den Papierkorb | wie heute: kompletter Ordner inkl. lokalem `.git` → macOS-Papierkorb | wiederherstellbar über Papierkorb |
| 3 · Endgültig inkl. GitHub-Repo | Stufe 2 **plus** `gh repo delete <owner>/<repo> --yes` | Repo-Name muss zur Bestätigung eingetippt werden (GitHub-Pattern) |

Stufe 3 nur wählbar, wenn ein GitHub-Remote erkannt wurde. Der Dialog zeigt explizit an,
**welches** Remote-Repo gelöscht würde (owner/name). Fehler beim Remote-Löschen (z. B. fehlende
`gh`-Berechtigung `delete_repo`) brechen den Rest nicht ab, sondern werden klar gemeldet.

**Git-Sektion im Detail-Panel** (heute nur ein GitHub-Button):
- Remote-URL (owner/repo, klickbar), aktueller Branch, letzter Commit (Message + relative Zeit)
- Commit-Aktivität als Sparkline (z. B. Commits/Woche, letzte 12 Wochen — aus `git log` Datum-Zählung)
- Dirty-Indikator (uncommitted changes ja/nein), ahead/behind gegenüber Remote falls ermittelbar

## Baustein D — Projekt-Insight: Roadmap-Tab v2 mit Gantt

Der bestehende Roadmap-Tab (Baum → Specs → Viewer) wird umgebaut zu drei Ebenen:

1. **„Nächster Schritt"-Banner** ganz oben (bestehender What's-next-Indikator, prominenter):
   empfohlene Aktion inkl. passendem a1-Skill (z. B. „M8 planen → a1-plan").
2. **Gantt-Timeline** der Milestones/Phasen:
   - Horizontale Zeitachse, ein Balken pro Milestone, „Heute"-Linie.
   - Zustände: **done** (gefüllt grün, echte Daten), **aktiv** (Cyan, laufend bis heute),
     **geplant** (Outline, geplanter Zeitraum).
   - **Datenquelle:** `.a1/roadmap.md`. Done-Daten stehen dort bereits in der Status-Spalte
     (`done (2026-07-05)`). Für geplante Zeiträume wird das Roadmap-Format um eine optionale
     Spalte erweitert: `Zeitraum: 2026-07-20 → 2026-08-03` (oder `geplant: KW30–KW31`).
     **Fallback ohne Daten:** Milestones werden in Roadmap-Reihenfolge als gleichbreite
     Segmente gerendert („Sequenz-Modus") — das Gantt degradiert nie zu einem Fehler.
   - Klick auf einen Balken springt zum Milestone im Baum darunter.
3. **Bestehender Baum + Spec-Liste + Spec-Viewer** darunter (unverändert).

## Technische Eckpunkte (Kurzfassung für die Plan-Phase)

- **Drift v4 → v5:** neue Tabelle `project_groups` (id, name), `ProjectSettingsTable` +
  nullable `groupId`, `AppConfigTable` + `viewMode`, + `orgSeedApplied`, Collapse-State als
  eigene kleine Tabelle (`group_collapse_state`) — alles in Drift, kein SharedPreferences
  (Konsistenz mit bestehendem Muster, beantwortet Spec-002-Klärungspunkt).
- **Gantt:** reine Erweiterung von `a1_reader` (Datums-Parsing) + neues Widget
  (CustomPainter oder Row-basiertes Layout); kein neues Package nötig.
- **Remote-Delete:** `deletion_service` erweitert um optionalen `gh repo delete`-Schritt
  (runInShell, Fehler tolerant, Ergebnis-Objekt statt bool).
- **Sparkline:** `git log --since=12.weeks --format=%cs` zählen, im bestehenden GitReader.

## Vorgeschlagene Feature-Aufteilung (je ein a1-new-feature-Durchlauf)

| Feature | Inhalt | Basis |
|---|---|---|
| F1 „Projekt-Hub" | Ein Projekte-Tab, Gruppen, Grid/List, Seeds, a1-Badge, Archiv | Spec 002 (Update) |
| F2 „Projekt-Insight" | Git-Sektion, Gantt-Timeline, Next-Step-Banner | neue Spec 003 |
| F3 „Aufräumen & Löschen" | Cleanup-Assistent, 3-Stufen-Lösch-Dialog inkl. Remote | neue Spec 004 |

Reihenfolge: F1 → F2 → F3 (F3 nutzt Archiv-Gruppe aus F1 und Git-Daten aus F2).

## Offene Entscheidungen für Robert

1. Code/Research-Tabs wirklich zu **einem** „Projekte"-Tab zusammenführen (Empfehlung),
   oder Tabs behalten und Gruppen in beiden Tabs anzeigen (Spec-002-Original)?
2. Inaktivitäts-Schwelle für den Aufräum-Assistenten: 6 Monate ok?
3. Gantt-Planungsdaten: reicht die optionale `Zeitraum:`-Spalte im Roadmap-Format,
   oder sollen geplante Zeiträume auch in der App editierbar sein (widerspräche read-only)?

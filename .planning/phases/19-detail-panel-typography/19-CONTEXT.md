# Phase 19: Detail-Panel Typography — Context

**Created:** 2026-03-05
**Phase goal:** Beschreibungstexte im Detail-Panel lesbar machen mit Zeilenhoehe, Selektierbarkeit, Kontrast und Expand/Collapse

## Decisions

### 1. Scope der Typografie-Verbesserungen

**Entscheidung:** Nur BESCHREIBUNG bekommt die volle Behandlung (Zeilenhoehe 1.6+, Selektierbarkeit, Expand/Collapse).

**Ausnahme:** NAECHSTER SCHRITT wird zusaetzlich selektierbar gemacht (Text -> SelectableText), bekommt aber keine weiteren Typografie-Aenderungen.

**Nicht betroffen:** Decisions-Text, Phasen-Namen, Datei-Namen, Links — alles bleibt wie bisher.

### 2. Kontrast (WCAG AA)

**Entscheidung:** `textSec` (#9399A0) beibehalten — kein Farbwechsel noetig.

**Begruendung:** textSec auf bgSurf (~#0A1017) ergibt ca. 6:1 Kontrast-Verhaeltnis, das WCAG AA (4.5:1 Minimum) deutlich besteht. Kein neuer Color-Token noetig.

### 3. Textformatierung

**Entscheidung:** Reiner Text (plain `SelectableText`), kein Markdown-Parsing.

**Begruendung:** Konsistent mit dem "Out of Scope"-Eintrag in REQUIREMENTS.md ("Full Markdown Renderer fuer kurze Beschreibungen — Overkill"). Keine neue Abhaengigkeit noetig.

### 4. Expand/Collapse — Abschneiden

**Entscheidung:** Harter Schnitt mit `maxLines: 5` + `TextOverflow.ellipsis`, darunter "Mehr anzeigen" Button.

**Kein Fade-out Gradient** — sauberer Schnitt, einfacher zu implementieren.

### 5. Expand/Collapse — Animation

**Entscheidung:** Sofort umschalten (kein AnimatedContainer/CrossFade).

**Begruendung:** Konsistent mit dem bestehenden `_DecisionsSection`-Muster (bool-Toggle). Weniger Code, kein visueller Overhead.

### 6. Expand/Collapse — Selektierbarkeit

**Entscheidung:** Eingeklappter Zustand nutzt `Text` (nicht selektierbar wegen maxLines), ausgeklappter nutzt `SelectableText`.

- Kurze Beschreibungen (<= 5 Zeilen): Immer `SelectableText`
- Lange Beschreibungen (> 5 Zeilen): Eingeklappt nicht selektierbar, ausgeklappt selektierbar

**Akzeptiert:** Pragmatischer Ansatz — eingeklappter Text ist Vorschau, aufgeklappter ist interaktiv.

### 7. Expand/Collapse — Laengen-Messung

**Entscheidung:** `maxLines: 5` mit Overflow-Detection (maxLines + didExceedMaxLines Ansatz).

Kein LayoutBuilder oder Newline-Zaehlung. Flutter-nativer Ansatz.

### 8. Button-Styling — Design

**Entscheidung:** Textlink mit Chevron-Icon, linksbuendig unter dem Text.

- Eingeklappt: `chevronRight` + "Mehr anzeigen"
- Ausgeklappt: `chevronDown` + "Weniger anzeigen"
- Farbe: `textDim`, Hover: Akzentfarbe (cyan/fuchsia je nach Projekttyp)
- Font: 12px, w400

### 9. Button-Platzierung

**Entscheidung:** Links unter dem Text, sowohl eingeklappt als auch ausgeklappt.

Im ausgeklappten Zustand steht "Weniger anzeigen" unter der letzten Zeile des vollen Textes (wandert mit).

### 10. Default-Zustand

**Entscheidung:** Lange Beschreibungen sind beim Oeffnen des Detail-Panels eingeklappt.

User muss aktiv aufklappen. Haelt das Panel kompakt.

## Code Context

### Betroffene Datei
`pro_orc/lib/features/shared/project_detail_panel.dart`

### Relevante Stellen
- **BESCHREIBUNG Sektion:** Zeile 226-236 — `Text` -> `SelectableText` mit height: 1.6, Expand/Collapse Wrapper
- **NAECHSTER SCHRITT Sektion:** Zeile 206-224 — `Text` -> `SelectableText` (nur Selektierbarkeit)
- **_DecisionsSection:** Zeile 632-741 — Bestehendes Expand/Collapse Pattern als Vorlage
- **_SectionCard:** Zeile 582-629 — Wrapper-Widget bleibt unveraendert

### Wiederverwendbare Muster
- `_DecisionsSection` hat bereits bool-Toggle Expand/Collapse mit `setState` — gleiches Muster fuer BESCHREIBUNG nutzen
- Die BESCHREIBUNG-Sektion muss von `StatelessWidget`-Kontext (ist inline in `_buildBody`) zu einem eigenen `StatefulWidget` extrahiert werden (fuer den `_expanded` State)

### Farbwerte (verifiziert)
- `textSec` (#9399A0) auf `bgSurf` (~#0A1017): ~6:1 Kontrast — WCAG AA bestanden
- `textDim` (#5F6469) fuer Button-Text im Normalzustand
- Akzentfarbe (cyan/fuchsia) fuer Button-Hover

## Deferred Ideas

Keine — alle Anforderungen (DPL-01 bis DPL-04) werden in Phase 19 adressiert.

---
*Context created: 2026-03-05*

# Bearbeitbarer Projekt-Titel

**Datum:** 2026-04-27
**Status:** Approved, ready for implementation
**Scope:** Pro Orc Flutter macOS App (`pro_orc/`)

## Ziel

Der angezeigte Projekt-Titel auf den Karten soll im Dashboard frei umbenennbar sein, ohne dass der Ordner auf der Festplatte oder die `PROJECT.md` geändert wird. Die Umbenennung wird in der lokalen Drift-Datenbank persistiert und überlebt App-Neustarts.

## Datenmodell

Die Spalte `displayName` existiert bereits in `ProjectSettingsTable` (`lib/data/db/tables/project_settings_table.dart`) — ist aber bisher tot. Sie wird jetzt aktiviert.

Neue DB-Methode:

```dart
Future<void> setProjectDisplayName(String folderId, String? name);
```

- `name == null` oder leerer/getrimmter String → Override löschen (Fallback greift wieder)
- Sonst: Wert speichern (upsert auf `folderId`)

## Auflösungs-Reihenfolge im Scanner

`project_scanner.dart` Zeile 189 wird erweitert:

1. **DB-Override** (`settings?.displayName`) — neu, höchste Priorität
2. **PROJECT.md H1** (`gsdResult.displayName`)
3. **Ordnername** (`folderId`) — Fallback

```dart
displayName: settings?.displayName?.trim().isNotEmpty == true
    ? settings!.displayName!
    : (gsdResult.displayName ?? folderId),
```

## UI

### Pfad A — Kontextmenü (Rechtsklick auf Karte)

In `project_context_menu.dart` neuer Eintrag **"Umbenennen…"** zwischen "Verschieben nach" und "Privat machen". Öffnet `RenameProjectDialog`.

### Pfad C — Detail-Panel

In `project_detail_panel.dart` ein kleines Edit-Icon (`Icons.edit_outlined`, 16px) rechts neben dem Titel. Erscheint beim Hover über die Title-Zeile (MouseRegion). Klick öffnet `RenameProjectDialog`.

### Dialog (`RenameProjectDialog`)

Neuer Shared Widget unter `lib/features/shared/rename_project_dialog.dart`:

- GlassDialog-Style (konsistent mit Create/Delete/Import)
- TextField vorbefüllt mit aktuellem `project.displayName`
- Hinweistext: *„Nur die Anzeige im Dashboard ändert sich — der Ordner bleibt `<folderId>`."*
- Buttons:
  - **Speichern** — schreibt Override (oder löscht bei leerem Input)
  - **Auf Standard zurücksetzen** — explizit löscht Override (nur sichtbar wenn aktuell ein Override existiert)
  - **Abbrechen**
- Nach Save: `ref.invalidate(projectsProvider)` triggert Re-Scan

## Verhalten

- **Sortierung:** Karten sind nach `displayName` sortiert (`project_scanner.dart:204`). Nach Umbenennen verschiebt sich die Karte automatisch — gewünschtes Verhalten.
- **Persistenz:** Override überlebt App-Neustart (Drift SQLite).
- **Ordner-Rename:** Wird der Ordner auf der Festplatte umbenannt, ändert sich `folderId` (= Primary Key). Der Override geht dann verloren — akzeptabel, da Edge Case.
- **Validierung:** Trim, kein Längenlimit. Leer = Reset.
- **Eindeutigkeit:** Keine Duplikat-Prüfung — `folderId` bleibt eindeutig, `displayName` ist rein kosmetisch. Zwei Projekte dürfen denselben Anzeigenamen haben.

## Tests

1. **DB-Test** (`test/data/db/app_database_test.dart`):
   - `setProjectDisplayName("foo", "Custom Name")` schreibt korrekt
   - `setProjectDisplayName("foo", null)` löscht Override
   - `setProjectDisplayName("foo", "  ")` löscht Override (whitespace)

2. **Scanner-Test** (`test/data/services/project_scanner_test.dart`):
   - Override aus DB überschreibt PROJECT.md H1
   - Ohne Override → PROJECT.md H1
   - Ohne PROJECT.md → folderId

3. **Widget-Test** (`test/features/shared/rename_project_dialog_test.dart`):
   - Dialog öffnet mit vorbefülltem Wert
   - Save mit neuem Wert ruft Callback mit Wert
   - Save mit leerem Feld ruft Callback mit `null`
   - Reset-Button ist sichtbar wenn Override existiert, sonst versteckt

## Geänderte / neue Dateien

| Datei | Art |
|-------|-----|
| `lib/data/db/app_database.dart` | + `setProjectDisplayName` Methode |
| `lib/data/services/project_scanner.dart` | 1 Zeile: Priority chain für `displayName` |
| `lib/features/shared/rename_project_dialog.dart` | **Neu** (~80 Zeilen) |
| `lib/features/shared/project_context_menu.dart` | + „Umbenennen…" Eintrag |
| `lib/features/shared/project_detail_panel.dart` | + Edit-Icon mit Hover |
| `test/data/db/app_database_test.dart` | + 3 Tests |
| `test/data/services/project_scanner_test.dart` | + 3 Tests |
| `test/features/shared/rename_project_dialog_test.dart` | **Neu** + 4 Tests |

## Out of Scope

- Bulk-Rename mehrerer Projekte
- Edit-History / Undo
- Cloud-Sync der Overrides
- Edit der `PROJECT.md` selbst (nur Override)
- Edit von Phase-Titeln oder anderen GSD-Inhalten

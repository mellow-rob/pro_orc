import 'package:drift/drift.dart';

/// System sentinel id for the non-deletable, non-renameable "Archiv" group.
/// Must be referenced via this constant everywhere (never a string literal)
/// so the id can never be typo'd into an invisible duplicate — see
/// records/2026-07-12-archiv-modeling-adr.md.
const String kArchiveGroupId = '__archiv__';

class ProjectGroupsTable extends Table {
  // Generated id (not derived from name), except for the reserved
  // [kArchiveGroupId] system sentinel — see ADR "Geprüfte Einwände" §1.
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

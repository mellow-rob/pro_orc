import 'package:drift/drift.dart';

class ProjectSettingsTable extends Table {
  TextColumn get folderId => text()(); // folder name = canonical ID
  TextColumn get projectType =>
      text().nullable()(); // 'code'|'research'|custom|null
  TextColumn get displayName => text().nullable()(); // override for PROJECT.md name
  DateTimeColumn get typeSetAt =>
      dateTime().nullable()(); // for conflict resolution
  BoolColumn get isHidden =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {folderId};
}

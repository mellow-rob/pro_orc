import 'package:drift/drift.dart';

class GroupCollapseStateTable extends Table {
  TextColumn get groupId => text()();
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {groupId};
}

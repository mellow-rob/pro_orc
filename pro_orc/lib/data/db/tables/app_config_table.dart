import 'package:drift/drift.dart';

class AppConfigTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scanDir => text().withDefault(const Constant(''))();
  TextColumn get ignoreListJson => text().withDefault(
        const Constant('[".*","node_modules","build",".dart_tool"]'),
      )();
  TextColumn get gitBinaryPath => text().withDefault(const Constant('git'))();

  /// One of 'light', 'dark', 'system'. Default 'dark' preserves the existing
  /// look for current users (v2.2 Design-Refresh).
  TextColumn get themeMode => text().withDefault(const Constant('dark'))();

  /// Absolute path to the Obsidian vault root used for the a1 learning-loop
  /// view (M6). Empty string means "use the default" (`$HOME/N3URAL-Vault`),
  /// resolved by the reader — kept empty by default so per-machine HOME is not
  /// baked into the DB.
  TextColumn get vaultDir => text().withDefault(const Constant(''))();
}

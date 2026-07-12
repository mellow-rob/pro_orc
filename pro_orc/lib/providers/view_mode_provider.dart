import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/providers/database_provider.dart';

/// Global grid/list layout preference for the merged Projekte tab (FR-001).
/// A single, app-wide setting — not tracked per former tab.
enum ViewMode {
  grid,
  list;

  /// Parses the persisted DB string ('grid'/'list'). Unknown values fall
  /// back to [ViewMode.grid] (the column default, preserving the existing
  /// look for current users).
  static ViewMode fromString(String value) {
    return switch (value) {
      'list' => ViewMode.list,
      _ => ViewMode.grid,
    };
  }

  String toDbString() {
    return switch (this) {
      ViewMode.grid => 'grid',
      ViewMode.list => 'list',
    };
  }
}

/// Persisted global view-mode preference (FR-001/FR-002).
///
/// Loads from the DB on first read and persists changes back via [set]/
/// [toggle].
class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() {
    _loadFromDb();
    return ViewMode.grid;
  }

  Future<void> _loadFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final raw = await db.getViewMode();
    state = ViewMode.fromString(raw);
  }

  Future<void> set(ViewMode mode) async {
    state = mode;
    final db = ref.read(appDatabaseProvider);
    await db.setViewMode(mode.toDbString());
  }

  Future<void> toggle() async {
    final next = state == ViewMode.grid ? ViewMode.list : ViewMode.grid;
    await set(next);
  }
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);

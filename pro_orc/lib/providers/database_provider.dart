import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/services/project_scanner.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';

/// Singleton AppDatabase instance. keepAlive — lives for entire app lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  ref.keepAlive();
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// ProjectScanner using the singleton database.
final projectScannerProvider = Provider<ProjectScanner>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProjectScanner(db);
});

/// Singleton QuickActionsService for opening Terminal, Finder, and URLs.
final quickActionsProvider = Provider<QuickActionsService>((ref) {
  return QuickActionsService();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/services/project_scanner.dart';

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

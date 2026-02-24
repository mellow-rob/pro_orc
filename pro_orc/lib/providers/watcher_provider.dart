import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../data/services/watcher_service.dart';
import 'database_provider.dart';

/// File watcher stream — emits debounced WatchEvents for all scan directories
/// plus the Claude projects directory (for memory status changes).
/// keepAlive: never disposed (locked decision from CONTEXT.md).
final watcherProvider = StreamProvider<WatchEvent>((ref) async* {
  ref.keepAlive();

  // Read scan dirs from DB config
  final db = ref.read(appDatabaseProvider);
  final scanDirs = await db.getScanDirs();

  // Also watch Claude projects dir for memory changes (rem-sleep updates)
  final claudeProjectsDir =
      p.join(Platform.environment['HOME']!, '.claude', 'projects');
  final allDirs = [...scanDirs, claudeProjectsDir];

  final service = WatcherService.multi(allDirs);
  ref.onDispose(service.dispose);

  // Forward all events from the service's debounced stream
  yield* service.events;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watcher/watcher.dart';

import '../data/services/watcher_service.dart';
import 'database_provider.dart';

/// File watcher stream — emits debounced WatchEvents for all scan directories.
/// keepAlive: never disposed (locked decision from CONTEXT.md).
final watcherProvider = StreamProvider<WatchEvent>((ref) async* {
  ref.keepAlive();

  // Read scan dirs from DB config
  final db = ref.read(appDatabaseProvider);
  final scanDirs = await db.getScanDirs();

  final service = WatcherService.multi(scanDirs);
  ref.onDispose(service.dispose);

  // Forward all events from the service's debounced stream
  yield* service.events;
});

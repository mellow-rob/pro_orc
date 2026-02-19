import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watcher/watcher.dart';

import '../data/services/watcher_service.dart';
import 'database_provider.dart';

/// File watcher stream — emits debounced WatchEvents for the scan directory.
/// keepAlive: never disposed (locked decision from CONTEXT.md).
final watcherProvider = StreamProvider<WatchEvent>((ref) async* {
  ref.keepAlive();

  // Read scan dir from DB config
  final db = ref.read(appDatabaseProvider);
  final config = await db.getConfig();
  final scanDir = config.scanDir;

  final service = WatcherService(scanDir);
  ref.onDispose(service.dispose);

  // Forward all events from the service's debounced stream
  yield* service.events;
});

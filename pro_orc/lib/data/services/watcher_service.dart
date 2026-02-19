import 'dart:async';

import 'package:stream_transform/stream_transform.dart';
import 'package:watcher/watcher.dart';

// ---------------------------------------------------------------------------
// WatcherService
// ---------------------------------------------------------------------------

/// A plain Dart service class that wraps [DirectoryWatcher] with a 350ms
/// trailing-edge debounce and defensive error handling.
///
/// Purpose: Isolate file-watching logic from Riverpod so it is independently
/// testable. This is the bottom layer of the watcher-to-provider-to-UI chain.
///
/// Design decisions:
/// - Watch-scope: Watches the root scan directory (covers all LIVE-01/02/03).
/// - Debounce: 350ms fixed, trailing-edge, global (one timer for all events).
/// - Start-timing: Watcher created lazily on first [events] access.
/// - Error handling: Defensive [handleError] around event stream per locked
///   decision — guards against watcher#79 and similar macOS edge cases even
///   though the assert was removed in watcher 1.2.1.
class WatcherService {
  final String _rootDir;
  DirectoryWatcher? _watcher;

  WatcherService(this._rootDir);

  /// Returns a debounced, error-guarded stream of [WatchEvent]s emitted from
  /// the watched directory.
  ///
  /// The [DirectoryWatcher] is created lazily on first access. Events are
  /// debounced with a 350ms trailing-edge window so that rapid bursts of
  /// filesystem activity (e.g. editor auto-save) collapse into a single
  /// downstream event.
  Stream<WatchEvent> get events {
    _watcher ??= DirectoryWatcher(_rootDir);
    return _watcher!.events
        .handleError((Object error, StackTrace stackTrace) {
          // Log but do not rethrow — defensive against watcher#79 and similar
          // macOS FSEvents edge cases. Prevents assertion crashes from
          // propagating through the provider chain in debug mode.
          // ignore: avoid_print
          print('[WatcherService] Suppressed watcher error: $error');
        })
        .debounce(const Duration(milliseconds: 350));
  }

  /// Returns true once the underlying [DirectoryWatcher] is ready to emit
  /// events (i.e., the initial directory scan is complete).
  ///
  /// Returns false if the watcher has not been created yet (events not yet
  /// accessed).
  bool get isReady => _watcher?.isReady ?? false;

  /// Returns a [Future] that completes when the watcher is ready.
  ///
  /// Useful in tests to await the initial scan before writing files.
  /// Creates the watcher if not already created.
  Future<void> get ready async {
    _watcher ??= DirectoryWatcher(_rootDir);
    await _watcher!.ready;
  }

  /// Disposes the watcher service.
  ///
  /// [DirectoryWatcher] does not expose an explicit dispose method; callers
  /// should cancel any [StreamSubscription]s they hold on [events]. This
  /// method exists to satisfy a common service lifecycle contract and allows
  /// future cleanup if the underlying watcher API gains a dispose.
  Future<void> dispose() async {
    // DirectoryWatcher does not have an explicit close/cancel API.
    // Subscriptions created by listeners are the callers' responsibility.
    // Nullify the watcher reference to allow GC and signal end-of-life.
    _watcher = null;
  }
}

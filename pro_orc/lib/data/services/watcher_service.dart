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
/// - Start-timing: Watcher and internal subscription started eagerly on
///   construction — the DirectoryWatcher requires an active listener to drive
///   its internal event loop and for [ready] to complete.
/// - Error handling: Defensive [handleError] around event stream per locked
///   decision — guards against watcher#79 and similar macOS edge cases even
///   though the assert was removed in watcher 1.2.1.
///
/// **Internal architecture:**
/// A [StreamController.broadcast] re-broadcasts [DirectoryWatcher.events]
/// through a permanent internal subscription. This keeps the watcher's event
/// loop running regardless of how many external listeners [events] has.
/// The debounced [events] getter returns a new single-subscription stream
/// tapping into this broadcast controller on each call.
class WatcherService {
  final String _rootDir;
  late final DirectoryWatcher _watcher;
  late final StreamController<WatchEvent> _controller;
  late final StreamSubscription<WatchEvent> _internalSub;

  WatcherService(this._rootDir) {
    _watcher = DirectoryWatcher(_rootDir);
    _controller = StreamController<WatchEvent>.broadcast();

    // Keep a permanent internal subscription so the watcher's event loop
    // runs and watcher.ready eventually completes.
    _internalSub = _watcher.events.listen(
      (event) {
        if (!_controller.isClosed) {
          _controller.add(event);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Log but do not rethrow — defensive against watcher#79 and similar
        // macOS FSEvents edge cases. Prevents assertion crashes from
        // propagating through the provider chain in debug mode.
        // ignore: avoid_print
        print('[WatcherService] Suppressed watcher error: $error');
      },
      onDone: () {
        if (!_controller.isClosed) {
          _controller.close();
        }
      },
      cancelOnError: false,
    );
  }

  /// Returns a debounced stream of [WatchEvent]s emitted from the watched
  /// directory.
  ///
  /// Events are debounced with a 350ms trailing-edge window so that rapid
  /// bursts of filesystem activity (e.g. editor auto-save) collapse into a
  /// single downstream event. Multiple calls return independent debounced
  /// streams sharing the same underlying broadcast source.
  Stream<WatchEvent> get events {
    return _controller.stream.debounce(const Duration(milliseconds: 350));
  }

  /// Returns true once the underlying [DirectoryWatcher] is ready to emit
  /// events (i.e., the initial directory scan is complete).
  bool get isReady => _watcher.isReady;

  /// Returns a [Future] that completes when the watcher is ready.
  ///
  /// Useful in tests to await the initial scan before writing files.
  Future<void> get ready => _watcher.ready;

  /// Disposes the watcher service, cancelling the internal subscription and
  /// closing the broadcast controller.
  Future<void> dispose() async {
    await _internalSub.cancel();
    await _controller.close();
  }
}

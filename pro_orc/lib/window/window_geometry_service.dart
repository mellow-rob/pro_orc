import 'dart:developer' as developer;
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class WindowGeometryService {
  static const String _keyX = 'window_x';
  static const String _keyY = 'window_y';
  static const String _keyW = 'window_w';
  static const String _keyH = 'window_h';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await prefs.setDouble(_keyX, position.dx);
    await prefs.setDouble(_keyY, position.dy);
    await prefs.setDouble(_keyW, size.width);
    await prefs.setDouble(_keyH, size.height);
  }

  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    final w = prefs.getDouble(_keyW);
    final h = prefs.getDouble(_keyH);

    if (x == null || y == null || w == null || h == null) {
      return false;
    }

    await windowManager.setSize(Size(w, h));

    // Off-screen guard: clamp against the real bounds of currently connected
    // displays instead of a fixed magic threshold, so geometry saved while a
    // second monitor was attached doesn't strand the window off-screen once
    // that monitor is disconnected.
    if (await _isOnAnyDisplay(x, y, w, h)) {
      await windowManager.setPosition(Offset(x, y));
    } else {
      await windowManager.center();
    }

    return true;
  }

  /// Returns true if the saved window rect overlaps at least one currently
  /// connected display. Falls back to true (trust the saved position) if the
  /// display list cannot be retrieved, to avoid unnecessarily re-centering.
  Future<bool> _isOnAnyDisplay(double x, double y, double w, double h) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      for (final display in displays) {
        final bounds = Rect.fromLTWH(
          display.visiblePosition?.dx ?? 0,
          display.visiblePosition?.dy ?? 0,
          display.size.width,
          display.size.height,
        );
        final windowRect = Rect.fromLTWH(x, y, w, h);
        if (bounds.overlaps(windowRect)) return true;
      }
      return false;
    } catch (e) {
      developer.log(
        'Failed to query displays for off-screen guard: $e',
        name: 'window_geometry_service',
      );
      return true;
    }
  }
}

import 'dart:ui';

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

    // Off-screen guard for disconnected monitors
    if (x < -100 || y < -100) {
      await windowManager.center();
    } else {
      await windowManager.setPosition(Offset(x, y));
    }

    return true;
  }
}

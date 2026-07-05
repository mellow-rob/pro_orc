import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/providers/database_provider.dart';

/// Converts the persisted DB string ('light'/'dark'/'system') to a
/// [ThemeMode]. Unknown values fall back to [ThemeMode.dark] (the app's
/// default, preserving the existing look for current users).
ThemeMode themeModeFromString(String value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

/// Converts a [ThemeMode] to the DB string representation.
String themeModeToString(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    ThemeMode.dark => 'dark',
  };
}

/// Persisted app-wide theme mode preference (Hell/Dunkel/System).
///
/// Loads from the DB on first read and persists changes back via [setMode].
/// Default is [ThemeMode.dark] — existing users keep their current look
/// until they explicitly opt into Light or System.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadFromDb();
    return ThemeMode.dark;
  }

  Future<void> _loadFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final raw = await db.getThemeMode();
    state = themeModeFromString(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final db = ref.read(appDatabaseProvider);
    await db.setThemeMode(themeModeToString(mode));
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

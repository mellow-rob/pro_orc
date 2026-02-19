import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/projects_provider.dart';
import '../../tray/tray_service.dart';
import '../../window/window_geometry_service.dart';
import 'glow_border_shell.dart';
import 'launch_dialog.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WindowListener, TrayListener {
  late final TrayService _trayService;
  final WindowGeometryService _geometryService = WindowGeometryService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _trayService = TrayService();
    _trayService.init();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('launch_at_login_asked') ?? false;
    if (!asked && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final enable = await showLaunchAtLoginDialog(context);
      if (enable) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      await prefs.setBool('launch_at_login_asked', true);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _trayService.dispose();
    super.dispose();
  }

  // WindowListener overrides

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onWindowMove() {
    _geometryService.save();
  }

  @override
  void onWindowResize() {
    _geometryService.save();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);

    return GlowBorderShell(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pro Orc',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Project Orchestration Dashboard',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Show live project count from provider
                switch (projectsAsync) {
                  AsyncData(:final value) => Text(
                      '${value.length} projects discovered',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  AsyncError(:final error) => Text(
                      'Error: $error',
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontSize: 12,
                      ),
                    ),
                  _ => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../providers/projects_provider.dart';
import '../../theme/n3_colors.dart';
import '../../tray/tray_service.dart';
import '../../window/window_geometry_service.dart';
import '../claude_tools/claude_tools_tab.dart';
import '../code/code_tab.dart';
import '../research/research_tab.dart';
import 'glow_border_shell.dart';
import 'launch_dialog.dart';
import 'orb_background.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WindowListener, TrayListener {
  late final TrayService _trayService;
  final WindowGeometryService _geometryService = WindowGeometryService();
  int _selectedIndex = 0;

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
    // Keep projectsProvider alive for the reactive watcher chain.
    // Unused local variable intentional — provider must be watched.
    ref.watch(projectsProvider);

    final colors = Theme.of(context).extension<AppColors>()!;

    return GlowBorderShell(
      child: Stack(
        children: [
          const Positioned.fill(child: OrbBackground()),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Row(
                children: [
                  NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _selectedIndex = i),
                    labelType: NavigationRailLabelType.selected,
                    minWidth: 80,
                    selectedIconTheme: IconThemeData(color: colors.cyan),
                    selectedLabelTextStyle: TextStyle(color: colors.cyan),
                    unselectedIconTheme: IconThemeData(color: colors.textDim),
                    unselectedLabelTextStyle:
                        TextStyle(color: colors.textDim),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.code_outlined),
                        selectedIcon: Icon(Icons.code),
                        label: Text('Code'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.science_outlined),
                        selectedIcon: Icon(Icons.science),
                        label: Text('Research'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.smart_toy_outlined),
                        selectedIcon: Icon(Icons.smart_toy),
                        label: Text('Claude Tools'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: const [
                        CodeTab(),
                        ResearchTab(),
                        ClaudeToolsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

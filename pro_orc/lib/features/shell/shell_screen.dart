import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/tray/tray_service.dart';
import 'package:pro_orc/window/window_geometry_service.dart';
import 'package:pro_orc/features/agents/agents_tab.dart';
import 'package:pro_orc/features/claude_tools/claude_tools_tab.dart';
import 'package:pro_orc/features/code/code_tab.dart';
import 'package:pro_orc/features/research/research_tab.dart';
import 'package:pro_orc/features/settings/settings_tab.dart';
import 'package:pro_orc/features/shell/glow_border_shell.dart';
import 'package:pro_orc/features/shell/launch_dialog.dart';
import 'package:pro_orc/features/shell/orb_background.dart';

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
      try {
        if (enable) {
          await launchAtStartup.enable();
        } else {
          await launchAtStartup.disable();
        }
      } catch (_) {
        // launch_at_startup plugin may fail in debug mode
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
                  _SideNav(
                    selectedIndex: _selectedIndex,
                    onSelect: (i) => setState(() => _selectedIndex = i),
                    colors: colors,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: const [
                        CodeTab(),
                        ResearchTab(),
                        ClaudeToolsTab(),
                        AgentsTab(),
                        SettingsTab(),
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

// ---------------------------------------------------------------------------
// Custom side navigation — full control over icon weight and text style
// ---------------------------------------------------------------------------

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.colors,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AppColors colors;

  static const _items = <({IconData icon, String label})>[
    (icon: LucideIcons.codeXml100, label: 'Code'),
    (icon: LucideIcons.beaker100, label: 'Research'),
    (icon: LucideIcons.brain100, label: 'Tools'),
    (icon: LucideIcons.bot100, label: 'Agents'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Image.asset(
              'assets/images/tray_icon.png',
              width: 24,
              height: 24,
              color: colors.cyan.withValues(alpha: 0.6),
            ),
          ),
          // Nav items
          for (int i = 0; i < _items.length; i++)
            _NavItem(
              icon: _items[i].icon,
              label: _items[i].label,
              selected: selectedIndex == i,
              accent: colors.cyan,
              dimColor: colors.textDim,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          // Settings
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _NavItem(
              icon: LucideIcons.settings100,
              label: 'Settings',
              selected: selectedIndex == 4,
              accent: colors.cyan,
              dimColor: colors.textDim,
              onTap: () => onSelect(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.dimColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final Color dimColor;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    final color = active ? widget.accent : widget.dimColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 68,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 22),
              if (widget.selected) ...[
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

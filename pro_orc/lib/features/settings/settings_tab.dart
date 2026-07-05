import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pro_orc/features/onboarding/onboarding_wizard.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/learning_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/providers/theme_mode_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Full-page settings tab — manages scan directories, ignore patterns,
/// git binary path, and launch-at-login preference.
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  List<String> _scanDirs = [];
  List<String> _ignorePatterns = [];
  String _gitBinaryPath = 'git';
  String _vaultDir = '';
  bool _launchAtLogin = false;
  bool _loading = true;

  final _gitController = TextEditingController();
  final _ignoreAddController = TextEditingController();
  final _vaultController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _gitController.dispose();
    _ignoreAddController.dispose();
    _vaultController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(appDatabaseProvider);
    final dirs = await db.getScanDirs();
    final config = await db.getConfig();

    List<String> patterns = [];
    try {
      final decoded = jsonDecode(config.ignoreListJson);
      if (decoded is List) {
        patterns = decoded.whereType<String>().toList();
      }
    } catch (_) {}

    bool launchEnabled = false;
    try {
      launchEnabled = await launchAtStartup.isEnabled();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _scanDirs = List.from(dirs);
        _ignorePatterns = patterns;
        _gitBinaryPath = config.gitBinaryPath;
        _gitController.text = config.gitBinaryPath;
        _vaultDir = config.vaultDir;
        _vaultController.text = config.vaultDir;
        _launchAtLogin = launchEnabled;
        _loading = false;
      });
    }
  }

  // --- Scan Dirs ---

  Future<void> _addScanDir() async {
    final dir = await getDirectoryPath();
    if (dir != null && !_scanDirs.contains(dir)) {
      setState(() => _scanDirs.add(dir));
      await _saveScanDirs();
    }
  }

  Future<void> _removeScanDir(int index) async {
    setState(() => _scanDirs.removeAt(index));
    await _saveScanDirs();
  }

  Future<void> _saveScanDirs() async {
    final db = ref.read(appDatabaseProvider);
    await db.setScanDirs(_scanDirs);
    ref.invalidate(projectsProvider);
  }

  // --- Ignore Patterns ---

  Future<void> _addIgnorePattern() async {
    final pattern = _ignoreAddController.text.trim();
    if (pattern.isNotEmpty && !_ignorePatterns.contains(pattern)) {
      setState(() => _ignorePatterns.add(pattern));
      _ignoreAddController.clear();
      await _saveIgnorePatterns();
    }
  }

  Future<void> _removeIgnorePattern(int index) async {
    setState(() => _ignorePatterns.removeAt(index));
    await _saveIgnorePatterns();
  }

  Future<void> _saveIgnorePatterns() async {
    final db = ref.read(appDatabaseProvider);
    await db.updateConfig(ignoreListJson: jsonEncode(_ignorePatterns));
    ref.invalidate(projectsProvider);
  }

  // --- Git Binary ---

  Future<void> _saveGitBinary() async {
    final value = _gitController.text.trim();
    if (value.isNotEmpty && value != _gitBinaryPath) {
      setState(() => _gitBinaryPath = value);
      final db = ref.read(appDatabaseProvider);
      await db.updateConfig(gitBinaryPath: value);
      ref.invalidate(projectsProvider);
    }
  }

  // --- Vault-Pfad ---

  Future<void> _saveVaultDir() async {
    final value = _vaultController.text.trim();
    if (value == _vaultDir) return;
    setState(() => _vaultDir = value);
    final db = ref.read(appDatabaseProvider);
    await db.setVaultDir(value);
    ref.invalidate(learningProvider);
  }

  // --- Launch at Login ---

  Future<void> _toggleLaunchAtLogin(bool value) async {
    setState(() => _launchAtLogin = value);
    try {
      if (value) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (_) {
      // May fail in debug mode
    }
  }

  // --- Setup Wizard ---

  Future<void> _restartWizard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OnboardingWizard(
        onComplete: () {
          ref.invalidate(watcherProvider);
          ref.invalidate(projectsProvider);
          _loadSettings(); // Refresh settings tab state
        },
      ),
    );
    await prefs.setBool('onboarding_completed', true);
  }

  // --- UI Helpers ---

  String _abbreviatePath(String path) {
    return path.replaceFirst(RegExp(r'^/Users/[^/]+'), '~');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.cyan),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Einstellungen',
            style: TextStyle(
              color: colors.textPri,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // --- Erscheinungsbild ---
          _buildThemeSection(colors),

          const SizedBox(height: 20),

          // --- Scan-Ordner ---
          _buildSection(
            colors: colors,
            icon: Icons.folder_outlined,
            title: 'Scan-Ordner',
            subtitle: 'Verzeichnisse, die nach Projekten durchsucht werden',
            child: Column(
              children: [
                if (_scanDirs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Keine Ordner konfiguriert',
                      style: TextStyle(color: colors.textSec, fontSize: 13),
                    ),
                  )
                else
                  ...List.generate(_scanDirs.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildDirRow(colors, _scanDirs[i], () => _removeScanDir(i)),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addScanDir,
                    icon: Icon(Icons.add, size: 16, color: colors.cyan),
                    label: Text(
                      'Ordner hinzufuegen',
                      style: TextStyle(color: colors.cyan, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.cyan.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Ignore-Muster ---
          _buildSection(
            colors: colors,
            icon: Icons.visibility_off_outlined,
            title: 'Ignorierte Ordner',
            subtitle: 'Ordnernamen oder Prefixe mit * (z.B. build*)',
            child: Column(
              children: [
                if (_ignorePatterns.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_ignorePatterns.length, (i) {
                      return Chip(
                        label: Text(
                          _ignorePatterns[i],
                          style: TextStyle(
                            color: colors.textSec,
                            fontSize: 12,
                            fontFamily: 'SF Mono',
                          ),
                        ),
                        deleteIcon: Icon(Icons.close, size: 14, color: colors.textDim),
                        onDeleted: () => _removeIgnorePattern(i),
                        backgroundColor: colors.bgElev.withValues(alpha: 0.6),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ignoreAddController,
                        style: TextStyle(
                          color: colors.textPri,
                          fontSize: 13,
                          fontFamily: 'SF Mono',
                        ),
                        decoration: colors.glassInputDecoration(
                          hintText: 'Muster eingeben...',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addIgnorePattern(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addIgnorePattern,
                      icon: Icon(Icons.add_circle_outline, color: colors.cyan, size: 20),
                      tooltip: 'Hinzufuegen',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Git Binary ---
          _buildSection(
            colors: colors,
            icon: Icons.terminal_outlined,
            title: 'Git-Pfad',
            subtitle: 'Pfad zum Git-Binary (Standard: git)',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gitController,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 13,
                      fontFamily: 'SF Mono',
                    ),
                    decoration: colors.glassInputDecoration(isDense: true),
                    onSubmitted: (_) => _saveGitBinary(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saveGitBinary,
                  child: Text(
                    'Speichern',
                    style: TextStyle(color: colors.cyan, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Vault-Pfad ---
          _buildSection(
            colors: colors,
            icon: LucideIcons.notebook,
            title: 'Obsidian-Vault',
            subtitle: 'Pfad zum Vault für die Learning-Ansicht '
                '(Standard: ~/N3URAL-Vault)',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vaultController,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 13,
                      fontFamily: 'SF Mono',
                    ),
                    decoration: colors.glassInputDecoration(
                      hintText: '~/N3URAL-Vault',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveVaultDir(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saveVaultDir,
                  child: Text(
                    'Speichern',
                    style: TextStyle(color: colors.cyan, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Launch at Login ---
          _buildSection(
            colors: colors,
            icon: Icons.rocket_launch_outlined,
            title: 'Autostart',
            subtitle: 'App beim Login automatisch starten',
            child: Row(
              children: [
                Text(
                  _launchAtLogin ? 'Aktiviert' : 'Deaktiviert',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _launchAtLogin,
                  onChanged: _toggleLaunchAtLogin,
                  activeTrackColor: colors.cyan,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Setup Wizard ---
          _buildSection(
            colors: colors,
            icon: LucideIcons.wand,
            title: 'Setup',
            subtitle: 'Ersteinrichtungs-Wizard erneut durchlaufen',
            child: TextButton.icon(
              onPressed: _restartWizard,
              icon: Icon(LucideIcons.refreshCw, size: 16, color: colors.cyan),
              label: Text(
                'Setup-Wizard erneut starten',
                style: TextStyle(color: colors.textSec, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(AppColors colors) {
    final currentMode = ref.watch(themeModeProvider);

    return _buildSection(
      colors: colors,
      icon: Icons.palette_outlined,
      title: 'Erscheinungsbild',
      subtitle: 'Hell, Dunkel oder System-Einstellung folgen',
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Hell'),
            icon: Icon(Icons.light_mode_outlined, size: 16),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Dunkel'),
            icon: Icon(Icons.dark_mode_outlined, size: 16),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('System'),
            icon: Icon(Icons.settings_suggest_outlined, size: 16),
          ),
        ],
        selected: {currentMode},
        onSelectionChanged: (selected) {
          ref.read(themeModeProvider.notifier).setMode(selected.first);
        },
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, color: colors.textPri),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.textDim.withValues(alpha: 0.3)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.cyan.withValues(alpha: 0.18);
            }
            return colors.bgElev.withValues(alpha: 0.4);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.cyan;
            }
            return colors.textSec;
          }),
        ),
      ),
    );
  }

  Widget _buildSection({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.cyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: colors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDirRow(AppColors colors, String dir, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.folder, color: colors.cyan.withValues(alpha: 0.7), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _abbreviatePath(dir),
              style: TextStyle(
                color: colors.textSec,
                fontSize: 12,
                fontFamily: 'SF Mono',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.remove_circle_outline, color: colors.textDim, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Dialog for creating a new Code or Research project.
///
/// Opened from [CodeTab] or [ResearchTab] via their Add+ cards.
/// Returns a [Map<String, dynamic>] with form values on confirm,
/// or null when dismissed.
///
/// Phase 15 will wire the actual filesystem creation logic.
class CreateProjectDialog extends ConsumerStatefulWidget {
  const CreateProjectDialog({
    super.key,
    required this.initialTab,
  });

  /// Initial tab to display: 'code' or 'research'.
  final String initialTab;

  @override
  ConsumerState<CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<CreateProjectDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _nameController;

  String _derivedFolderName = '';
  bool _folderExists = false;
  String? _selectedScanDir;
  List<String> _scanDirs = [];

  // Code tab toggles
  bool _gitInit = true;
  bool _gsdSkeleton = true;
  bool _codeRemSleep = false;

  // Research tab toggles
  bool _notion = true;
  bool _researchRemSleep = true;

  // ignore: prefer_final_fields
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'research' ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabChanged);
    _nameController = TextEditingController();
    _loadScanDirs();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadScanDirs() async {
    final db = ref.read(appDatabaseProvider);
    final dirs = await db.getScanDirs();
    if (mounted) {
      setState(() {
        _scanDirs = dirs;
        _selectedScanDir = dirs.isNotEmpty ? dirs.first : null;
      });
      // Re-check folder existence with the loaded scan dir
      _updateDerivedName(_nameController.text);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Tab switch completed — reset toggles to this tab's defaults
      setState(() {
        if (_tabController.index == 0) {
          _gitInit = true;
          _gsdSkeleton = true;
          _codeRemSleep = false;
        } else {
          _notion = true;
          _researchRemSleep = true;
        }
      });
    }
  }

  void _updateDerivedName(String input) {
    final derived = _deriveFolderName(input);
    bool exists = false;
    if (derived.isNotEmpty && _selectedScanDir != null) {
      final fullPath = path.join(_selectedScanDir!, derived);
      exists = Directory(fullPath).existsSync();
    }
    setState(() {
      _derivedFolderName = derived;
      _folderExists = exists;
    });
  }

  String _deriveFolderName(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    // Replace spaces with underscores, then remove any chars not in [a-z0-9_-]
    final withUnderscores = trimmed.replaceAll(' ', '_');
    return withUnderscores.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
  }

  String _abbreviatePath(String p) {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && p.startsWith(home)) {
      return '~${p.substring(home.length)}';
    }
    return p;
  }

  bool get _isFormValid =>
      _derivedFolderName.isNotEmpty && !_folderExists && !_isLoading;

  String get _dialogTitle {
    return _tabController.index == 0
        ? 'Neues Code-Projekt'
        : 'Neues Research-Projekt';
  }

  Color _accentColor(AppColors colors) {
    return _tabController.index == 0 ? colors.cyan : colors.fuch;
  }

  void _submit() {
    if (!_isFormValid) return;
    final isCode = _tabController.index == 0;
    Navigator.of(context).pop(<String, dynamic>{
      'name': _nameController.text.trim(),
      'folderName': _derivedFolderName,
      'scanDir': _selectedScanDir,
      'tab': isCode ? 'code' : 'research',
      'gitInit': isCode ? _gitInit : false,
      'gsdSkeleton': isCode ? _gsdSkeleton : false,
      'notion': isCode ? false : _notion,
      'remSleep': isCode ? _codeRemSleep : _researchRemSleep,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = _accentColor(colors);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            blendMode: BlendMode.src,
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: colors.bgSurf,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colors, accent),
                  const SizedBox(height: 16),
                  _buildTabBar(colors, accent),
                  const SizedBox(height: 20),
                  _buildNameField(colors, accent),
                  const SizedBox(height: 4),
                  _buildFolderPreview(colors),
                  const SizedBox(height: 16),
                  _buildZielordnerDropdown(colors, accent),
                  const SizedBox(height: 8),
                  _buildToggles(colors, accent),
                  const SizedBox(height: 24),
                  _buildButtons(colors, accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors, Color accent) {
    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _dialogTitle,
              key: ValueKey(_tabController.index),
              style: TextStyle(
                color: colors.textPri,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.textDim, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 16,
          tooltip: 'Schliessen',
        ),
      ],
    );
  }

  Widget _buildTabBar(AppColors colors, Color accent) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final currentAccent = _accentColor(colors);
        return TabBar(
          controller: _tabController,
          labelColor: colors.textPri,
          unselectedLabelColor: colors.textDim,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: currentAccent,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: colors.textDim.withValues(alpha: 0.2),
          tabs: const [
            Tab(text: 'Code'),
            Tab(text: 'Research'),
          ],
        );
      },
    );
  }

  Widget _buildNameField(AppColors colors, Color accent) {
    return TextField(
      controller: _nameController,
      autofocus: true,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      cursorColor: accent,
      decoration: InputDecoration(
        hintText: 'Projektname',
        hintStyle: TextStyle(color: colors.textDim, fontSize: 14),
        filled: true,
        fillColor: colors.bgElev.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: _updateDerivedName,
    );
  }

  Widget _buildFolderPreview(AppColors colors) {
    if (_derivedFolderName.isEmpty) {
      return const SizedBox(height: 16);
    }
    if (_folderExists) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          'Ordner existiert bereits',
          style: TextStyle(color: colors.amber, fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        'Ordner: $_derivedFolderName',
        style: TextStyle(color: colors.textSec, fontSize: 12),
      ),
    );
  }

  Widget _buildZielordnerDropdown(AppColors colors, Color accent) {
    if (_scanDirs.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      initialValue: _selectedScanDir,
      dropdownColor: colors.bgElev,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      iconEnabledColor: colors.textDim,
      decoration: InputDecoration(
        labelText: 'Zielordner',
        labelStyle: TextStyle(color: colors.textDim, fontSize: 12),
        filled: true,
        fillColor: colors.bgElev.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: _scanDirs.map((dir) {
        return DropdownMenuItem<String>(
          value: dir,
          child: Text(
            _abbreviatePath(dir),
            style: TextStyle(color: colors.textPri, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedScanDir = value;
        });
        _updateDerivedName(_nameController.text);
      },
    );
  }

  Widget _buildToggles(AppColors colors, Color accent) {
    final isCode = _tabController.index == 0;

    final codeToggles = Column(
      key: const ValueKey('code-toggles'),
      children: [
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'Git Repository initialisieren',
          value: _gitInit,
          onChanged: (v) => setState(() => _gitInit = v),
        ),
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'GSD Skeleton anlegen',
          value: _gsdSkeleton,
          onChanged: (v) => setState(() => _gsdSkeleton = v),
        ),
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'rem-sleep nach Erstellung',
          value: _codeRemSleep,
          onChanged: (v) => setState(() => _codeRemSleep = v),
        ),
      ],
    );

    final researchToggles = Column(
      key: const ValueKey('research-toggles'),
      children: [
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'Notion-Seite erstellen',
          value: _notion,
          onChanged: (v) => setState(() => _notion = v),
        ),
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'rem-sleep nach Erstellung',
          value: _researchRemSleep,
          onChanged: (v) => setState(() => _researchRemSleep = v),
        ),
      ],
    );

    // Fixed height to prevent dialog resize on tab switch.
    // 3 toggles × 28px (24 switch + 4 padding) = 84px
    return SizedBox(
      height: 84,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isCode ? codeToggles : researchToggles,
      ),
    );
  }

  Widget _buildToggle({
    required AppColors colors,
    required Color accent,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colors.textPri, fontSize: 13),
            ),
          ),
          SizedBox(
            height: 24,
            width: 40,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: value,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.4),
                inactiveThumbColor: colors.textDim,
                inactiveTrackColor: colors.textDim.withValues(alpha: 0.2),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(AppColors colors, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isFormValid ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            disabledBackgroundColor: accent.withValues(alpha: 0.3),
            foregroundColor: colors.bgBase,
            disabledForegroundColor: colors.bgBase.withValues(alpha: 0.5),
          ),
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}

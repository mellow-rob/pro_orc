import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:pro_orc/data/services/project_creator_service.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Dialog for creating a new Code or Research project.
///
/// Opened from [CodeTab] or [ResearchTab] via their Add+ cards.
/// Calls [createProject] to create the filesystem scaffold, then
/// triggers optional post-creation actions (Terminal, rem-sleep).
/// Auto-closes on success after a brief feedback moment.
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
  bool _claudeMd = true;
  bool _terminal = true;
  bool _codeRemSleep = false;
  String _gitignoreTemplate = 'none';

  // Research tab toggles
  bool _notion = true;
  bool _researchTerminal = true;
  bool _researchRemSleep = true;

  // Track previous tab index to detect actual tab changes
  late int _previousTabIndex;

  // ignore: prefer_final_fields
  bool _isLoading = false;
  bool _isCreated = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'research' ? 1 : 0;
    _previousTabIndex = initialIndex;
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
    // Filter out non-writable directories
    final writable = <String>[];
    for (final d in dirs) {
      if (FileSystemEntity.isDirectorySync(d) && _isWritable(d)) {
        writable.add(d);
      }
    }
    if (mounted) {
      setState(() {
        _scanDirs = writable;
        _selectedScanDir = writable.isNotEmpty ? writable.first : null;
      });
      _updateDerivedName(_nameController.text);
    }
  }

  bool _isWritable(String dirPath) {
    final testFile = File(path.join(dirPath, '.pro_orc_write_test'));
    try {
      testFile.writeAsStringSync('');
      testFile.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onTabChanged() {
    // Only reset toggles on actual tab switch, not on every listener fire
    if (_tabController.index != _previousTabIndex) {
      _previousTabIndex = _tabController.index;
      setState(() {
        if (_tabController.index == 0) {
          _gitInit = true;
          _gsdSkeleton = true;
          _claudeMd = true;
          _terminal = true;
          _codeRemSleep = false;
          _gitignoreTemplate = 'none';
        } else {
          _notion = true;
          _researchTerminal = true;
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
    // Replace spaces and underscores with hyphens for kebab-case
    final withHyphens = trimmed.replaceAll(RegExp(r'[\s_]+'), '-');
    // Remove any chars not in [a-z0-9-]
    final cleaned = withHyphens.replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    // Collapse multiple hyphens into one
    return cleaned.replaceAll(RegExp(r'-{2,}'), '-');
  }

  String _abbreviatePath(String p) {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && p.startsWith(home)) {
      return '~${p.substring(home.length)}';
    }
    return p;
  }

  bool get _isFormValid =>
      _derivedFolderName.isNotEmpty &&
      !_folderExists &&
      !_isLoading &&
      !_isCreated;

  String get _dialogTitle {
    return _tabController.index == 0
        ? 'Neues Code-Projekt'
        : 'Neues Research-Projekt';
  }

  Color _accentColor(AppColors colors) {
    return _tabController.index == 0 ? colors.cyan : colors.fuch;
  }

  Future<void> _submit() async {
    if (!_isFormValid || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isCode = _tabController.index == 0;
    final result = await createProject(
      scanDir: _selectedScanDir!,
      folderName: _derivedFolderName,
      displayName: _nameController.text.trim(),
      projectType: isCode ? 'code' : 'research',
      gitInit: isCode ? _gitInit : false,
      gsdSkeleton: isCode ? _gsdSkeleton : false,
      claudeMd: isCode ? _claudeMd : false,
      gitignoreTemplate: isCode ? _gitignoreTemplate : 'none',
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isLoading = false;
        _isCreated = true;
        // Show warnings (e.g. git init failed) above the success indicator
        if (result.warnings.isNotEmpty) {
          _errorMessage = result.warnings.join(' • ');
        }
      });

      // Brief delay so user sees "Erstellt!" feedback
      final delay = result.warnings.isNotEmpty
          ? const Duration(milliseconds: 3000)
          : const Duration(milliseconds: 1500);
      await Future.delayed(delay);

      if (!mounted) return;

      // Collect post-creation action flags before closing
      final wantsTerminal = isCode ? _terminal : _researchTerminal;
      final wantsRemSleep = isCode ? _codeRemSleep : _researchRemSleep;

      // Pop with a map containing result + action flags — tab handles actions
      Navigator.of(context).pop({
        'result': result,
        'wantsTerminal': wantsTerminal,
        'wantsRemSleep': wantsRemSleep,
        'wantsNotion': !isCode && _notion,
        'displayName': _nameController.text.trim(),
      });
    } else {
      // Creation failed — show error, reset loading
      setState(() {
        _isLoading = false;
        _errorMessage = result.warnings.isNotEmpty
            ? result.warnings.first
            : 'Projekt konnte nicht erstellt werden';
      });
    }
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
    // Full path preview: ~/code/mein-projekt
    final fullPath = _selectedScanDir != null
        ? _abbreviatePath(path.join(_selectedScanDir!, _derivedFolderName))
        : _derivedFolderName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        fullPath,
        style: TextStyle(color: colors.textSec, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildZielordnerDropdown(AppColors colors, Color accent) {
    if (_scanDirs.isEmpty) return const SizedBox.shrink();
    // Hide dropdown if only one scan dir (auto-selected)
    if (_scanDirs.length == 1) return const SizedBox.shrink();

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
          title: 'CLAUDE.md erstellen',
          value: _claudeMd,
          onChanged: (v) => setState(() => _claudeMd = v),
        ),
        _buildGitignoreDropdown(colors, accent),
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'Terminal oeffnen',
          value: _terminal,
          onChanged: (v) {
            setState(() {
              _terminal = v;
              // Switching off Terminal also switches off rem-sleep
              if (!v) _codeRemSleep = false;
            });
          },
        ),
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'rem-sleep nach Erstellung',
          value: _codeRemSleep,
          onChanged: (v) {
            setState(() {
              _codeRemSleep = v;
              // rem-sleep ON forces Terminal ON
              if (v) _terminal = true;
            });
          },
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
          title: 'Terminal oeffnen',
          value: _researchTerminal,
          onChanged: (v) {
            setState(() {
              _researchTerminal = v;
              // Switching off Terminal also switches off rem-sleep
              if (!v) _researchRemSleep = false;
            });
          },
        ),
        _buildToggle(
          colors: colors,
          accent: accent,
          title: 'rem-sleep nach Erstellung',
          value: _researchRemSleep,
          onChanged: (v) {
            setState(() {
              _researchRemSleep = v;
              // rem-sleep ON forces Terminal ON
              if (v) _researchTerminal = true;
            });
          },
        ),
      ],
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isCode ? codeToggles : researchToggles,
      ),
    );
  }

  Widget _buildGitignoreDropdown(AppColors colors, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DropdownButtonFormField<String>(
        initialValue: _gitignoreTemplate,
        dropdownColor: colors.bgElev,
        style: TextStyle(color: colors.textPri, fontSize: 13),
        iconEnabledColor: colors.textDim,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '.gitignore Template',
          labelStyle: TextStyle(color: colors.textDim, fontSize: 11),
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
            borderSide:
                BorderSide(color: accent.withValues(alpha: 0.5), width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'none', child: Text('Kein .gitignore')),
          DropdownMenuItem(value: 'flutter', child: Text('Flutter')),
          DropdownMenuItem(value: 'nodejs', child: Text('Node.js')),
          DropdownMenuItem(value: 'python', child: Text('Python')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _gitignoreTemplate = value);
        },
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
    final isDisabled = _isLoading || _isCreated;

    Widget buttonChild;
    if (_isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.bgBase,
        ),
      );
    } else if (_isCreated) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: colors.bgBase, size: 16),
          const SizedBox(width: 4),
          const Text('Erstellt!'),
        ],
      );
    } else {
      buttonChild = const Text('Erstellen');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // Warning/error text — shown above buttons row
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: colors.amber, fontSize: 12),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isDisabled ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: colors.textSec,
                disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
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
              child: buttonChild,
            ),
          ],
        ),
      ],
    );
  }
}

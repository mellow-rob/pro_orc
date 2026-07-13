import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:pro_orc/data/models/gitignore_template.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_creator_service.dart';
import 'package:pro_orc/features/shared/create_project/dialog_buttons.dart';
import 'package:pro_orc/features/shared/create_project/dialog_header.dart';
import 'package:pro_orc/features/shared/create_project/form_fields.dart';
import 'package:pro_orc/features/shared/create_project/toggles_section.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Dialog for creating a new Code or Research project.
///
/// Opened from the merged Projekte tab's Add+ menu.
/// Calls [createProject] to create the filesystem scaffold, then
/// triggers optional post-creation actions (Terminal, rem-sleep).
/// Auto-closes on success after a brief feedback moment.
class CreateProjectDialog extends ConsumerStatefulWidget {
  const CreateProjectDialog({super.key, required this.initialTab});

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
  bool _claudeMd = true;
  bool _terminal = true;
  bool _codeRemSleep = false;
  GitignoreTemplate _gitignoreTemplate = GitignoreTemplate.none;

  // Research tab toggles
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
    } catch (e) {
      developer.log(
        'Directory not writable: $dirPath: $e',
        name: 'create_project_dialog',
      );
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
          _claudeMd = true;
          _terminal = true;
          _codeRemSleep = false;
          _gitignoreTemplate = GitignoreTemplate.none;
        } else {
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
      projectType: isCode ? ProjectType.code : ProjectType.research,
      gitInit: isCode ? _gitInit : false,
      claudeMd: isCode ? _claudeMd : false,
      gitignoreTemplate: isCode ? _gitignoreTemplate : GitignoreTemplate.none,
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

    return GlassDialog(
      maxWidth: 480,
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
    );
  }

  Widget _buildHeader(AppColors colors, Color accent) {
    return CreateProjectDialogHeader(
      title: _dialogTitle,
      tabIndex: _tabController.index,
      colors: colors,
      onClose: () => Navigator.of(context).pop(),
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
    return ProjectNameField(
      controller: _nameController,
      colors: colors,
      accent: accent,
      onChanged: _updateDerivedName,
    );
  }

  Widget _buildFolderPreview(AppColors colors) {
    // Full path preview: ~/code/mein-projekt
    final fullPath = _selectedScanDir != null
        ? _abbreviatePath(path.join(_selectedScanDir!, _derivedFolderName))
        : _derivedFolderName;
    return FolderPreview(
      derivedFolderName: _derivedFolderName,
      folderExists: _folderExists,
      fullPathPreview: fullPath,
      colors: colors,
    );
  }

  Widget _buildZielordnerDropdown(AppColors colors, Color accent) {
    return ZielordnerDropdown(
      scanDirs: _scanDirs,
      selectedScanDir: _selectedScanDir,
      colors: colors,
      accent: accent,
      abbreviatePath: _abbreviatePath,
      onChanged: (value) {
        setState(() {
          _selectedScanDir = value;
        });
        _updateDerivedName(_nameController.text);
      },
    );
  }

  Widget _buildToggles(AppColors colors, Color accent) {
    return TogglesSection(
      isCode: _tabController.index == 0,
      colors: colors,
      accent: accent,
      gitInit: _gitInit,
      onGitInitChanged: (v) => setState(() => _gitInit = v),
      claudeMd: _claudeMd,
      onClaudeMdChanged: (v) => setState(() => _claudeMd = v),
      gitignoreTemplate: _gitignoreTemplate,
      onGitignoreTemplateChanged: (v) =>
          setState(() => _gitignoreTemplate = v),
      terminal: _terminal,
      onTerminalChanged: (v) {
        setState(() {
          _terminal = v;
          // Switching off Terminal also switches off rem-sleep
          if (!v) _codeRemSleep = false;
        });
      },
      codeRemSleep: _codeRemSleep,
      onCodeRemSleepChanged: (v) {
        setState(() {
          _codeRemSleep = v;
          // rem-sleep ON forces Terminal ON
          if (v) _terminal = true;
        });
      },
      researchTerminal: _researchTerminal,
      onResearchTerminalChanged: (v) {
        setState(() {
          _researchTerminal = v;
          // Switching off Terminal also switches off rem-sleep
          if (!v) _researchRemSleep = false;
        });
      },
      researchRemSleep: _researchRemSleep,
      onResearchRemSleepChanged: (v) {
        setState(() {
          _researchRemSleep = v;
          // rem-sleep ON forces Terminal ON
          if (v) _researchTerminal = true;
        });
      },
    );
  }

  Widget _buildButtons(AppColors colors, Color accent) {
    return CreateProjectDialogButtons(
      colors: colors,
      accent: accent,
      isLoading: _isLoading,
      isCreated: _isCreated,
      isFormValid: _isFormValid,
      errorMessage: _errorMessage,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
    );
  }
}

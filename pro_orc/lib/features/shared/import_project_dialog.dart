import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/gitignore_template.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_importer_service.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Import dialog for existing folders — previews analysis, offers smart
/// scaffold toggles, handles scan-dir expansion.
///
/// Opened after the user picks a folder via the native file picker.
/// Uses [GlassDialog] wrapper, consistent with [CreateProjectDialog].
class ImportProjectDialog extends ConsumerStatefulWidget {
  const ImportProjectDialog({
    super.key,
    required this.analysis,
    required this.scanDirs,
  });

  final FolderAnalysis analysis;
  final List<String> scanDirs;

  @override
  ConsumerState<ImportProjectDialog> createState() =>
      _ImportProjectDialogState();
}

class _ImportProjectDialogState extends ConsumerState<ImportProjectDialog> {
  late ProjectType _selectedType;

  // Scaffold toggles (only meaningful when the corresponding file is missing)
  bool _claudeMd = true;
  bool _gitInit = true;
  GitignoreTemplate _gitignoreTemplate = GitignoreTemplate.none;

  // Scan-dir expansion
  bool _addParentAsScanDir = true;

  bool _isImporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.analysis.detectedType;
    _applyTypeDefaults(_selectedType);
  }

  void _applyTypeDefaults(ProjectType type) {
    _gitInit = type != ProjectType.research;
  }

  Color _accent(AppColors colors) =>
      _selectedType == ProjectType.code ? colors.cyan : colors.fuch;

  String _abbreviatePath(String path) {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  Future<void> _import() async {
    if (_isImporting) return;
    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      // 1. Scaffold
      final result = await scaffoldProject(
        projectPath: widget.analysis.path,
        displayName: widget.analysis.folderName,
        claudeMd: !widget.analysis.hasClaudeMd && _claudeMd,
        gitignoreTemplate:
            !widget.analysis.hasGitignore ? _gitignoreTemplate : GitignoreTemplate.none,
        gitInit: !widget.analysis.hasGit && _gitInit,
      );

      // 2. Handle scan-dir expansion
      if (!widget.analysis.isInsideScanDir && _addParentAsScanDir) {
        final parentDir = p.dirname(widget.analysis.path);
        final db = ref.read(appDatabaseProvider);
        final currentDirs = await db.getScanDirs();
        if (!currentDirs.contains(parentDir)) {
          currentDirs.add(parentDir);
          await db.setScanDirs(currentDirs);
        }
      }

      // 3. Persist project type in DB
      final folderId = p.basename(widget.analysis.path);
      final db = ref.read(appDatabaseProvider);
      await db.upsertProjectSettings(ProjectSettingsTableCompanion.insert(
        folderId: folderId,
        projectType: Value(_selectedType.name),
      ));

      // 4. Invalidate watcher + projects — CRITICAL for live update
      ref.invalidate(watcherProvider);
      ref.invalidate(projectsProvider);

      if (!mounted) return;

      // 5. Close dialog, return success
      Navigator.of(context).pop({
        'success': true,
        'result': result,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorMessage = 'Import fehlgeschlagen: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = _accent(colors);
    final analysis = widget.analysis;

    return GlassDialog(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colors, accent, analysis),
          const SizedBox(height: 16),
          _buildTypeSelector(colors, accent),
          const SizedBox(height: 16),
          _buildSmartDefaults(colors, accent, analysis),
          const SizedBox(height: 12),
          _buildScanDirBanner(colors, analysis),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: colors.amber, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          _buildButtons(colors, accent),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors colors, Color accent, FolderAnalysis analysis) {
    return Row(
      children: [
        Icon(
          _selectedType == ProjectType.code ? Icons.code : Icons.science,
          color: accent,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analysis.folderName,
                style: TextStyle(
                  color: colors.textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _abbreviatePath(analysis.path),
                style: TextStyle(color: colors.textDim, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

  Widget _buildTypeSelector(AppColors colors, Color accent) {
    return Row(
      children: [
        Text(
          'Projekttyp:',
          style: TextStyle(color: colors.textSec, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<ProjectType>(
            segments: [
              ButtonSegment(
                value: ProjectType.code,
                label: const Text('Code'),
                icon: const Icon(Icons.code, size: 16),
              ),
              ButtonSegment(
                value: ProjectType.research,
                label: const Text('Research'),
                icon: const Icon(Icons.science, size: 16),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (values) {
              setState(() {
                _selectedType = values.first;
                _applyTypeDefaults(_selectedType);
              });
            },
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return colors.bgBase;
                }
                return colors.textSec;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return accent;
                }
                return Colors.transparent;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: colors.textDim.withValues(alpha: 0.3)),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartDefaults(
      AppColors colors, Color accent, FolderAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scaffold-Optionen',
          style: TextStyle(
            color: colors.textSec,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // CLAUDE.md
        _buildScaffoldRow(
          colors: colors,
          accent: accent,
          title: 'CLAUDE.md',
          exists: analysis.hasClaudeMd,
          value: _claudeMd,
          onChanged: (v) => setState(() => _claudeMd = v),
        ),
        // .gitignore
        _buildGitignoreRow(colors, accent, analysis),
        // git init
        _buildScaffoldRow(
          colors: colors,
          accent: accent,
          title: 'Git Repository',
          exists: analysis.hasGit,
          existsLabel: 'Git vorhanden',
          value: _gitInit,
          onChanged: (v) => setState(() => _gitInit = v),
        ),
      ],
    );
  }

  /// Builds a scaffold toggle row — greyed out "Vorhanden" when file exists,
  /// active toggle when missing.
  Widget _buildScaffoldRow({
    required AppColors colors,
    required Color accent,
    required String title,
    required bool exists,
    required bool value,
    required ValueChanged<bool> onChanged,
    String existsLabel = 'Vorhanden',
  }) {
    if (exists) {
      // Greyed-out row with checkmark
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: colors.textDim, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: colors.textDim, fontSize: 13),
              ),
            ),
            Text(
              existsLabel,
              style: TextStyle(color: colors.textDim, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Active toggle row
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

  Widget _buildGitignoreRow(
      AppColors colors, Color accent, FolderAnalysis analysis) {
    if (analysis.hasGitignore) {
      return _buildScaffoldRow(
        colors: colors,
        accent: accent,
        title: '.gitignore',
        exists: true,
        value: false,
        onChanged: (_) {},
      );
    }

    // .gitignore missing — show dropdown
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DropdownButtonFormField<GitignoreTemplate>(
        initialValue: _gitignoreTemplate,
        dropdownColor: colors.bgElev,
        style: TextStyle(color: colors.textPri, fontSize: 13),
        iconEnabledColor: colors.textDim,
        isExpanded: true,
        decoration: colors.glassInputDecoration(
          labelText: '.gitignore Template',
          accentColor: accent,
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(
              value: GitignoreTemplate.none, child: Text('Kein .gitignore')),
          DropdownMenuItem(
              value: GitignoreTemplate.flutter, child: Text('Flutter')),
          DropdownMenuItem(
              value: GitignoreTemplate.nodejs, child: Text('Node.js')),
          DropdownMenuItem(
              value: GitignoreTemplate.nextjs, child: Text('HTML + Next.js')),
          DropdownMenuItem(
              value: GitignoreTemplate.python, child: Text('Python')),
          DropdownMenuItem(
              value: GitignoreTemplate.html, child: Text('HTML (statisch)')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _gitignoreTemplate = value);
        },
      ),
    );
  }

  Widget _buildScanDirBanner(AppColors colors, FolderAnalysis analysis) {
    if (analysis.isInsideScanDir) {
      // Already inside scan dir — amber warning
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.amber.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ordner wird bereits ueber ${_abbreviatePath(analysis.containingScanDir!)} gescannt',
                style: TextStyle(color: colors.amber, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Outside scan dirs — info banner with checkbox
    final parentDir = p.dirname(analysis.path);
    final parentName = p.basename(parentDir);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.cyan.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ordner liegt ausserhalb der Scan-Verzeichnisse',
                  style: TextStyle(color: colors.cyan, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _addParentAsScanDir,
                  activeColor: colors.cyan,
                  onChanged: (v) =>
                      setState(() => _addParentAsScanDir = v ?? true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Parent-Ordner ($parentName) als Scan-Verzeichnis hinzufuegen',
                  style: TextStyle(color: colors.textSec, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(AppColors colors, Color accent) {
    Widget buttonChild;
    if (_isImporting) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.bgBase,
        ),
      );
    } else {
      buttonChild = const Text('Importieren');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isImporting ? null : _import,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            disabledBackgroundColor: accent.withValues(alpha: 0.3),
            foregroundColor: colors.bgBase,
            disabledForegroundColor: colors.bgBase.withValues(alpha: 0.5),
          ),
          child: buttonChild,
        ),
      ],
    );
  }
}

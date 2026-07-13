import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/group_section_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_creator_service.dart';
import 'package:pro_orc/data/services/project_importer_service.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/projects/group_section.dart';
import 'package:pro_orc/features/projects/hidden_projects_section.dart';
import 'package:pro_orc/features/projects/projects_tab_header.dart';
import 'package:pro_orc/features/projects/projects_type_filter.dart';
import 'package:pro_orc/features/shared/create_project_dialog.dart';
import 'package:pro_orc/features/shared/empty_state.dart';
import 'package:pro_orc/features/shared/hidden_projects_banner.dart';
import 'package:pro_orc/features/shared/import_project_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/grouped_projects_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// The merged "Projekte" tab (FR-020): replaces the former Code/Research
/// tab split with one view showing every project, sectioned by group
/// (FR-011), with a global grid/list toggle (FR-001) and type filter chips
/// (FR-021). Group-management actions (drag & drop, ⋯ menus, "+ Gruppe")
/// are wired in Wave 4 — this wave only renders the structure.
class ProjectsTab extends ConsumerStatefulWidget {
  const ProjectsTab({super.key});

  @override
  ConsumerState<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends ConsumerState<ProjectsTab> {
  ProjectsTypeFilter _filter = ProjectsTypeFilter.all;
  bool _showHidden = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.cyan)),
      error: (err, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Fehler beim Laden der Projekte',
              style: TextStyle(color: colors.textSec, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(projectsProvider),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.cyan,
                side: BorderSide(color: colors.cyan.withValues(alpha: 0.5)),
              ),
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
      data: (allProjects) => _buildContent(context, colors, allProjects),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    List<ProjectModel> allProjects,
  ) {
    if (allProjects.isEmpty) {
      return EmptyState(
        tabName: 'Projekte',
        message:
            'Lege Projekte als Unterordner in deinem Scan-Verzeichnis an, '
            'oder waehle einen anderen Ordner.',
        onPickDirectory: () => _pickScanDir(context),
      );
    }

    final hiddenSet = ref.watch(hiddenProjectsProvider);
    final hiddenProjects =
        allProjects.where((p) => hiddenSet.contains(p.folderId)).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final sections = ref.watch(groupedProjectsProvider);
    final filteredSections = _applyTypeFilter(sections);
    final viewMode = ref.watch(viewModeProvider);

    return Column(
      children: [
        ProjectsTabHeader(
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
          viewMode: viewMode,
          onAddPressed: (position) => _showAddMenu(context, position),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final section in filteredSections)
                GroupSection(key: ValueKey(section.group.id), data: section),
            ],
          ),
        ),
        if (hiddenProjects.isNotEmpty)
          HiddenProjectsBanner(
            hiddenCount: hiddenProjects.length,
            isExpanded: _showHidden,
            onToggle: () => setState(() => _showHidden = !_showHidden),
            accentColor: colors.cyan,
          ),
        if (_showHidden && hiddenProjects.isNotEmpty)
          HiddenProjectsSection(projects: hiddenProjects, viewMode: viewMode),
      ],
    );
  }

  List<GroupSectionData> _applyTypeFilter(List<GroupSectionData> sections) {
    if (_filter == ProjectsTypeFilter.all) return sections;
    final wanted = _filter == ProjectsTypeFilter.code
        ? ProjectType.code
        : ProjectType.research;

    return [
      for (final section in sections)
        GroupSectionData(
          group: section.group,
          members: section.members
              .where((p) => (p.projectType ?? ProjectType.code) == wanted)
              .toList(),
        ),
    ];
  }

  Future<void> _pickScanDir(BuildContext context) async {
    final dir = await getDirectoryPath();
    if (dir != null) {
      final db = ref.read(appDatabaseProvider);
      await db.updateConfig(scanDir: dir);
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _showAddMenu(BuildContext _, Offset position) async {
    final ctx = context;
    final colors = Theme.of(ctx).extension<AppColors>()!;
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: ctx,
      color: colors.bgElev,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'create',
          child: Row(
            children: [
              Icon(Icons.add, color: colors.textSec, size: 18),
              const SizedBox(width: 8),
              Text(
                'Neues Projekt',
                style: TextStyle(color: colors.textPri, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.folder_open, color: colors.textSec, size: 18),
              const SizedBox(width: 8),
              Text(
                'Ordner importieren',
                style: TextStyle(color: colors.textPri, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted || result == null) return;

    if (result == 'create') {
      await _openCreateDialog();
    } else if (result == 'import') {
      await _openImportFlow();
    }
  }

  Future<void> _openImportFlow() async {
    final dir = await getDirectoryPath();
    if (dir == null || !mounted) return;

    final projects = ref.read(projectsProvider).value ?? [];
    final alreadyExists = projects.any((p) => p.path == dir);
    if (alreadyExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projekt ist bereits im Dashboard vorhanden'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final scanDirs = await db.getScanDirs();
    final analysis = await analyzeFolder(dir, scanDirs);

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) =>
          ImportProjectDialog(analysis: analysis, scanDirs: scanDirs),
    );

    if (result != null && result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projekt importiert'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => const CreateProjectDialog(initialTab: 'code'),
    );
    if (result != null) {
      final creationResult = result['result'] as ProjectCreationResult;
      final wantsRemSleep = result['wantsRemSleep'] as bool? ?? false;
      final wantsTerminal = result['wantsTerminal'] as bool? ?? false;

      final folderId = p.basename(creationResult.projectPath);
      final db = ref.read(appDatabaseProvider);
      await db.upsertProjectSettings(
        ProjectSettingsTableCompanion.insert(
          folderId: folderId,
          projectType: Value(ProjectType.code.name),
        ),
      );

      ref.invalidate(projectsProvider);

      final actions = QuickActionsService();
      if (wantsRemSleep) {
        await actions.openRemSleep(creationResult.projectPath);
      } else if (wantsTerminal) {
        await actions.openInTerminal(creationResult.projectPath);
      }
    }
  }
}

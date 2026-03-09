import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_creator_service.dart';
import 'package:pro_orc/data/services/project_importer_service.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/code/code_project_card.dart';
import 'package:pro_orc/features/shared/add_project_card.dart';
import 'package:pro_orc/features/shared/create_project_dialog.dart';
import 'package:pro_orc/features/shared/import_project_dialog.dart';
import 'package:pro_orc/features/shared/empty_state.dart';
import 'package:pro_orc/features/shared/hidden_projects_banner.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Code tab — responsive grid of [CodeProjectCard]s sorted by last git activity.
///
/// Features:
/// - 2-4 column responsive grid via [LayoutBuilder]
/// - Cards sorted descending by [GitData.lastCommitDate] (null last)
/// - Hidden projects filtered out with an expandable banner
/// - [EmptyState] with NSOpenPanel folder picker when no projects exist
class CodeTab extends ConsumerStatefulWidget {
  const CodeTab({super.key});

  @override
  ConsumerState<CodeTab> createState() => _CodeTabState();
}

class _CodeTabState extends ConsumerState<CodeTab> {
  bool _showHidden = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final projectsAsync = ref.watch(projectsProvider);
    final hiddenSet = ref.watch(hiddenProjectsProvider);

    return projectsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.cyan),
      ),
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
      data: (projects) => _buildContent(context, colors, projects, hiddenSet),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    List<ProjectModel> allProjects,
    Set<String> hiddenSet,
  ) {
    // Filter to code projects (type == code or unclassified null)
    final codeProjects = allProjects
        .where((p) => p.projectType == ProjectType.code || p.projectType == null)
        .toList();

    // Separate visible and hidden
    final visible = codeProjects
        .where((p) => !hiddenSet.contains(p.folderId))
        .toList();
    final hidden = codeProjects
        .where((p) => hiddenSet.contains(p.folderId))
        .toList();

    // Sort by last commit date descending (null dates sort last)
    void sortByActivity(List<ProjectModel> list) {
      list.sort((a, b) {
        final aDate = a.git?.lastCommitDate;
        final bDate = b.git?.lastCommitDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    }

    sortByActivity(visible);
    sortByActivity(hidden);

    // Empty state — no projects at all
    if (visible.isEmpty && hidden.isEmpty) {
      return EmptyState(
        tabName: 'Code',
        message:
            'Lege Projekte als Unterordner in deinem Scan-Verzeichnis an, '
            'oder waehle einen anderen Ordner.',
        onPickDirectory: () => _pickScanDir(context),
      );
    }

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = switch (constraints.maxWidth) {
                > 1100 => 4,
                > 750 => 3,
                _ => 2,
              };

              final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 240,
              );

              // If showing private projects, use CustomScrollView with both grids
              if (_showHidden && hidden.isNotEmpty) {
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => CodeProjectCard(
                            project: visible[index],
                            onTap: () => _showDetail(context, visible[index]),
                          ),
                          childCount: visible.length,
                        ),
                        gridDelegate: gridDelegate,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => CodeProjectCard(
                            project: hidden[index],
                            isHiddenCard: true,
                            onTap: () => _showDetail(context, hidden[index]),
                          ),
                          childCount: hidden.length,
                        ),
                        gridDelegate: gridDelegate,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => AddProjectCard(
                            accentColor: colors.cyan,
                            onTapWithPosition: (ctx, pos) =>
                                _showAddMenu(ctx, pos, 'code'),
                          ),
                          childCount: 1,
                        ),
                        gridDelegate: gridDelegate,
                      ),
                    ),
                  ],
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: gridDelegate,
                itemCount: visible.length + 1,
                itemBuilder: (context, index) {
                  if (index == visible.length) {
                    return AddProjectCard(
                      accentColor: colors.cyan,
                      onTapWithPosition: (ctx, pos) =>
                          _showAddMenu(ctx, pos, 'code'),
                    );
                  }
                  return CodeProjectCard(
                    project: visible[index],
                    onTap: () => _showDetail(context, visible[index]),
                  );
                },
              );
            },
          ),
        ),

        // --- Private projects banner (always pinned at bottom) ---
        if (hidden.isNotEmpty)
          HiddenProjectsBanner(
            hiddenCount: hidden.length,
            isExpanded: _showHidden,
            onToggle: () => setState(() => _showHidden = !_showHidden),
            accentColor: colors.cyan,
          ),
      ],
    );
  }

  Future<void> _pickScanDir(BuildContext context) async {
    final dir = await getDirectoryPath();
    if (dir != null) {
      final db = ref.read(appDatabaseProvider);
      await db.updateConfig(scanDir: dir);
      ref.invalidate(projectsProvider);
    }
  }

  void _showDetail(BuildContext context, ProjectModel project) {
    showProjectDetail(context, project);
  }

  Future<void> _showAddMenu(
      BuildContext _, Offset position, String tabType) async {
    final ctx = context;
    final colors = Theme.of(ctx).extension<AppColors>()!;
    final overlay =
        Overlay.of(ctx).context.findRenderObject() as RenderBox;
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
              Text('Neues Projekt',
                  style: TextStyle(color: colors.textPri, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.folder_open, color: colors.textSec, size: 18),
              const SizedBox(width: 8),
              Text('Ordner importieren',
                  style: TextStyle(color: colors.textPri, fontSize: 13)),
            ],
          ),
        ),
      ],
    );

    if (!mounted || result == null) return;

    if (result == 'create') {
      await _openCreateDialog(tabType);
    } else if (result == 'import') {
      await _openImportFlow();
    }
  }

  Future<void> _openImportFlow() async {
    final dir = await getDirectoryPath();
    if (dir == null || !mounted) return;

    // Duplicate check — prevent importing an already-known project
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
      builder: (ctx) => ImportProjectDialog(
        analysis: analysis,
        scanDirs: scanDirs,
      ),
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

  Future<void> _openCreateDialog(String initialTab) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => CreateProjectDialog(initialTab: initialTab),
    );
    if (result != null) {
      final creationResult = result['result'] as ProjectCreationResult;
      final wantsRemSleep = result['wantsRemSleep'] as bool? ?? false;
      final wantsTerminal = result['wantsTerminal'] as bool? ?? false;

      // Persist projectType in DB so scanner classifies correctly
      final folderId = p.basename(creationResult.projectPath);
      final db = ref.read(appDatabaseProvider);
      await db.upsertProjectSettings(ProjectSettingsTableCompanion.insert(
        folderId: folderId,
        projectType: Value(ProjectType.code.name),
      ));

      // Force rescan so new project appears in tab
      ref.invalidate(projectsProvider);

      // Execute post-creation actions (Terminal, rem-sleep)
      final actions = QuickActionsService();
      if (wantsRemSleep) {
        await actions.openRemSleep(creationResult.projectPath);
      } else if (wantsTerminal) {
        await actions.openInTerminal(creationResult.projectPath);
      }
    }
  }
}

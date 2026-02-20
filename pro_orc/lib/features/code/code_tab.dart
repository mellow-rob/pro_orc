import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/code/code_project_card.dart';
import 'package:pro_orc/features/shared/empty_state.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
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
    // Filter to code projects (type == 'code' or unclassified null)
    final codeProjects = allProjects
        .where((p) => p.projectType == 'code' || p.projectType == null)
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
        // --- Responsive grid ---
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = switch (constraints.maxWidth) {
                > 1100 => 4,
                > 750 => 3,
                _ => 2,
              };

              final gridItems = <Widget>[
                ...visible.map(
                  (p) => CodeProjectCard(
                    project: p,
                    onTap: () => _showDetail(context, p),
                  ),
                ),
                if (_showHidden)
                  ...hidden.map(
                    (p) => CodeProjectCard(
                      project: p,
                      isHiddenCard: true,
                      onTap: () => _showDetail(context, p),
                    ),
                  ),
              ];

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 300,
                ),
                itemCount: gridItems.length,
                itemBuilder: (context, index) => gridItems[index],
              );
            },
          ),
        ),

        // --- Hidden projects banner ---
        if (hidden.isNotEmpty)
          _buildHiddenBanner(colors, hidden.length),
      ],
    );
  }

  Widget _buildHiddenBanner(AppColors colors, int hiddenCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => setState(() => _showHidden = !_showHidden),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  color: colors.textDim,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '$hiddenCount ${hiddenCount == 1 ? 'Projekt' : 'Projekte'} ausgeblendet',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  _showHidden ? 'Ausblenden' : 'Alle zeigen',
                  style: TextStyle(
                    color: colors.cyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showHidden ? Icons.expand_less : Icons.expand_more,
                  color: colors.cyan,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
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
}

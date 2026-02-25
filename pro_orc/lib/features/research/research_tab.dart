import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/research/research_project_card.dart';
import 'package:pro_orc/features/shared/add_project_card.dart';
import 'package:pro_orc/features/shared/create_project_dialog.dart';
import 'package:pro_orc/features/shared/empty_state.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Research tab — responsive grid of [ResearchProjectCard]s sorted alphabetically.
///
/// Features:
/// - 2-4 column responsive grid via [LayoutBuilder]
/// - Cards sorted ascending by displayName
/// - Hidden projects filtered out with an expandable banner
/// - [EmptyState] when no research projects exist
class ResearchTab extends ConsumerStatefulWidget {
  const ResearchTab({super.key});

  @override
  ConsumerState<ResearchTab> createState() => _ResearchTabState();
}

class _ResearchTabState extends ConsumerState<ResearchTab> {
  bool _showHidden = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final projectsAsync = ref.watch(projectsProvider);
    final hiddenSet = ref.watch(hiddenProjectsProvider);

    return projectsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.fuch),
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
                foregroundColor: colors.fuch,
                side: BorderSide(color: colors.fuch.withValues(alpha: 0.5)),
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
    // Filter to research projects
    final researchProjects = allProjects
        .where((p) => p.projectType == 'research')
        .toList();

    // Separate visible and hidden
    final visible = researchProjects
        .where((p) => !hiddenSet.contains(p.folderId))
        .toList();
    final hidden = researchProjects
        .where((p) => hiddenSet.contains(p.folderId))
        .toList();

    // Sort alphabetically by displayName
    visible.sort((a, b) => a.displayName.compareTo(b.displayName));
    hidden.sort((a, b) => a.displayName.compareTo(b.displayName));

    // Empty state — no research projects at all
    if (visible.isEmpty && hidden.isEmpty) {
      return EmptyState(
        tabName: 'Research',
        message:
            'Lege Projekte mit projectType: research in deinem Scan-Verzeichnis an.',
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
                mainAxisExtent: 220,
              );

              if (_showHidden && hidden.isNotEmpty) {
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => ResearchProjectCard(
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
                          (context, index) => ResearchProjectCard(
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
                            accentColor: colors.fuch,
                            onTap: () =>
                                _openCreateDialog(context, 'research'),
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
                      accentColor: colors.fuch,
                      onTap: () => _openCreateDialog(context, 'research'),
                    );
                  }
                  return ResearchProjectCard(
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
                  '$hiddenCount private ${hiddenCount == 1 ? 'Projekt' : 'Projekte'}',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  _showHidden ? 'Verbergen' : 'Anzeigen',
                  style: TextStyle(
                    color: colors.fuch,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showHidden ? Icons.expand_less : Icons.expand_more,
                  color: colors.fuch,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, ProjectModel project) {
    showProjectDetail(context, project);
  }

  void _openCreateDialog(BuildContext context, String initialTab) {
    showDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => CreateProjectDialog(initialTab: initialTab),
    );
    // New project appears automatically via watcher-driven projectsProvider invalidation
  }
}

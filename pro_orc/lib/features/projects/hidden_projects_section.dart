import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/projects/project_card.dart';
import 'package:pro_orc/features/projects/project_list_row.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';

/// Flat "Privat" section rendered beneath the group sections when the
/// hidden-projects banner is expanded — mirrors the old Code/Research tabs'
/// behaviour of listing hidden projects outside the normal grid, now
/// independent of group sectioning (hidden projects are excluded from
/// `groupedProjectsProvider` entirely, so they need their own render path).
class HiddenProjectsSection extends StatelessWidget {
  const HiddenProjectsSection({
    super.key,
    required this.projects,
    required this.viewMode,
  });

  final List<ProjectModel> projects;
  final ViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.list) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (final project in projects)
              ProjectListRow(
                project: project,
                isHiddenRow: true,
                onTap: () => showProjectDetail(context, project),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = switch (constraints.maxWidth) {
            > 1100 => 4,
            > 750 => 3,
            _ => 2,
          };

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 240,
            ),
            itemCount: projects.length,
            itemBuilder: (context, index) => ProjectCard(
              project: projects[index],
              isHiddenCard: true,
              onTap: () => showProjectDetail(context, projects[index]),
            ),
          );
        },
      ),
    );
  }
}

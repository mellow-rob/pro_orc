import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/group_section_data.dart';
import 'package:pro_orc/features/projects/project_card.dart';
import 'package:pro_orc/features/projects/project_list_row.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/providers/group_collapse_provider.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Toolbar-style header + collapsible body for one group of projects in the
/// merged Projekte tab.
///
/// - User groups: folder icon, name, member-count pill, and a "..." menu
///   button (placeholder only in Wave 3 — group actions ship in Wave 4).
/// - The system-owned "Archiv" group: archive-box icon instead of folder,
///   no "..." button at all (not just disabled — absent from the tree),
///   and its members render at 60% opacity.
///
/// Collapse state is read/toggled via [groupCollapseProvider] with no
/// animation (instant show/hide), per the Wave 3 spec.
class GroupSection extends ConsumerWidget {
  const GroupSection({super.key, required this.data});

  final GroupSectionData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final collapseState = ref.watch(groupCollapseProvider);
    final collapsed = collapseState[data.group.id] ?? false;
    final viewMode = ref.watch(viewModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ref, colors, collapsed),
          if (!collapsed) ...[
            const SizedBox(height: 10),
            _buildBody(context, colors, viewMode),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    bool collapsed,
  ) {
    final isArchive = data.group.isSystem;

    return InkWell(
      onTap: () =>
          ref.read(groupCollapseProvider.notifier).toggle(data.group.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isArchive ? LucideIcons.archive100 : LucideIcons.folder100,
              color: colors.textSec,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              data.group.name,
              style: TextStyle(
                color: colors.textPri,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            _buildCountPill(colors),
            const Spacer(),
            Icon(
              collapsed
                  ? LucideIcons.chevronRight100
                  : LucideIcons.chevronDown100,
              color: colors.textDim,
              size: 16,
            ),
            if (!isArchive) ...[
              const SizedBox(width: 4),
              // Wave 4 wires rename/dissolve behind this button — placeholder only.
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(LucideIcons.ellipsis100, color: colors.textDim),
                onPressed: null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountPill(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: colors.bgElev,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${data.members.length}',
        style: TextStyle(color: colors.textSec, fontSize: 11),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppColors colors, ViewMode viewMode) {
    if (data.members.isEmpty) {
      return _EmptyGroupCallToAction(colors: colors);
    }

    final body = viewMode == ViewMode.list
        ? _buildList(context)
        : _buildGrid(context);

    if (!data.group.isSystem) return body;
    return Opacity(opacity: 0.6, child: body);
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        for (final project in data.members)
          ProjectListRow(
            project: project,
            onTap: () => showProjectDetail(context, project),
          ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
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
          itemCount: data.members.length,
          itemBuilder: (context, index) => ProjectCard(
            project: data.members[index],
            onTap: () => showProjectDetail(context, data.members[index]),
          ),
        );
      },
    );
  }
}

class _EmptyGroupCallToAction extends StatelessWidget {
  const _EmptyGroupCallToAction({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Noch keine Projekte — Karte hierher ziehen oder per Rechtsklick zuweisen.',
        style: TextStyle(color: colors.textDim, fontSize: 12),
      ),
    );
  }
}

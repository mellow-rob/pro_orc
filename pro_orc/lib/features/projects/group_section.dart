import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/group_section_data.dart';
import 'package:pro_orc/features/projects/project_card.dart';
import 'package:pro_orc/features/projects/project_list_row.dart';
import 'package:pro_orc/features/projects/rename_group_dialog.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/providers/group_collapse_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Toolbar-style header + collapsible body for one group of projects in the
/// merged Projekte tab.
///
/// - User groups: folder icon, name, member-count pill, and a "..." menu
///   button (rename/dissolve — FR-019).
/// - The system-owned "Archiv" group: archive-box icon instead of folder,
///   no "..." button at all (not just disabled — absent from the tree),
///   and its members render at 60% opacity.
/// - The synthetic "Ohne Gruppe" section behaves like a user group for drop
///   purposes (assigns to `null`) but has no rename/dissolve menu either,
///   since it has no backing DB row.
///
/// The whole section (header + body) is a `DragTarget<String>` (FR-007):
/// dropping a project already in this section is a silent no-op (no DB
/// write, no flicker); dropping a project from elsewhere assigns it here.
///
/// Collapse state is read/toggled via [groupCollapseProvider] with no
/// animation (instant show/hide), per the Wave 3 spec.
class GroupSection extends ConsumerStatefulWidget {
  const GroupSection({super.key, required this.data});

  final GroupSectionData data;

  @override
  ConsumerState<GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends ConsumerState<GroupSection> {
  bool _dragHover = false;

  GroupSectionData get data => widget.data;

  /// The groupId a drop on this section should assign to: `null` for "Ohne
  /// Gruppe" (its synthetic id is not a real DB row), otherwise the group's
  /// own id — including the Archiv sentinel, which is a normal drop target
  /// with no special-casing (KERNENTSCHEIDUNG 4/1).
  String? get _dropTargetGroupId =>
      data.isUngrouped ? null : data.group.id;

  bool _isNoOpDrop(String folderId) {
    final currentGroupId = ref.read(membershipProvider)[folderId];
    return currentGroupId == _dropTargetGroupId;
  }

  Future<void> _handleDrop(String folderId) async {
    setState(() => _dragHover = false);
    if (_isNoOpDrop(folderId)) return;

    final targetGroupId = _dropTargetGroupId;
    final notifier = ref.read(membershipProvider.notifier);
    if (targetGroupId == null) {
      await notifier.unassign(folderId);
    } else {
      await notifier.assign(folderId, targetGroupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final collapseState = ref.watch(groupCollapseProvider);
    final collapsed = collapseState[data.group.id] ?? false;
    final viewMode = ref.watch(viewModeProvider);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (_) {
        if (!_dragHover) setState(() => _dragHover = true);
      },
      onLeave: (_) => setState(() => _dragHover = false),
      onAcceptWithDetails: (details) => _handleDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: _dragHover
                ? colors.cyan.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
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
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    bool collapsed,
  ) {
    final isArchive = data.group.isSystem;
    final showMenuButton = !isArchive && !data.isUngrouped;

    return InkWell(
      onTap: () =>
          ref.read(groupCollapseProvider.notifier).toggle(data.group.id),
      onSecondaryTapUp: showMenuButton
          ? (details) => _showHeaderMenu(context, details.globalPosition)
          : null,
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
            Flexible(
              child: Tooltip(
                message: data.group.name,
                child: Text(
                  data.group.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            if (showMenuButton) ...[
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(LucideIcons.ellipsis100, color: colors.textDim),
                tooltip: 'Gruppen-Optionen',
                onPressed: () => _showHeaderMenu(
                  context,
                  _iconButtonAnchor(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Offset _iconButtonAnchor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset(box.size.width, box.size.height));
  }

  Future<void> _showHeaderMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('Umbenennen…')),
        PopupMenuItem(value: 'dissolve', child: Text('Aufloesen')),
      ],
    );

    if (!context.mounted || result == null) return;

    if (result == 'rename') {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RenameGroupDialog(group: data.group),
      );
    } else if (result == 'dissolve') {
      await ref.read(groupsProvider.notifier).dissolve(data.group.id);
    }
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

/// Placeholder button shown in an empty group's body, opening the create
/// dialog is not applicable here — kept purely informational; assignment
/// happens by dragging a card or via the context menu.
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

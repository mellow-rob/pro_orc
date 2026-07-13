import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/projects/a1_badge.dart';
import 'package:pro_orc/features/projects/draggable_project.dart';
import 'package:pro_orc/features/projects/type_badge.dart';
import 'package:pro_orc/features/shared/memory_indicator.dart';
import 'package:pro_orc/features/shared/project_context_menu.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Narrow row layout for the list view mode of the merged Projekte tab
/// (FR-012 — full field parity with [pro_orc.features.projects.project_card.ProjectCard]:
/// name, status/type badge, progress bar, description, all in one line).
class ProjectListRow extends ConsumerWidget {
  const ProjectListRow({
    super.key,
    required this.project,
    this.onTap,
    this.isHiddenRow = false,
  });

  final ProjectModel project;
  final VoidCallback? onTap;
  final bool isHiddenRow;

  ProjectType get _type => project.projectType ?? ProjectType.code;

  Color _accent(AppColors colors) =>
      _type == ProjectType.research ? colors.fuch : colors.cyan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = _accent(colors);
    final hiddenSet = ref.watch(hiddenProjectsProvider);
    final isHidden = hiddenSet.contains(project.folderId);
    final progress = project.a1?.overallProgress;

    return DraggableProject(
      folderId: project.folderId,
      child: Opacity(
        opacity: isHiddenRow ? 0.45 : 1.0,
        child: GestureDetector(
          onTap: onTap,
          onSecondaryTapUp: (details) => showProjectContextMenu(
            context: context,
            details: details,
            isHidden: isHidden,
            ref: ref,
            project: project,
            moveTarget: _type == ProjectType.code
                ? ProjectType.research
                : ProjectType.code,
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              borderRadius: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      _type == ProjectType.research
                          ? LucideIcons.beaker100
                          : LucideIcons.codeXml100,
                      color: accent,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    TypeBadge(type: _type),
                    const SizedBox(width: 6),
                    A1Badge(project: project),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 160,
                      child: Text(
                        project.displayName,
                        style: TextStyle(
                          color: colors.textPri,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (progress != null) ...[
                      SizedBox(
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 4,
                            color: colors.bgElev,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0, 100) / 100.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${progress.clamp(0, 100)}%',
                        style: TextStyle(color: colors.textSec, fontSize: 11),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: project.description != null
                          ? Text(
                              project.description!,
                              style: TextStyle(
                                color: colors.textSec,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const SizedBox.shrink(),
                    ),
                    MemoryIndicator(
                      memory: project.memory,
                      colors: colors,
                      onTap: () => ref
                          .read(quickActionsProvider)
                          .openRemSleep(project.path),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 15,
                        icon: Icon(
                          isHidden ? LucideIcons.eyeOff100 : LucideIcons.eye100,
                          color: colors.textDim,
                        ),
                        tooltip: isHidden ? 'Oeffentlich' : 'Privat',
                        onPressed: () {
                          ref
                              .read(hiddenProjectsProvider.notifier)
                              .toggle(project.folderId);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 15,
                        icon: Icon(
                          LucideIcons.ellipsis100,
                          color: colors.textDim,
                        ),
                        tooltip: 'Optionen',
                        onPressed: () => showProjectContextMenuAt(
                          context: context,
                          position: _menuAnchor(context),
                          isHidden: isHidden,
                          ref: ref,
                          project: project,
                          moveTarget: _type == ProjectType.code
                              ? ProjectType.research
                              : ProjectType.code,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Anchors the "..." menu near the row's top-right, mirroring how
  /// right-click positions the menu at the pointer.
  Offset _menuAnchor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset(box.size.width - 8, 8));
  }
}

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
import 'package:pro_orc/features/shared/quick_actions.dart';
import 'package:pro_orc/features/shared/session_live_indicator.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Unified grid card for a project, replacing the former per-tab
/// CodeProjectCard/ResearchProjectCard split now that both project types
/// live in the merged Projekte tab (FR-012).
///
/// Renders: [TypeBadge] + [A1Badge], name, optional a1 progress block,
/// description, memory indicator, and quick action buttons. The accent
/// color (title icon, hover glow, Claude button) still follows the
/// project's [ProjectType] to preserve visual continuity with the old tabs.
class ProjectCard extends ConsumerStatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.isHiddenCard = false,
  });

  final ProjectModel project;
  final VoidCallback? onTap;

  /// When true, the card is rendered with reduced opacity to indicate it's hidden.
  final bool isHiddenCard;

  @override
  ConsumerState<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<ProjectCard> {
  bool _isHovered = false;

  ProjectType get _type => widget.project.projectType ?? ProjectType.code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = _type.accent(colors);
    final hiddenSet = ref.watch(hiddenProjectsProvider);
    final isHidden = hiddenSet.contains(widget.project.folderId);

    return DraggableProject(
      folderId: widget.project.folderId,
      child: Opacity(
        opacity: widget.isHiddenCard ? 0.45 : 1.0,
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapUp: (details) => showProjectContextMenu(
            context: context,
            details: details,
            isHidden: isHidden,
            ref: ref,
            project: widget.project,
            moveTarget: _type.moveTarget,
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildContent(context, colors, accent, isHidden),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    Color accent,
    bool isHidden,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBadgeRow(),
        const SizedBox(height: 8),
        _buildTitleRow(colors, accent, isHidden),
        const SizedBox(height: 10),
        if (_a1Progress != null) ...[
          _buildA1Block(colors, accent, _a1Progress!),
          const SizedBox(height: 10),
        ],
        if (widget.project.description != null) ...[
          Text(
            widget.project.description!,
            style: TextStyle(color: colors.textSec, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        MemoryIndicator(
          memory: widget.project.memory,
          colors: colors,
          onTap: () =>
              ref.read(quickActionsProvider).openRemSleep(widget.project.path),
        ),
        const Spacer(),
        _buildClaudeButton(colors, accent),
        const SizedBox(height: 8),
        buildQuickActionRow(
          buildProjectQuickActions(
            widget.project,
            ref.read(quickActionsProvider),
          ),
          colors,
        ),
      ],
    );
  }

  Widget _buildBadgeRow() {
    return Row(
      children: [
        TypeBadge(type: _type),
        const SizedBox(width: 6),
        A1Badge(project: widget.project),
      ],
    );
  }

  Widget _buildTitleRow(AppColors colors, Color accent, bool isHidden) {
    final sessionsAsync = ref.watch(
      projectSessionsProvider(widget.project.path),
    );
    final hasActiveSession = sessionsAsync.value?.hasActiveSession ?? false;

    return Row(
      children: [
        Icon(_type.icon, color: accent, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  widget.project.displayName,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasActiveSession) ...[
                const SizedBox(width: 6),
                SessionLiveIndicator(colors: colors),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: Icon(
              isHidden ? LucideIcons.eyeOff100 : LucideIcons.eye100,
              color: colors.textDim,
            ),
            tooltip: isHidden ? 'Oeffentlich' : 'Privat',
            onPressed: () {
              ref
                  .read(hiddenProjectsProvider.notifier)
                  .toggle(widget.project.folderId);
            },
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: Icon(LucideIcons.ellipsis100, color: colors.textDim),
            tooltip: 'Optionen',
            onPressed: () => showProjectContextMenuAt(
              context: context,
              position: _menuAnchor(context),
              isHidden: isHidden,
              ref: ref,
              project: widget.project,
              moveTarget: _type.moveTarget,
            ),
          ),
        ),
      ],
    );
  }

  /// Anchors the "..." menu near the card's top-right, mirroring how
  /// right-click positions the menu at the pointer.
  Offset _menuAnchor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset(box.size.width - 8, 8));
  }

  /// Aggregate a1 phase progress (0-100), or null when the project has no
  /// measurable a1 phases.
  int? get _a1Progress => widget.project.a1?.overallProgress;

  Widget _buildA1Block(AppColors colors, Color accent, int progress) {
    final a1 = widget.project.a1!;
    final active = a1.activePhase;
    final clamped = progress.clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fortschritt',
              style: TextStyle(color: colors.textSec, fontSize: 11),
            ),
            const Spacer(),
            Text(
              '$clamped%',
              style: TextStyle(color: colors.textSec, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 4,
            color: colors.bgElev,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped / 100.0,
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        if (active != null) ...[
          const SizedBox(height: 8),
          Text(
            'Phase ${active.name} · ${active.checkedTasks}/${active.totalTasks}',
            style: TextStyle(color: colors.textSec, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildClaudeButton(AppColors colors, Color accent) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: () =>
            ref.read(quickActionsProvider).openClaude(widget.project.path),
        icon: Icon(LucideIcons.sparkles100, size: 16, color: accent),
        label: Text(
          'Claude',
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }
}

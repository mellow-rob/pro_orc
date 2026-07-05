import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/gsd_status.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/memory_indicator.dart';
import 'package:pro_orc/features/shared/project_context_menu.dart';
import 'package:pro_orc/features/shared/quick_actions.dart';
import 'package:pro_orc/features/shared/session_live_indicator.dart';
import 'package:pro_orc/features/shared/status_badge.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Card widget for a single code project.
///
/// Renders: name + version, status badge, progress bar, next step,
/// description, and quick action buttons (Terminal, Finder, GitHub, Notion).
///
/// Hover adds a subtle cyan glow. Right-click shows Ausblenden/Einblenden
/// context menu (locked decision). Eye icon in title row does the same toggle.
class CodeProjectCard extends ConsumerStatefulWidget {
  const CodeProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.isHiddenCard = false,
  });

  final ProjectModel project;

  /// Optional tap callback — wired in Plan 03 (project detail panel).
  final VoidCallback? onTap;

  /// When true, the card is rendered with reduced opacity to indicate it's hidden.
  final bool isHiddenCard;

  @override
  ConsumerState<CodeProjectCard> createState() => _CodeProjectCardState();
}

class _CodeProjectCardState extends ConsumerState<CodeProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final hiddenSet = ref.watch(hiddenProjectsProvider);
    final isHidden = hiddenSet.contains(widget.project.folderId);

    return Opacity(
      opacity: widget.isHiddenCard ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => showProjectContextMenu(
          context: context,
          details: details,
          isHidden: isHidden,
          ref: ref,
          project: widget.project,
          moveTarget: ProjectType.research,
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
                        color: colors.cyan.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContent(context, colors, isHidden),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppColors colors, bool isHidden) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Title row ---
        _buildTitleRow(colors, isHidden),
        const SizedBox(height: 10),

        // --- GSD progress block (3 lines: status+%, bar, phases+plans) ---
        // Falls back to a1 phase progress when a project has no GSD .planning/.
        if (widget.project.gsd != null)
          _buildGsdBlock(colors)
        else if (_a1Progress != null)
          _buildA1Block(colors, _a1Progress!)
        else
          _buildGsdBlock(colors),

        // --- Next step (conditional) ---
        if (widget.project.gsd?.nextStep != null) ...[
          const SizedBox(height: 10),
          _buildNextStep(colors, widget.project.gsd!.nextStep!),
        ],

        // --- Memory indicator (below next step) ---
        const SizedBox(height: 14),
        MemoryIndicator(
          memory: widget.project.memory,
          colors: colors,
          onTap: () => ref.read(quickActionsProvider).openRemSleep(widget.project.path),
        ),

        const Spacer(),

        // --- Claude button (primary action) ---
        _buildClaudeButton(colors),
        const SizedBox(height: 8),

        // --- Quick action buttons (secondary) ---
        buildQuickActionRow(
          buildProjectQuickActions(widget.project, ref.read(quickActionsProvider)),
          colors,
        ),
      ],
    );
  }

  Widget _buildTitleRow(AppColors colors, bool isHidden) {
    final version = widget.project.gsd?.version;
    final sessionsAsync = ref.watch(projectSessionsProvider(widget.project.path));
    final hasActiveSession = sessionsAsync.value?.hasActiveSession ?? false;

    return Row(
      children: [
        Icon(LucideIcons.codeXml100, color: colors.cyan, size: 15),
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
              if (version != null) ...[
                const SizedBox(width: 6),
                Text(
                  version,
                  style: TextStyle(color: colors.textSec, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        // Eye icon for hide/show toggle
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
              ref.read(hiddenProjectsProvider.notifier).toggle(widget.project.folderId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGsdBlock(AppColors colors) {
    final gsd = widget.project.gsd;
    final progress = gsd?.phaseProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line 1: Status badge (left) + percent (right)
        Row(
          children: [
            GsdStatusBadge(status: gsd?.status),
            if (widget.project.hasParseError) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Parse error',
                child: Icon(LucideIcons.triangleAlert100, color: const Color(0xFFF59E0B), size: 13),
              ),
            ],
            const Spacer(),
            if (progress != null)
              Text(
                '${progress.clamp(0, 100)}%',
                style: TextStyle(color: colors.textSec, fontSize: 11),
              ),
          ],
        ),

        // Line 2: Progress bar
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 4,
              color: colors.bgElev,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0, 100) / 100.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.cyan,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],

        // Line 3: Phases (left) + Plans (right) — hidden when complete
        if (gsd?.status != GsdStatus.done && gsd?.status != GsdStatus.archived) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Phase ${gsd?.phasesCompleted ?? '–'}/${gsd?.phasesTotal ?? '–'}',
                style: TextStyle(color: colors.textSec, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'Plans ${gsd?.plansCompleted ?? '–'}/${gsd?.plansTotal ?? '–'}',
                style: TextStyle(color: colors.textSec, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Aggregate a1 phase progress (0-100), or null when the project has no
  /// measurable a1 phases. Used as the card fallback when there is no GSD.
  int? get _a1Progress => widget.project.a1?.overallProgress;

  /// Compact a1 progress block shown in place of the GSD block for projects
  /// that plan with `.a1/` instead of `.planning/`.
  Widget _buildA1Block(AppColors colors, int progress) {
    final a1 = widget.project.a1!;
    final active = a1.activePhase;
    final clamped = progress.clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'a1',
                style: TextStyle(
                  color: colors.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  color: colors.cyan,
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

  Widget _buildClaudeButton(AppColors colors) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: () => ref.read(quickActionsProvider).openClaude(widget.project.path),
        icon: Icon(LucideIcons.sparkles100, size: 16, color: colors.cyan),
        label: Text(
          'Claude',
          style: TextStyle(
            color: colors.cyan,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: colors.cyan.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildNextStep(AppColors colors, String nextStep) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next: ',
          style: TextStyle(color: colors.textDim, fontSize: 12),
        ),
        Expanded(
          child: Text(
            nextStep,
            style: TextStyle(color: colors.textPri, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/memory_indicator.dart';
import 'package:pro_orc/features/shared/project_context_menu.dart';
import 'package:pro_orc/features/shared/quick_actions.dart';
import 'package:pro_orc/features/shared/session_live_indicator.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Card widget for a single code project.
///
/// Renders: name, optional a1 progress block, description, memory indicator,
/// and quick action buttons (Terminal, Finder, GitHub).
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

        // --- a1 progress block (only shown when the project has .a1/ phases) ---
        if (_a1Progress != null) ...[
          _buildA1Block(colors, _a1Progress!),
          const SizedBox(height: 10),
        ],

        // --- Memory indicator ---
        const SizedBox(height: 4),
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

  /// Aggregate a1 phase progress (0-100), or null when the project has no
  /// measurable a1 phases.
  int? get _a1Progress => widget.project.a1?.overallProgress;

  /// Compact a1 progress block shown for projects that plan with `.a1/`.
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
}

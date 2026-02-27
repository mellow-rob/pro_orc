import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/shared/delete_project_dialog.dart';
import 'package:pro_orc/features/shared/memory_indicator.dart';
import 'package:pro_orc/features/shared/status_badge.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
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
        onSecondaryTapUp: (details) => _showContextMenu(context, details, isHidden),
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

        // --- Quick action buttons ---
        _buildQuickActions(colors),
      ],
    );
  }

  Widget _buildTitleRow(AppColors colors, bool isHidden) {
    final version = widget.project.gsd?.version;
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
        if (gsd?.status != 'done' && gsd?.status != 'archived') ...[
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

  Widget _buildQuickActions(AppColors colors) {
    final qa = ref.read(quickActionsProvider);
    final project = widget.project;

    // Action definitions — extensible list pattern
    final actions = <_QuickAction>[
      _QuickAction(
        icon: LucideIcons.terminal100,
        tooltip: 'Terminal',
        onPressed: () => qa.openInTerminal(project.path),
      ),
      _QuickAction(
        icon: LucideIcons.folder100,
        tooltip: 'Finder',
        onPressed: () => qa.openInFinder(project.path),
      ),
      if (project.git?.githubUrl != null)
        _QuickAction(
          icon: LucideIcons.externalLink100,
          tooltip: 'GitHub',
          onPressed: () => qa.openUrl(project.git!.githubUrl!),
        ),
      if (project.gsd?.notionUrl != null)
        _QuickAction(
          icon: LucideIcons.fileText100,
          tooltip: 'Notion',
          onPressed: () => qa.openUrl(project.gsd!.notionUrl!),
        ),
      if (project.memory != null)
        _QuickAction(
          icon: LucideIcons.moonStar100,
          tooltip: 'Claude Memory',
          onPressed: () => qa.openRemSleep(project.path),
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: actions
          .map(
            (a) => SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                icon: Icon(a.icon, color: colors.textDim),
                tooltip: a.tooltip,
                splashRadius: 16,
                onPressed: a.onPressed,
              ),
            ),
          )
          .toList(),
    );
  }

  void _showContextMenu(
    BuildContext context,
    TapUpDetails details,
    bool isHidden,
  ) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        overlay.size.width - details.globalPosition.dx,
        overlay.size.height - details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'toggle_hidden',
          child: Text(isHidden ? 'Oeffentlich' : 'Privat'),
        ),
        const PopupMenuItem(
          value: 'move_research',
          child: Text('Verschieben nach Research'),
        ),
        const PopupMenuItem(
          value: 'ignore',
          child: Text('Ignorieren'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Projekt loeschen'),
        ),
      ],
    ).then((value) {
      if (value == 'toggle_hidden') {
        ref.read(hiddenProjectsProvider.notifier).toggle(widget.project.folderId);
      } else if (value == 'move_research') {
        _setProjectType('research');
      } else if (value == 'ignore') {
        _ignoreProject();
      } else if (value == 'delete') {
        _confirmDelete();
      }
    });
  }

  Future<void> _setProjectType(String type) async {
    final db = ref.read(appDatabaseProvider);
    await db.upsertProjectSettings(
      ProjectSettingsTableCompanion(
        folderId: Value(widget.project.folderId),
        projectType: Value(type),
      ),
    );
    ref.invalidate(projectsProvider);
  }

  Future<void> _ignoreProject() async {
    final db = ref.read(appDatabaseProvider);
    await db.addIgnorePattern(widget.project.folderId);
    ref.invalidate(projectsProvider);
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (_) => DeleteProjectDialog(project: widget.project),
    );
  }
}

/// Internal action definition for the quick action button list.
class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

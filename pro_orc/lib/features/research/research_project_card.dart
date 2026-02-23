import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Card widget for a single research project.
///
/// Renders: name + description with fuchsia accent.
/// No progress bar, no status badge, no next step, no version (locked decision).
///
/// Hover adds a subtle fuchsia glow. Right-click shows Ausblenden/Einblenden
/// context menu (locked decision). Eye icon in title row does the same toggle.
class ResearchProjectCard extends ConsumerStatefulWidget {
  const ResearchProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.isHiddenCard = false,
  });

  final ProjectModel project;

  /// Optional tap callback — opens project detail panel.
  final VoidCallback? onTap;

  /// When true, the card is rendered with reduced opacity to indicate it's hidden.
  final bool isHiddenCard;

  @override
  ConsumerState<ResearchProjectCard> createState() =>
      _ResearchProjectCardState();
}

class _ResearchProjectCardState extends ConsumerState<ResearchProjectCard> {
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
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details, isHidden),
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
                        color: colors.fuch.withValues(alpha: 0.15),
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
        const SizedBox(height: 12),

        // --- Description (more prominent — no progress bar or next step to compete) ---
        if (widget.project.description != null) ...[
          Text(
            widget.project.description!,
            style: TextStyle(color: colors.textSec, fontSize: 13),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],

        const Spacer(),

        // --- Quick action buttons ---
        _buildQuickActions(colors),
      ],
    );
  }

  Widget _buildTitleRow(AppColors colors, bool isHidden) {
    return Row(
      children: [
        Icon(LucideIcons.beaker100, color: colors.fuch, size: 15),
        const SizedBox(width: 6),
        Expanded(
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
              ref
                  .read(hiddenProjectsProvider.notifier)
                  .toggle(widget.project.folderId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppColors colors) {
    final qa = ref.read(quickActionsProvider);
    final project = widget.project;

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
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
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
          value: 'move_code',
          child: Text('Verschieben nach Code'),
        ),
        const PopupMenuItem(
          value: 'ignore',
          child: Text('Ignorieren'),
        ),
      ],
    ).then((value) {
      if (value == 'toggle_hidden') {
        ref
            .read(hiddenProjectsProvider.notifier)
            .toggle(widget.project.folderId);
      } else if (value == 'move_code') {
        _setProjectType('code');
      } else if (value == 'ignore') {
        _ignoreProject();
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

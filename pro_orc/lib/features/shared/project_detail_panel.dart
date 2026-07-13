import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/models/collaboration_graph.dart';
import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/features/agents/agent_card.dart';
import 'package:pro_orc/features/shared/claude_tool_detail_panel.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/shared/collaboration_mini_graph.dart';
import 'package:pro_orc/features/shared/quick_actions.dart';
import 'package:pro_orc/features/shared/rename_project_dialog.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tab.dart';
import 'package:pro_orc/features/shared/skill_launcher_dialog.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/project_detail_provider.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Opens the project detail view embedded inside the app shell's content
/// area (replaces the previous full-screen `Navigator.push` route — the
/// shell's side navigation and background now stay visible while a detail
/// view is open).
///
/// Call this from any card's onTap callback:
/// ```dart
/// onTap: () => showProjectDetail(context, project),
/// ```
void showProjectDetail(BuildContext context, ProjectModel project) {
  ProviderScope.containerOf(
    context,
  ).read(openProjectDetailProvider.notifier).open(project);
}

/// Detail view for a project, showing all available project data.
///
/// Accent color follows project type: cyan for code, fuchsia for research.
///
/// Has two tabs (FR-001): "Übersicht" (today's content, unchanged) and
/// "Roadmap" (read-only three-tier fallback view). Embedded directly inside
/// [ShellScreen]'s content area (see `openProjectDetailProvider`) instead of
/// being pushed as its own route, so it no longer owns a [Scaffold] — the
/// shell provides the surrounding chrome. [onBack] is invoked instead of
/// `Navigator.pop` when the user wants to return to the previous tab.
class ProjectDetailPanel extends ConsumerStatefulWidget {
  const ProjectDetailPanel({super.key, required this.project, this.onBack});

  final ProjectModel project;

  /// Called when the user taps the back arrow. If omitted, falls back to
  /// clearing [openProjectDetailProvider] directly so existing call sites
  /// (e.g. tests that pump [ProjectDetailPanel] standalone) keep working.
  final VoidCallback? onBack;

  @override
  ConsumerState<ProjectDetailPanel> createState() => _ProjectDetailPanelState();
}

enum _DetailTab { uebersicht, roadmap }

class _ProjectDetailPanelState extends ConsumerState<ProjectDetailPanel> {
  _DetailTab _tab = _DetailTab.uebersicht;

  ProjectModel get project => widget.project;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = project.projectType == ProjectType.research
        ? colors.fuch
        : colors.cyan;

    return DefaultTextStyle(
      style: TextStyle(
        color: colors.textPri,
        fontSize: 14,
        decoration: TextDecoration.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: GlassCard(
          child: Column(
            children: [
              _buildHeader(context, colors, accent),
              _buildTabSwitch(colors, accent),
              // Content fills the remaining space given by the shell.
              Expanded(
                child: _tab == _DetailTab.uebersicht
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: _buildBody(context, ref, colors, accent),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: RoadmapTab(project: project, accent: accent),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitch(AppColors colors, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Row(
        children: [
          _TabButton(
            label: 'Übersicht',
            selected: _tab == _DetailTab.uebersicht,
            colors: colors,
            accent: accent,
            onTap: () => setState(() => _tab = _DetailTab.uebersicht),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Roadmap',
            selected: _tab == _DetailTab.roadmap,
            colors: colors,
            accent: accent,
            onTap: () => setState(() => _tab = _DetailTab.roadmap),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
      child: Row(
        children: [
          // Back navigation — closes the embedded detail view and returns
          // to whichever tab was active before it opened (see onBack).
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(
                LucideIcons.arrowLeft100,
                color: colors.textDim,
                size: 18,
              ),
              tooltip: 'Zurueck',
              onPressed:
                  widget.onBack ??
                  () => ref.read(openProjectDetailProvider.notifier).close(),
            ),
          ),
          const SizedBox(width: 4),
          // Accent left border strip
          Container(
            width: 2,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 16),
          // Type icon in accent circle
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              project.projectType == ProjectType.research
                  ? LucideIcons.beaker100
                  : LucideIcons.codeXml100,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    project.displayName,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    icon: Icon(
                      LucideIcons.pencil100,
                      color: colors.textDim,
                      size: 14,
                    ),
                    tooltip: 'Umbenennen',
                    onPressed: () => showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => RenameProjectDialog(project: project),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    Color accent,
  ) {
    final git = project.git;
    final qa = ref.read(quickActionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Beschreibung ---
        if (project.description != null)
          _DescriptionSection(
            colors: colors,
            accent: accent,
            description: project.description!,
          ),

        // --- Dateien (.md Hierarchie) ---
        if (project.mdFiles != null && project.mdFiles!.isNotEmpty)
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'DATEIEN',
            child: _buildFilesSection(colors, accent),
          ),

        // --- Agents ---
        if (project.usedAgents != null && project.usedAgents!.isNotEmpty)
          _buildAgentsSection(context, ref, colors, accent),

        // --- Zusammenarbeits-Graph (Projekt + lokale Agents/Skills) ---
        _buildCollaborationGraphSection(ref, colors, accent),

        // --- Sessions ---
        _buildSessionsSection(ref, colors, accent),

        // --- Git & Links ---
        if (git != null)
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'LINKS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (git.lastCommitHash != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.gitCommitHorizontal100,
                          color: colors.textDim,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          git.lastCommitHash!,
                          style: TextStyle(
                            color: colors.textSec,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(git.lastCommitDate),
                          style: TextStyle(color: colors.textDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (git.githubUrl != null)
                      _LinkChip(
                        icon: LucideIcons.externalLink100,
                        label: 'GitHub',
                        accent: accent,
                        colors: colors,
                        onTap: () => qa.openUrl(git.githubUrl!),
                      ),
                  ],
                ),
              ],
            ),
          ),

        // --- Quick Actions ---
        const SizedBox(height: 8),
        _buildQuickActions(context, colors, accent, qa),
      ],
    );
  }

  Widget _buildAgentsSection(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    Color accent,
  ) {
    final toolsAsync = ref.read(claudeToolsProvider);
    final allAgents = toolsAsync.value?.agents ?? [];

    return _SectionCard(
      colors: colors,
      accent: accent,
      title: 'AGENTS',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: project.usedAgents!.map((name) {
          final agentData = allAgents.where((a) => a.name == name).firstOrNull;
          final chipColor = agentData != null
              ? agentAccentColor(agentData.color, colors)
              : colors.textSec;

          return GestureDetector(
            onTap: agentData != null
                ? () => showAgentDetail(context, agentData)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chipColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: chipColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      color: chipColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSessionsSection(WidgetRef ref, AppColors colors, Color accent) {
    final sessionsAsync = ref.watch(projectSessionsProvider(project.path));

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.sessions.isEmpty) return const SizedBox.shrink();

        return _SectionCard(
          colors: colors,
          accent: accent,
          title: 'SESSIONS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SessionsTokenSummary(
                projectPath: project.path,
                colors: colors,
                accent: accent,
              ),
              for (int i = 0; i < data.recentFive.length; i++) ...[
                _SessionRow(
                  session: data.recentFive[i],
                  colors: colors,
                  accent: accent,
                ),
                if (i < data.recentFive.length - 1)
                  Divider(
                    height: 1,
                    color: colors.bgElev.withValues(alpha: 0.8),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollaborationGraphSection(
    WidgetRef ref,
    AppColors colors,
    Color accent,
  ) {
    final toolsAsync = ref.watch(projectToolsByPathProvider(project.path));

    return toolsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tools) {
        final graphData = CollaborationGraphData.build(
          projectId: project.folderId,
          projectName: project.displayName,
          localAgentNames: tools.agents.map((a) => a.name).toList(),
          localSkillNames: tools.skills.map((s) => s.name).toList(),
          usedAgentNames: project.usedAgents ?? const [],
        );

        if (graphData.isEmpty) return const SizedBox.shrink();

        return _SectionCard(
          colors: colors,
          accent: accent,
          title: 'ZUSAMMENARBEIT',
          child: CollaborationMiniGraph(data: graphData, colors: colors),
        );
      },
    );
  }

  Widget _buildFilesSection(AppColors colors, Color accent) {
    final tree = _buildFileTree(project.mdFiles!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Root-level files (no folder wrapper)
        for (final file in tree.files)
          _MdFileRow(file: file, depth: 0, colors: colors, accent: accent),
        // Root-level subdirectories
        for (final child in tree.children.entries)
          _FolderNode(
            name: child.key,
            node: child.value,
            depth: 0,
            colors: colors,
            accent: accent,
          ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    AppColors colors,
    Color accent,
    QuickActionsService qa,
  ) {
    final actions = [
      ...buildProjectQuickActions(project, qa),
      QuickAction(
        icon: LucideIcons.sparkles100,
        tooltip: 'Mit Skill starten',
        onPressed: () => SkillLauncherDialog.show(
          context,
          projectPath: project.path,
          projectName: project.displayName,
        ),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: actions
          .map(
            (a) =>
                _QuickActionButton(action: a, accent: accent, colors: colors),
          )
          .toList(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Segmented-control-style tab button used by [ProjectDetailPanel]'s
/// "Übersicht"/"Roadmap" switch (FR-001).
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.4) : colors.bgElev,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : colors.textDim,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section card wrapper — subtle container with accent top border.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.colors,
    required this.accent,
    required this.title,
    required this.child,
  });

  final AppColors colors;
  final Color accent;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.bgSurf.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Expandable description section — short texts always selectable,
/// long texts (>5 lines) collapsed by default with expand/collapse toggle.
class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({
    required this.colors,
    required this.accent,
    required this.description,
  });

  final AppColors colors;
  final Color accent;
  final String description;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  TextStyle get _textStyle =>
      TextStyle(color: widget.colors.textSec, fontSize: 14, height: 1.6);

  bool _needsExpansion(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.description, style: _textStyle),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      colors: widget.colors,
      accent: widget.accent,
      title: 'BESCHREIBUNG',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needsToggle = _needsExpansion(constraints.maxWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!needsToggle || _expanded)
                SelectableText(widget.description, style: _textStyle)
              else
                Text(
                  widget.description,
                  style: _textStyle,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              if (needsToggle)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ExpandToggleButton(
                    expanded: _expanded,
                    colors: widget.colors,
                    accent: widget.accent,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Toggle button with hover effect for expand/collapse sections.
class _ExpandToggleButton extends StatefulWidget {
  const _ExpandToggleButton({
    required this.expanded,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final bool expanded;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ExpandToggleButton> createState() => _ExpandToggleButtonState();
}

class _ExpandToggleButtonState extends State<_ExpandToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? widget.accent : widget.colors.textDim;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.expanded
                  ? LucideIcons.chevronDown100
                  : LucideIcons.chevronRight100,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              widget.expanded ? 'Weniger anzeigen' : 'Mehr anzeigen',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Styled link chip with icon.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button with icon + label.
class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.action,
    required this.accent,
    required this.colors,
  });

  final QuickAction action;
  final Color accent;
  final AppColors colors;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.action.onPressed,
          child: Container(
            width: 64,
            height: 52,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.action.icon,
                  color: _hovered ? widget.accent : widget.colors.textDim,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.action.tooltip,
                  style: TextStyle(
                    color: _hovered ? widget.accent : widget.colors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tree node holding files at this directory level and child directories.
/// Immutable — built once by [_buildFileTree] via [_FileTreeNodeBuilder] and
/// consumed read-only by [_FolderNode].
class _FileTreeNode {
  const _FileTreeNode({required this.files, required this.children});

  final List<MdFileInfo> files;
  final Map<String, _FileTreeNode> children;
}

/// Mutable accumulator used only while assembling the tree in
/// [_buildFileTree] — never exposed outside that function.
class _FileTreeNodeBuilder {
  final List<MdFileInfo> files = [];
  final Map<String, _FileTreeNodeBuilder> children = {};

  _FileTreeNode toNode() {
    return _FileTreeNode(
      files: files,
      children: children.map((seg, child) => MapEntry(seg, child.toNode())),
    );
  }
}

/// Builds a nested tree from a flat list of [MdFileInfo].
_FileTreeNode _buildFileTree(List<MdFileInfo> files) {
  final root = _FileTreeNodeBuilder();
  for (final file in files) {
    final dir = p.dirname(file.relativePath);
    if (dir == '.') {
      root.files.add(file);
    } else {
      final segments = p.split(dir);
      var node = root;
      for (final seg in segments) {
        node = node.children.putIfAbsent(seg, _FileTreeNodeBuilder.new);
      }
      node.files.add(file);
    }
  }
  return root.toNode();
}

/// Collapsible folder node that renders its files and nested subfolders.
class _FolderNode extends StatefulWidget {
  const _FolderNode({
    required this.name,
    required this.node,
    required this.depth,
    required this.colors,
    required this.accent,
  });

  final String name;
  final _FileTreeNode node;
  final int depth;
  final AppColors colors;
  final Color accent;

  @override
  State<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends State<_FolderNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder header (clickable to toggle)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.only(left: indent),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? LucideIcons.chevronDown100
                          : LucideIcons.chevronRight100,
                      color: widget.colors.textDim,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? LucideIcons.folderOpen100
                          : LucideIcons.folder100,
                      color: widget.colors.textDim,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: widget.colors.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Expanded content: files then child folders
        if (_expanded) ...[
          for (final file in widget.node.files)
            _MdFileRow(
              file: file,
              depth: widget.depth + 1,
              colors: widget.colors,
              accent: widget.accent,
            ),
          for (final child in widget.node.children.entries)
            _FolderNode(
              name: child.key,
              node: child.value,
              depth: widget.depth + 1,
              colors: widget.colors,
              accent: widget.accent,
            ),
        ],
      ],
    );
  }
}

/// Clickable .md file row with hover accent and optional role label.
class _MdFileRow extends StatefulWidget {
  const _MdFileRow({
    required this.file,
    required this.depth,
    required this.colors,
    required this.accent,
  });

  final MdFileInfo file;
  final int depth;
  final AppColors colors;
  final Color accent;

  @override
  State<_MdFileRow> createState() => _MdFileRowState();
}

class _MdFileRowState extends State<_MdFileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent + 18),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () =>
              Process.run('open', [widget.file.path], runInShell: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText100,
                  color: _hovered ? widget.accent : widget.colors.textDim,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.file.name,
                    style: TextStyle(
                      color: _hovered ? widget.accent : widget.colors.textPri,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.file.role != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.file.role!,
                    style: TextStyle(
                      color: widget.colors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable row showing a single session: active/inactive dot, id, and
/// last-activity timestamp. Tapping expands to a deep-dive (model, invoked
/// skills, spawned subagents, last-activity preview), which is parsed lazily
/// via [sessionDetailProvider] only on first expand (AD-1). Read-only.
class _SessionRow extends ConsumerStatefulWidget {
  const _SessionRow({
    required this.session,
    required this.colors,
    required this.accent,
  });

  final SessionInfo session;
  final AppColors colors;
  final Color accent;

  @override
  ConsumerState<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends ConsumerState<_SessionRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final colors = widget.colors;
    final statusColor = session.isActive ? colors.emerald : colors.textDim;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      session.id,
                      style: TextStyle(
                        color: colors.textPri,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.isActive
                        ? 'Aktiv'
                        : _formatSessionTime(session.lastActivity),
                    style: TextStyle(
                      color: session.isActive ? colors.emerald : colors.textDim,
                      fontSize: 11,
                      fontWeight: session.isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp100
                        : LucideIcons.chevronDown100,
                    color: colors.textDim,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) _buildDetail(),
      ],
    );
  }

  Widget _buildDetail() {
    final detailAsync = ref.watch(sessionDetailProvider(widget.session));
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.only(left: 17, bottom: 8),
      child: detailAsync.when(
        loading: () => _detailHint('Lade Details…'),
        error: (_, _) => _detailHint('Nicht lesbar'),
        data: (detail) => _SessionDetailBody(
          detail: detail,
          colors: colors,
          accent: widget.accent,
        ),
      ),
    );
  }

  Widget _detailHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: widget.colors.textDim, fontSize: 11),
      ),
    );
  }

  String _formatSessionTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m. $hh:$mm';
  }
}

/// Compact per-project token estimate summed over the recent sessions shown
/// (M7 AD-4). Explicitly labelled "ca." — it is an estimate parsed from the
/// session logs' `usage` fields, not a billed figure, and carries no euro
/// amount. Renders nothing while loading, on error, or when no estimate
/// exists.
class _SessionsTokenSummary extends ConsumerWidget {
  const _SessionsTokenSummary({
    required this.projectPath,
    required this.colors,
    required this.accent,
  });

  final String projectPath;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimateAsync = ref.watch(projectTokenEstimateProvider(projectPath));

    return estimateAsync.maybeWhen(
      data: (total) {
        if (total == null || total <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(LucideIcons.coins100, color: colors.textDim, size: 13),
              const SizedBox(width: 8),
              Text(
                'ca. ${formatTokenCount(total)} Tokens',
                style: TextStyle(color: colors.textSec, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                '(Schätzung, letzte 5 Sessions)',
                style: TextStyle(color: colors.textDim, fontSize: 11),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Body of an expanded session row: model, skills, subagents, last activity.
class _SessionDetailBody extends StatelessWidget {
  const _SessionDetailBody({
    required this.detail,
    required this.colors,
    required this.accent,
  });

  final SessionInfo detail;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (detail.model != null) {
      rows.add(_metaRow('Modell', detail.model!));
    }
    if (detail.messageCount != null) {
      rows.add(_metaRow('Nachrichten', '${detail.messageCount}'));
    }
    if (detail.hasTokenEstimate) {
      rows.add(
        _metaRow(
          'Tokens (ca.)',
          'ca. ${formatTokenCount(detail.totalTokens)} '
              '(${formatTokenCount(detail.inputTokens ?? 0)} in / '
              '${formatTokenCount(detail.outputTokens ?? 0)} out)',
        ),
      );
    }
    if (detail.skills.isNotEmpty) {
      rows.add(_chipRow('Skills', detail.skills, LucideIcons.sparkles100));
    }
    if (detail.subagents.isNotEmpty) {
      rows.add(_chipRow('Subagents', detail.subagents, LucideIcons.bot100));
    }
    if (detail.lastActivityText != null) {
      rows.add(_metaRow('Letzte Aktivität', detail.lastActivityText!));
    }

    if (rows.isEmpty) {
      return Text(
        'Keine Details verfügbar',
        style: TextStyle(color: colors.textDim, fontSize: 11),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: colors.textDim, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: colors.textPri, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _chipRow(String label, List<String> items, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: colors.textDim, fontSize: 11),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accent, size: 11),
                      const SizedBox(width: 5),
                      Text(item, style: TextStyle(color: accent, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

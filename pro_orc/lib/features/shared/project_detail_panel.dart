import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/detail/agents_section.dart';
import 'package:pro_orc/features/shared/detail/collaboration_graph_section.dart';
import 'package:pro_orc/features/shared/detail/description_section.dart';
import 'package:pro_orc/features/shared/detail/file_preview_section.dart';
import 'package:pro_orc/features/shared/detail/links_section.dart';
import 'package:pro_orc/features/shared/detail/quick_actions_section.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/features/shared/detail/sessions_section.dart';
import 'package:pro_orc/features/shared/rename_project_dialog.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tab.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/project_detail_provider.dart';
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
          DescriptionSection(
            colors: colors,
            accent: accent,
            description: project.description!,
          ),

        // --- Dateien (.md Hierarchie) ---
        if (project.mdFiles != null && project.mdFiles!.isNotEmpty)
          SectionCard(
            colors: colors,
            accent: accent,
            title: 'DATEIEN',
            child: FilePreviewSection(
              mdFiles: project.mdFiles!,
              colors: colors,
              accent: accent,
            ),
          ),

        // --- Agents ---
        if (project.usedAgents != null && project.usedAgents!.isNotEmpty)
          AgentsSection(
            usedAgents: project.usedAgents!,
            colors: colors,
            accent: accent,
          ),

        // --- Zusammenarbeits-Graph (Projekt + lokale Agents/Skills) ---
        CollaborationGraphSection(
          projectFolderId: project.folderId,
          projectDisplayName: project.displayName,
          projectPath: project.path,
          usedAgents: project.usedAgents ?? const [],
          colors: colors,
          accent: accent,
        ),

        // --- Sessions ---
        SessionsSection(projectPath: project.path, colors: colors, accent: accent),

        // --- Git & Links ---
        if (git != null)
          LinksSection(git: git, colors: colors, accent: accent, qa: qa),

        // --- Quick Actions ---
        const SizedBox(height: 8),
        QuickActionsSection(
          project: project,
          colors: colors,
          accent: accent,
          qa: qa,
        ),
      ],
    );
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

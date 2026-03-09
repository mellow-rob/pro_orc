import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/claude_tools/mcp_server_card.dart';
import 'package:pro_orc/features/claude_tools/plugin_card.dart';
import 'package:pro_orc/features/claude_tools/skill_card.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Full Claude Tools tab with search, project filter, three sections, mini cards,
/// and live updates.
///
/// Sections: Skills (amber) -> Plugins (emerald) -> MCP-Server (violet).
/// All three sections always visible, even when filtered to zero items.
/// File watcher on ~/.claude/ triggers automatic re-scan via claudeToolsProvider.
class ClaudeToolsTab extends ConsumerStatefulWidget {
  const ClaudeToolsTab({super.key});

  @override
  ConsumerState<ClaudeToolsTab> createState() => _ClaudeToolsTabState();
}

class _ClaudeToolsTabState extends ConsumerState<ClaudeToolsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final toolsAsync = ref.watch(claudeToolsProvider);

    return toolsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.cyan),
      ),
      error: (error, _) => Center(
        child: Text(
          'Fehler beim Laden der Claude Tools',
          style: TextStyle(color: colors.textSec),
        ),
      ),
      data: (data) {
        if (data.isEmpty && _searchQuery.isEmpty) {
          return _buildFullEmptyState(context, colors);
        }
        return _buildContent(context, colors, data);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Full empty state
  // ---------------------------------------------------------------------------

  Widget _buildFullEmptyState(BuildContext context, AppColors colors) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keine Claude Tools gefunden',
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Skills, Plugins und MCP-Server erweitern Claude mit neuen Fähigkeiten.',
                  style: TextStyle(color: colors.textSec, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _helpRow(
                  colors,
                  icon: Icons.handyman,
                  label: 'Skills',
                  detail: 'Ordner in ~/.claude/skills/ anlegen (mit SKILL.md)',
                ),
                const SizedBox(height: 8),
                _helpRow(
                  colors,
                  icon: Icons.extension,
                  label: 'Plugins',
                  detail: 'Via Claude Marketplace installieren',
                ),
                const SizedBox(height: 8),
                _helpRow(
                  colors,
                  icon: Icons.dns,
                  label: 'MCP-Server',
                  detail: 'Eintrag in ~/.claude/settings.json -> mcpServers',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _helpRow(
    AppColors colors, {
    required IconData icon,
    required String label,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.textDim, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: colors.textSec,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: detail,
                  style: TextStyle(color: colors.textDim, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Content (search field + project selector + three sections)
  // ---------------------------------------------------------------------------

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    ClaudeToolsData globalData,
  ) {
    final selectedPath = ref.watch(selectedProjectPathProvider);
    final projectToolsAsync = ref.watch(projectToolsProvider);

    // Merge global + project tools when a project is selected
    final mergedSkills = _mergeSkills(globalData.skills, projectToolsAsync);
    final mergedMcp = _mergeMcpServers(globalData.mcpServers, projectToolsAsync);
    // Plugins are always global
    final allPlugins = globalData.plugins;

    // Apply search filter
    final filteredSkills = _searchQuery.isEmpty
        ? mergedSkills
        : mergedSkills
            .where((s) => s.name.toLowerCase().contains(_searchQuery))
            .toList();
    final filteredPlugins = _searchQuery.isEmpty
        ? allPlugins
        : allPlugins
            .where((p) => p.name.toLowerCase().contains(_searchQuery))
            .toList();
    final filteredMcp = _searchQuery.isEmpty
        ? mergedMcp
        : mergedMcp
            .where((m) => m.name.toLowerCase().contains(_searchQuery))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          _buildSearchField(colors),
          const SizedBox(height: 12),

          // Project selector dropdown
          _buildProjectSelector(colors, selectedPath),
          const SizedBox(height: 24),

          // Skills section
          _buildSection(
            context,
            colors,
            icon: Icons.handyman,
            label: 'Skills',
            count: filteredSkills.length,
            emptyText: 'Keine Skills installiert',
            cards: filteredSkills
                .map((s) => _wrapWithScopeBadge(
                      colors,
                      SkillCard(skill: s),
                      s.scope,
                      selectedPath != null,
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),

          // Plugins section
          _buildSection(
            context,
            colors,
            icon: Icons.extension,
            label: 'Plugins',
            count: filteredPlugins.length,
            emptyText: 'Keine Plugins installiert',
            cards: filteredPlugins.map((p) => PluginCard(plugin: p)).toList(),
          ),
          const SizedBox(height: 32),

          // MCP-Server section
          _buildSection(
            context,
            colors,
            icon: Icons.dns,
            label: 'MCP-Server',
            count: filteredMcp.length,
            emptyText: 'Keine MCP-Server konfiguriert',
            cards: filteredMcp
                .map((m) => _wrapWithScopeBadge(
                      colors,
                      McpServerCard(server: m),
                      m.scope,
                      selectedPath != null,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Merge helpers
  // ---------------------------------------------------------------------------

  List<SkillData> _mergeSkills(
    List<SkillData> global,
    AsyncValue<ClaudeToolsData?> projectAsync,
  ) {
    final projectData = projectAsync.value;
    if (projectData == null) return global;
    return [...global, ...projectData.skills];
  }

  List<McpServerData> _mergeMcpServers(
    List<McpServerData> global,
    AsyncValue<ClaudeToolsData?> projectAsync,
  ) {
    final projectData = projectAsync.value;
    if (projectData == null) return global;
    return [...global, ...projectData.mcpServers];
  }

  // ---------------------------------------------------------------------------
  // Scope badge wrapper
  // ---------------------------------------------------------------------------

  /// Wraps a card with a scope badge when a project is selected.
  Widget _wrapWithScopeBadge(
    AppColors colors,
    Widget card,
    String scope,
    bool showBadge,
  ) {
    if (!showBadge) return card;

    return Stack(
      children: [
        card,
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scope == 'project'
                  ? colors.cyanLo.withValues(alpha: 0.15)
                  : colors.textDim.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              scope == 'project' ? 'Projekt' : 'Global',
              style: TextStyle(
                color: scope == 'project' ? colors.cyanLo : colors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Project selector dropdown
  // ---------------------------------------------------------------------------

  Widget _buildProjectSelector(AppColors colors, String? selectedPath) {
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (projects) {
        if (projects.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.bgElev,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedPath,
              isExpanded: true,
              dropdownColor: colors.bgElev,
              icon: Icon(Icons.unfold_more, color: colors.textSec, size: 18),
              style: TextStyle(color: colors.textPri, fontSize: 13),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Alle Tools (Global)',
                    style: TextStyle(color: colors.textPri, fontSize: 13),
                  ),
                ),
                ...projects.map((p) => DropdownMenuItem<String?>(
                      value: p.path,
                      child: Text(
                        p.displayName,
                        style: TextStyle(color: colors.textPri, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (value) {
                ref.read(selectedProjectPathProvider.notifier).select(value);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: colors.textPri),
      decoration: InputDecoration(
        hintText: 'Suchen...',
        hintStyle: TextStyle(color: colors.textDim),
        prefixIcon: Icon(Icons.search, color: colors.textDim, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: colors.textDim, size: 18),
                onPressed: () => _searchController.clear(),
                padding: EdgeInsets.zero,
              )
            : null,
        filled: true,
        fillColor: colors.bgElev,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.cyanLo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section builder
  // ---------------------------------------------------------------------------

  Widget _buildSection(
    BuildContext context,
    AppColors colors, {
    required IconData icon,
    required String label,
    required int count,
    required String emptyText,
    required List<Widget> cards,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: Icon + Name + count badge
        Row(
          children: [
            Icon(icon, color: colors.textSec, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textPri,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($count)',
              style: TextStyle(color: colors.textSec, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Cards or empty state
        if (cards.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards,
          )
        else
          Text(
            emptyText,
            style: TextStyle(color: colors.textDim, fontSize: 13),
          ),
      ],
    );
  }
}

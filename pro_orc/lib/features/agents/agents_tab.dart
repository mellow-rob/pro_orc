import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/agents/agent_card.dart';
import 'package:pro_orc/features/network/network_screen.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Agents tab — shows global Claude agents from `~/.claude/agents/` plus
/// project-local agents from every scanned project's `.claude/agents/`.
///
/// Two sections: Allgemeine Agents, Projekt-Agents.
/// Search field filters by agent name.
class AgentsTab extends ConsumerStatefulWidget {
  const AgentsTab({super.key});

  @override
  ConsumerState<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends ConsumerState<AgentsTab> {
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
    final agentsAsync = ref.watch(allAgentsProvider);

    return agentsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.cyan),
      ),
      error: (error, _) => Center(
        child: Text(
          'Fehler beim Laden der Agents',
          style: TextStyle(color: colors.textSec),
        ),
      ),
      data: (agents) => _buildContent(context, colors, agents),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    List<AgentData> agents,
  ) {
    final filtered = _searchQuery.isEmpty
        ? agents
        : agents
            .where((a) => a.name.toLowerCase().contains(_searchQuery))
            .toList();

    final projectAgents = filtered.where((a) => a.scope == 'project').toList();
    final generalAgents = filtered.where((a) => a.scope != 'project').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field + Netzwerk button
          Row(
            children: [
              Expanded(child: _buildSearchField(colors)),
              const SizedBox(width: 12),
              _buildNetworkButton(context, colors),
            ],
          ),
          const SizedBox(height: 24),

          // General Agents section
          _buildSection(
            colors,
            icon: Icons.smart_toy_outlined,
            iconColor: colors.cyan,
            label: 'Allgemeine Agents',
            count: generalAgents.length,
            emptyText: 'Keine allgemeinen Agents gefunden',
            cards: generalAgents.map((a) => AgentCard(agent: a)).toList(),
          ),
          const SizedBox(height: 32),

          // Project-local Agents section
          _buildSection(
            colors,
            icon: Icons.folder_special_outlined,
            iconColor: colors.violet,
            label: 'Projekt-Agents',
            count: projectAgents.length,
            emptyText: 'Keine projekt-lokalen Agents gefunden',
            cards: projectAgents.map((a) => AgentCard(agent: a)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkButton(BuildContext context, AppColors colors) {
    return Tooltip(
      message: 'Zusammenarbeits-Netzwerk aller Projekte anzeigen',
      child: TextButton.icon(
        onPressed: () => showNetworkScreen(context),
        icon: Icon(LucideIcons.workflow100, color: colors.cyan, size: 16),
        label: Text(
          'Netzwerk anzeigen',
          style: TextStyle(color: colors.cyan, fontSize: 13),
        ),
        style: TextButton.styleFrom(
          backgroundColor: colors.cyan.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.cyan.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: colors.textPri),
      decoration: InputDecoration(
        hintText: 'Agents suchen...',
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSection(
    AppColors colors, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required int count,
    required String emptyText,
    required List<Widget> cards,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
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

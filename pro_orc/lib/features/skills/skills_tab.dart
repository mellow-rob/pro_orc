import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/claude_tools/skill_card.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Skills tab — shows global Claude skills (`~/.claude/skills/`) plus
/// project-local skills for every scanned project (`.claude/skills/`).
///
/// Search field filters by skill name. Accent color: amber.
class SkillsTab extends ConsumerStatefulWidget {
  const SkillsTab({super.key});

  @override
  ConsumerState<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<SkillsTab> {
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
    final skillsAsync = ref.watch(allSkillsProvider);

    return skillsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.amber),
      ),
      error: (error, _) => Center(
        child: Text(
          'Fehler beim Laden der Skills',
          style: TextStyle(color: colors.textSec),
        ),
      ),
      data: (skills) => _buildContent(context, colors, skills),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    List<SkillData> allSkills,
  ) {
    final filtered = _searchQuery.isEmpty
        ? allSkills
        : allSkills
            .where((s) => s.name.toLowerCase().contains(_searchQuery))
            .toList();

    final globalFiltered = filtered.where((s) => s.scope == 'global').toList();
    final projectFiltered = filtered.where((s) => s.scope == 'project').toList();
    final pluginFiltered = filtered.where((s) => s.scope == 'plugin').toList();

    if (allSkills.isEmpty && _searchQuery.isEmpty) {
      return _buildEmptyState(colors);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(colors),
          const SizedBox(height: 24),

          _buildSection(
            colors,
            icon: Icons.handyman_outlined,
            iconColor: colors.amber,
            label: 'Globale Skills',
            count: globalFiltered.length,
            emptyText: 'Keine globalen Skills gefunden',
            cards: globalFiltered.map((s) => SkillCard(skill: s)).toList(),
          ),
          const SizedBox(height: 32),

          _buildSection(
            colors,
            icon: Icons.folder_special_outlined,
            iconColor: colors.violet,
            label: 'Projekt-Skills',
            count: projectFiltered.length,
            emptyText: 'Keine projekt-lokalen Skills gefunden',
            cards: projectFiltered.map((s) => SkillCard(skill: s)).toList(),
          ),
          const SizedBox(height: 32),

          _buildSection(
            colors,
            icon: Icons.extension_outlined,
            iconColor: colors.violet,
            label: 'Plugin-Skills',
            count: pluginFiltered.length,
            emptyText: 'Keine Plugin-Skills gefunden',
            cards: pluginFiltered.map((s) => SkillCard(skill: s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Text(
        'Keine Skills gefunden.\n'
        'Lege einen Ordner in ~/.claude/skills/ mit einer SKILL.md an.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.textSec, fontSize: 14),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: colors.textPri),
      decoration: InputDecoration(
        hintText: 'Skills suchen...',
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
          borderSide: BorderSide(color: colors.amberLo, width: 1.5),
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

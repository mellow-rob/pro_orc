import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Modal dialog that lists available skills (global + project-local, from
/// [allSkillsProvider]) with a search field, and launches Claude Code in the
/// project directory with the picked skill pre-invoked as a slash command
/// (`claude "/<skill>"`, AD-4).
///
/// Read-only w.r.t. config — it only spawns a terminal, never writes.
class SkillLauncherDialog extends ConsumerStatefulWidget {
  const SkillLauncherDialog({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  final String projectPath;
  final String projectName;

  /// Convenience opener.
  static Future<void> show(
    BuildContext context, {
    required String projectPath,
    required String projectName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SkillLauncherDialog(
        projectPath: projectPath,
        projectName: projectName,
      ),
    );
  }

  @override
  ConsumerState<SkillLauncherDialog> createState() =>
      _SkillLauncherDialogState();
}

class _SkillLauncherDialogState extends ConsumerState<SkillLauncherDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() => _query = _search.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.amber;
    final skillsAsync = ref.watch(allSkillsProvider);

    return GlassDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles100, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mit Skill starten',
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.x100, color: colors.textDim, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Startet Claude Code in ${widget.projectName}.',
            style: TextStyle(color: colors.textSec, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            autofocus: true,
            style: TextStyle(color: colors.textPri),
            decoration: InputDecoration(
              hintText: 'Skill suchen…',
              hintStyle: TextStyle(color: colors.textDim),
              prefixIcon: Icon(
                LucideIcons.search100,
                color: colors.textDim,
                size: 18,
              ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: skillsAsync.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: accent)),
              error: (_, _) => Center(
                child: Text(
                  'Skills nicht lesbar',
                  style: TextStyle(color: colors.textSec),
                ),
              ),
              data: (skills) => _buildList(colors, accent, skills),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppColors colors, Color accent, List<SkillData> skills) {
    final filtered = _query.isEmpty
        ? skills
        : skills.where((s) => s.name.toLowerCase().contains(_query)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Keine Skills gefunden',
          style: TextStyle(color: colors.textDim, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colors.bgElev.withValues(alpha: 0.8)),
      itemBuilder: (context, i) {
        final skill = filtered[i];
        return _SkillTile(
          skill: skill,
          colors: colors,
          accent: accent,
          onTap: () => _launch(skill),
        );
      },
    );
  }

  Future<void> _launch(SkillData skill) async {
    Navigator.of(context).pop();
    await QuickActionsService().openClaudeWithSkill(
      widget.projectPath,
      skill.name,
    );
  }
}

class _SkillTile extends StatefulWidget {
  const _SkillTile({
    required this.skill,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final SkillData skill;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_SkillTile> createState() => _SkillTileState();
}

class _SkillTileState extends State<_SkillTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final scopeLabel = widget.skill.scope == 'global' ? 'Global' : 'Projekt';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hovered
              ? widget.accent.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              Icon(
                LucideIcons.sparkles100,
                color: _hovered ? widget.accent : colors.textDim,
                size: 15,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.skill.name,
                      style: TextStyle(
                        color: _hovered ? widget.accent : colors.textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.skill.description != null &&
                        widget.skill.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.skill.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textDim, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                scopeLabel,
                style: TextStyle(color: colors.textDim, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

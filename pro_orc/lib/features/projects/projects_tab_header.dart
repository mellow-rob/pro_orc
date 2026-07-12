import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/features/projects/projects_type_filter.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Header row for the merged Projekte tab: type-filter chips (FR-021), the
/// "+ Gruppe" affordance (placeholder — wired in Wave 4), the grid/list
/// toggle (FR-001), and the add-project entry point.
class ProjectsTabHeader extends StatelessWidget {
  const ProjectsTabHeader({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.viewMode,
    required this.onAddPressed,
  });

  final ProjectsTypeFilter filter;
  final ValueChanged<ProjectsTypeFilter> onFilterChanged;
  final ViewMode viewMode;
  final void Function(Offset position) onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Consumer(
      builder: (context, ref, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'Alle',
                selected: filter == ProjectsTypeFilter.all,
                onTap: () => onFilterChanged(ProjectsTypeFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Code',
                selected: filter == ProjectsTypeFilter.code,
                onTap: () => onFilterChanged(ProjectsTypeFilter.code),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Research',
                selected: filter == ProjectsTypeFilter.research,
                onTap: () => onFilterChanged(ProjectsTypeFilter.research),
              ),
              const Spacer(),
              // Wave 4 wires up group creation behind this button.
              TextButton.icon(
                onPressed: null,
                icon: Icon(
                  LucideIcons.folderPlus100,
                  size: 16,
                  color: colors.textDim,
                ),
                label: Text(
                  '+ Gruppe',
                  style: TextStyle(color: colors.textDim, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('view-mode-toggle'),
                tooltip: viewMode == ViewMode.grid
                    ? 'Listenansicht'
                    : 'Rasteransicht',
                icon: Icon(
                  viewMode == ViewMode.grid
                      ? LucideIcons.list100
                      : LucideIcons.layoutGrid100,
                  color: colors.textSec,
                  size: 18,
                ),
                onPressed: () => ref.read(viewModeProvider.notifier).toggle(),
              ),
              IconButton(
                tooltip: 'Projekt hinzufuegen',
                icon: Icon(Icons.add, color: colors.cyan, size: 20),
                onPressed: () {
                  final box = context.findRenderObject() as RenderBox;
                  final position = box.localToGlobal(Offset.zero);
                  onAddPressed(position);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.cyan.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? colors.cyan
                : colors.textDim.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.cyan : colors.textSec,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

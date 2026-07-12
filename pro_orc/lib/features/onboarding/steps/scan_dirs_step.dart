import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Step 2: Folder picker for scan directories.
///
/// Allows the user to add and remove directories that Pro Orc
/// will scan for projects. Uses the same visual pattern as
/// the Settings tab scan directory section.
class ScanDirsStep extends StatelessWidget {
  const ScanDirsStep({
    super.key,
    required this.scanDirs,
    required this.onAddDir,
    required this.onRemoveDir,
  });

  final List<String> scanDirs;
  final VoidCallback onAddDir;
  final ValueChanged<int> onRemoveDir;

  String _abbreviatePath(String path) {
    return path.replaceFirst(RegExp(r'^/Users/[^/]+'), '~');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(
          LucideIcons.folderOpen,
          size: 48,
          color: colors.cyan.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          'Projektverzeichnisse waehlen',
          style: TextStyle(
            color: colors.textPri,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welche Ordner soll Pro Orc nach Projekten durchsuchen?',
          style: TextStyle(color: colors.textDim, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Expanded(
          child: scanDirs.isEmpty
              ? Center(
                  child: Text(
                    'Noch keine Ordner ausgewaehlt',
                    style: TextStyle(color: colors.textDim, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: scanDirs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    return _buildDirRow(colors, scanDirs[index], index);
                  },
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddDir,
            icon: Icon(LucideIcons.plus, size: 16, color: colors.cyan),
            label: Text(
              'Ordner hinzufuegen',
              style: TextStyle(color: colors.cyan, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.cyan.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDirRow(AppColors colors, String dir, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.folder,
            color: colors.cyan.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _abbreviatePath(dir),
              style: TextStyle(
                color: colors.textSec,
                fontSize: 12,
                fontFamily: 'SF Mono',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onRemoveDir(index),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(LucideIcons.circleX, color: colors.textDim, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

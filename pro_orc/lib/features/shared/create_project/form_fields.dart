import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Name text field for [CreateProjectDialog] — free-text project name that
/// derives the folder name as the user types.
class ProjectNameField extends StatelessWidget {
  const ProjectNameField({
    super.key,
    required this.controller,
    required this.colors,
    required this.accent,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AppColors colors;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      cursorColor: accent,
      decoration: colors.glassInputDecoration(
        hintText: 'Projektname',
        accentColor: accent,
      ),
      onChanged: onChanged,
    );
  }
}

/// Preview line below the name field: either an "already exists" warning or
/// the abbreviated full target path (e.g. `~/code/mein-projekt`).
class FolderPreview extends StatelessWidget {
  const FolderPreview({
    super.key,
    required this.derivedFolderName,
    required this.folderExists,
    required this.fullPathPreview,
    required this.colors,
  });

  final String derivedFolderName;
  final bool folderExists;

  /// Already-abbreviated full path (e.g. `~/code/mein-projekt`), or the bare
  /// derived folder name when no scan dir is selected yet.
  final String fullPathPreview;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (derivedFolderName.isEmpty) {
      return const SizedBox(height: 16);
    }
    if (folderExists) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          'Ordner existiert bereits',
          style: TextStyle(color: colors.amber, fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        fullPathPreview,
        style: TextStyle(color: colors.textSec, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Zielordner (scan dir) dropdown. Hidden when there is only one scan dir
/// (auto-selected) or none at all.
class ZielordnerDropdown extends StatelessWidget {
  const ZielordnerDropdown({
    super.key,
    required this.scanDirs,
    required this.selectedScanDir,
    required this.colors,
    required this.accent,
    required this.abbreviatePath,
    required this.onChanged,
  });

  final List<String> scanDirs;
  final String? selectedScanDir;
  final AppColors colors;
  final Color accent;
  final String Function(String) abbreviatePath;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (scanDirs.isEmpty) return const SizedBox.shrink();
    // Hide dropdown if only one scan dir (auto-selected)
    if (scanDirs.length == 1) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      initialValue: selectedScanDir,
      dropdownColor: colors.bgElev,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      iconEnabledColor: colors.textDim,
      decoration: colors.glassInputDecoration(
        labelText: 'Zielordner',
        accentColor: accent,
      ),
      items: scanDirs.map((dir) {
        return DropdownMenuItem<String>(
          value: dir,
          child: Text(
            abbreviatePath(dir),
            style: TextStyle(color: colors.textPri, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// A single labelled toggle row (title + adaptive switch), shared by the
/// Code- and Research-tab toggle groups.
class DialogToggleRow extends StatelessWidget {
  const DialogToggleRow({
    super.key,
    required this.colors,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final AppColors colors;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colors.textPri, fontSize: 13),
            ),
          ),
          SizedBox(
            height: 24,
            width: 40,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: value,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.4),
                inactiveThumbColor: colors.textDim,
                inactiveTrackColor: colors.textDim.withValues(alpha: 0.2),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

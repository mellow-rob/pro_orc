import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Dialog to rename a project's display name (DB override).
///
/// The folder on disk is NOT renamed — only the displayed title.
/// Empty input clears the override and falls back to PROJECT.md / folder name.
///
/// Resolves: `true` if changed, `false` on cancel.
class RenameProjectDialog extends ConsumerStatefulWidget {
  const RenameProjectDialog({super.key, required this.project});

  final ProjectModel project;

  @override
  ConsumerState<RenameProjectDialog> createState() =>
      _RenameProjectDialogState();
}

class _RenameProjectDialogState extends ConsumerState<RenameProjectDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.project.displayName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// True if the project currently has a display-name override saved.
  /// We can't tell from the model alone (it always has a displayName), so we
  /// approximate: override exists if displayName differs from folderId AND we
  /// loaded settings showing it. For UX we just always show the reset button
  /// when the input differs from what would be auto-derived. The DB call is
  /// cheap, so we let the user always reset.
  bool get _hasChanges =>
      _controller.text.trim() != widget.project.displayName.trim();

  Future<void> _save({required bool reset}) async {
    if (_saving) return;
    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    final value = reset ? null : _controller.text;
    await db.setProjectDisplayName(widget.project.folderId, value);

    if (!mounted) return;
    ref.invalidate(projectsProvider);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GlassDialog(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colors),
          const SizedBox(height: 16),
          _buildTextField(colors),
          const SizedBox(height: 8),
          _buildHint(colors),
          const SizedBox(height: 4),
          _buildResetLink(colors),
          const SizedBox(height: 16),
          _buildButtons(colors),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Projekt umbenennen',
            style: TextStyle(
              color: colors.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.textDim, size: 20),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          splashRadius: 16,
          tooltip: 'Schliessen',
        ),
      ],
    );
  }

  Widget _buildTextField(AppColors colors) {
    return TextField(
      controller: _controller,
      autofocus: true,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      cursorColor: colors.cyan,
      onSubmitted: (_) => _save(reset: false),
      decoration: InputDecoration(
        hintText: 'Anzeigename',
        hintStyle: TextStyle(color: colors.textDim, fontSize: 14),
        filled: true,
        fillColor: colors.bgElev.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colors.cyan.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildHint(AppColors colors) {
    return Text(
      'Nur die Anzeige im Dashboard aendert sich — der Ordner bleibt '
      '"${widget.project.folderId}".',
      style: TextStyle(color: colors.textDim, fontSize: 12),
    );
  }

  Widget _buildButtons(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: (_saving || !_hasChanges)
              ? null
              : () => _save(reset: false),
          style: FilledButton.styleFrom(
            backgroundColor: colors.cyan,
            disabledBackgroundColor: colors.textDim.withValues(alpha: 0.2),
            foregroundColor: Colors.black,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.5),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text('Speichern'),
        ),
      ],
    );
  }

  Widget _buildResetLink(AppColors colors) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _saving ? null : () => _save(reset: true),
        style: TextButton.styleFrom(
          foregroundColor: colors.textDim,
          disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: const Text('Zuruecksetzen'),
      ),
    );
  }
}

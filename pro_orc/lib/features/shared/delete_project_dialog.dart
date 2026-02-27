import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/deletion_service.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// GitHub-style deletion confirmation dialog.
///
/// Requires the user to type the exact project name before enabling
/// the "Loeschen" button — prevents accidental permanent deletion.
///
/// On confirm: calls [deleteProject], invalidates [projectsProvider]
/// for auto-refresh, then pops with `true`.
/// On cancel: pops with `false` — no side effects.
class DeleteProjectDialog extends ConsumerStatefulWidget {
  const DeleteProjectDialog({
    super.key,
    required this.project,
  });

  final ProjectModel project;

  @override
  ConsumerState<DeleteProjectDialog> createState() =>
      _DeleteProjectDialogState();
}

class _DeleteProjectDialogState extends ConsumerState<DeleteProjectDialog> {
  late final TextEditingController _textController;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _nameMatches =>
      _textController.text == widget.project.displayName;

  Future<void> _onDelete() async {
    if (!_nameMatches || _isDeleting) return;
    setState(() => _isDeleting = true);

    final success = await deleteProject(widget.project.path);

    if (!mounted) return;

    if (success) {
      ref.invalidate(projectsProvider);
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            blendMode: BlendMode.src,
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: colors.bgSurf,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colors),
                  const SizedBox(height: 16),
                  _buildWarning(colors),
                  const SizedBox(height: 16),
                  _buildProjectName(colors),
                  const SizedBox(height: 16),
                  _buildTextField(colors),
                  const SizedBox(height: 24),
                  _buildButtons(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Projekt loeschen',
            style: TextStyle(
              color: colors.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.textDim, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
          splashRadius: 16,
          tooltip: 'Schliessen',
        ),
      ],
    );
  }

  Widget _buildWarning(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.shade700.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        'Diese Aktion kann nicht rueckgaengig gemacht werden. '
        'Der Ordner wird permanent geloescht.',
        style: TextStyle(
          color: colors.textSec,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildProjectName(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projekt',
          style: TextStyle(color: colors.textDim, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          widget.project.displayName,
          style: TextStyle(
            color: colors.textPri,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(AppColors colors) {
    return TextField(
      controller: _textController,
      autofocus: true,
      style: TextStyle(color: colors.textPri, fontSize: 14),
      cursorColor: Colors.red.shade400,
      decoration: InputDecoration(
        hintText: 'Projektname zur Bestaetigung eingeben',
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
            color: _nameMatches
                ? Colors.red.shade700.withValues(alpha: 0.7)
                : colors.textDim.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildButtons(AppColors colors) {
    final deleteEnabled = _nameMatches && !_isDeleting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: deleteEnabled ? _onDelete : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            disabledBackgroundColor: colors.textDim.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.5),
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Loeschen'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Dialog to rename an existing user-created group (FR-004/019).
///
/// Never shown for the system-owned "Archiv" group — callers gate on
/// `group.isSystem` before opening this dialog. Surfaces the shared Wave-2
/// name-validation result inline ("Gruppe existiert bereits" for a
/// duplicate/reserved name).
///
/// Resolves `true` on a successful rename, `false`/`null` on cancel.
class RenameGroupDialog extends ConsumerStatefulWidget {
  const RenameGroupDialog({super.key, required this.group});

  final ProjectGroup group;

  @override
  ConsumerState<RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends ConsumerState<RenameGroupDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.group.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(groupsProvider.notifier)
        .rename(widget.group.id, _controller.text);

    if (!mounted) return;

    switch (result) {
      case GroupActionSuccess():
        Navigator.of(context).pop(true);
      case GroupActionNameRejected():
        setState(() {
          _saving = false;
          _error = 'Gruppe existiert bereits';
        });
      case GroupActionSystemGroupRejected():
      case GroupActionNotFound():
        setState(() {
          _saving = false;
          _error = 'Aktion nicht moeglich';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GlassDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colors),
          const SizedBox(height: 16),
          _buildTextField(colors),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const ValueKey('rename-group-error'),
              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
            ),
          ],
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
          child: Tooltip(
            message: 'Gruppe umbenennen',
            child: Text(
              'Gruppe umbenennen',
              style: TextStyle(
                color: colors.textPri,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
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
      onSubmitted: (_) => _rename(),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        hintText: 'Gruppenname',
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildButtons(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _saving ? null : _rename,
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
}

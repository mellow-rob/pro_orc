import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Dialog to create a new group (FR-003/009/019).
///
/// Used from two entry points: the header "+ Gruppe" affordance, and the
/// card context menu's "Neue Gruppe..." submenu item. Surfaces the shared
/// Wave-2 name-validation result inline ("Gruppe existiert bereits" for a
/// duplicate/reserved name incl. "Archiv").
///
/// Resolves with the new group's id on success, or `null` on cancel.
class CreateGroupDialog extends ConsumerStatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  ConsumerState<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<CreateGroupDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(groupsProvider.notifier)
        .create(_controller.text);

    if (!mounted) return;

    switch (result) {
      case GroupActionSuccess():
        final created = ref
            .read(groupsProvider)
            .where((g) => g.name == _controller.text.trim())
            .lastOrNull;
        Navigator.of(context).pop(created?.id);
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
              key: const ValueKey('create-group-error'),
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
            message: 'Neue Gruppe',
            child: Text(
              'Neue Gruppe',
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
      onSubmitted: (_) => _create(),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSec,
            disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
          ),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _saving ? null : _create,
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
              : const Text('Erstellen'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Bottom button row (Abbrechen/Erstellen) plus optional error/warning text
/// for [CreateProjectDialog]. Renders a loading spinner or a success check
/// inside the primary button depending on submit state.
class CreateProjectDialogButtons extends StatelessWidget {
  const CreateProjectDialogButtons({
    super.key,
    required this.colors,
    required this.accent,
    required this.isLoading,
    required this.isCreated,
    required this.isFormValid,
    required this.errorMessage,
    required this.onCancel,
    required this.onSubmit,
  });

  final AppColors colors;
  final Color accent;
  final bool isLoading;
  final bool isCreated;
  final bool isFormValid;
  final String? errorMessage;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading || isCreated;

    Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.bgBase),
      );
    } else if (isCreated) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: colors.bgBase, size: 16),
          const SizedBox(width: 4),
          const Text('Erstellt!'),
        ],
      );
    } else {
      buttonChild = const Text('Erstellen');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Warning/error text — shown above buttons row
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              errorMessage!,
              style: TextStyle(color: colors.amber, fontSize: 12),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isDisabled ? null : onCancel,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSec,
                disabledForegroundColor: colors.textDim.withValues(alpha: 0.4),
              ),
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isFormValid ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                disabledBackgroundColor: accent.withValues(alpha: 0.3),
                foregroundColor: colors.bgBase,
                disabledForegroundColor: colors.bgBase.withValues(alpha: 0.5),
              ),
              child: buttonChild,
            ),
          ],
        ),
      ],
    );
  }
}

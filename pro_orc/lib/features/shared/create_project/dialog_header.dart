import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Title row + close button for [CreateProjectDialog]. Title text swaps
/// with a fade when the active tab (Code/Research) changes.
class CreateProjectDialogHeader extends StatelessWidget {
  const CreateProjectDialogHeader({
    super.key,
    required this.title,
    required this.tabIndex,
    required this.colors,
    required this.onClose,
  });

  final String title;
  final int tabIndex;
  final AppColors colors;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              title,
              key: ValueKey(tabIndex),
              style: TextStyle(
                color: colors.textPri,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.textDim, size: 20),
          onPressed: onClose,
          splashRadius: 16,
          tooltip: 'Schliessen',
        ),
      ],
    );
  }
}

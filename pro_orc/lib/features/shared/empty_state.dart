import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Generic empty state widget shown when a tab has no projects.
///
/// Displays a friendly icon, heading, explanatory text, and an optional
/// "Scan-Ordner waehlen" button that triggers [onPickDirectory].
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.tabName,
    required this.message,
    this.onPickDirectory,
  });

  final String tabName;
  final String message;
  final VoidCallback? onPickDirectory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: colors.textDim,
            ),
            const SizedBox(height: 20),
            Text(
              'Keine Projekte gefunden',
              style: TextStyle(
                color: colors.textPri,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: colors.textSec, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (onPickDirectory != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onPickDirectory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.cyan,
                  side: BorderSide(color: colors.cyan.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Scan-Ordner waehlen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

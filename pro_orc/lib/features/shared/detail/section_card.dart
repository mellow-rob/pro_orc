import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Section card wrapper — subtle container with accent top border.
///
/// Shared by every section of [ProjectDetailPanel]'s "Übersicht" tab.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.colors,
    required this.accent,
    required this.title,
    required this.child,
  });

  final AppColors colors;
  final Color accent;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.bgSurf.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

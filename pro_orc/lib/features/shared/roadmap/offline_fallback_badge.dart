import 'package:flutter/material.dart';

/// Badge shown when the Roadmap tab's data resolved from the Obsidian Vault
/// tier (i.e. local `.a1/roadmap.md` AND A1 Brain both yielded no usable
/// data) — signals to Robert that this is fallback/possibly-stale data
/// (FR-010a).
class OfflineFallbackBadge extends StatelessWidget {
  const OfflineFallbackBadge({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF59E0B); // amber — matches "paused" status tone

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Offline-Fallback',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

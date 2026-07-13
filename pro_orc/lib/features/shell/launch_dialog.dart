import 'package:flutter/material.dart';

Future<bool> showLaunchAtLoginDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
      ),
      title: const Text(
        'Start Pro Orc when you log in?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const Text(
        'Pro Orc can start automatically when you log in to your Mac.',
        style: TextStyle(color: Color(0xFFB0B0C0), fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Not now',
            style: TextStyle(color: Color(0xFFB0B0C0)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: const Color(0xFF0A0A0F),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes, start at login'),
        ),
      ],
    ),
  );
  return result ?? false;
}

import 'package:flutter/material.dart';

class GlowBorderShell extends StatelessWidget {
  const GlowBorderShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFFF00FF).withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}
